# main.py
import os
import io
import json
import traceback
from typing import Optional, List, Dict

import numpy as np
import requests
from PIL import Image
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn

# -----------------------
# Config / paths
# -----------------------
BASE_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(BASE_DIR, "data", "products")
MODEL_NAME = os.getenv("MODEL_NAME", "clip-ViT-B-32")
MAX_IMAGE_WIDTH = int(os.getenv("MAX_IMAGE_WIDTH", "1024"))  # resize very large uploads

# -----------------------
# App init
# -----------------------
app = FastAPI(title="Visual Product Matcher")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

print("Loading model:", MODEL_NAME)
model = SentenceTransformer(MODEL_NAME)

# load dataset & precomputed embeddings
products_path = os.path.join(DATA_DIR, "products.json")
prod_emb_path = os.path.join(DATA_DIR, "product_embeddings.npy")
img_emb_path = os.path.join(DATA_DIR, "image_embeddings.npy")
img_index_path = os.path.join(DATA_DIR, "image_index.json")

if not (os.path.exists(products_path) and os.path.exists(prod_emb_path) and os.path.exists(img_emb_path) and os.path.exists(img_index_path)):
    raise RuntimeError("Missing products.json or embeddings. Run precompute_embeddings_images.py first.")

with open(products_path, "r", encoding="utf-8") as f:
    products = json.load(f)

product_embeddings = np.load(prod_emb_path)
image_embeddings = np.load(img_emb_path)
with open(img_index_path, "r", encoding="utf-8") as f:
    image_index = json.load(f)

# -----------------------
# Helpers
# -----------------------
def pil_open_and_normalize(img_bytes: bytes, max_width: int = MAX_IMAGE_WIDTH) -> Image.Image:
    """Open bytes into PIL Image, convert to RGB, resize if too large."""
    img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    w, h = img.size
    if w > max_width:
        new_h = int(max_width * h / w)
        img = img.resize((max_width, new_h), Image.LANCZOS)
    return img

def img_to_embedding(img: Image.Image) -> np.ndarray:
    """Encode PIL image to a normalized vector."""
    emb = model.encode(img, convert_to_numpy=True)
    norm = np.linalg.norm(emb) + 1e-10
    return (emb / norm).astype(np.float32)

def img_bytes_to_emb(img_bytes: bytes) -> np.ndarray:
    img = pil_open_and_normalize(img_bytes)
    return img_to_embedding(img)

def safe_float(x) -> Optional[float]:
    try:
        if x is None:
            return None
        return float(str(x).replace("₹", "").replace(",", ""))
    except Exception:
        return None

def _image_url_out(file_name: str) -> str:
    """Return server-side static path for file or pass-through absolute URLs."""
    if not file_name:
        return ""
    file_name = str(file_name)
    if file_name.startswith("http://") or file_name.startswith("https://"):
        return file_name
    return f"/static/{file_name}"

# -----------------------
# Match endpoint (returns images[] for each matched product)
# -----------------------
@app.post("/match")
async def match(
    file: UploadFile = File(None),
    image_url: str = Form(None),
    top_k: int = Form(6),
    threshold: float = Form(0.0),
    price_min: float = Form(None),
    price_max: float = Form(None),
):
    try:
        # 1) obtain bytes
        if file:
            content = await file.read()
            if not content:
                raise HTTPException(status_code=400, detail="Uploaded file is empty")
        elif image_url:
            try:
                resp = requests.get(image_url, timeout=8)
                resp.raise_for_status()
                content = resp.content
                if not content:
                    raise HTTPException(status_code=400, detail="Downloaded image is empty")
            except requests.RequestException as e:
                raise HTTPException(status_code=400, detail=f"Failed to download image_url: {e}")
        else:
            raise HTTPException(status_code=400, detail="No image provided (send file or image_url)")

        # 2) compute query embedding (catch PIL / encoding errors)
        try:
            q_emb = img_bytes_to_emb(content).reshape(1, -1)
        except Exception as e:
            tb = traceback.format_exc()
            print("ERROR: failed to create embedding for query image:\n", tb)
            raise HTTPException(status_code=400, detail=f"Image decoding/encoding failed: {e}")

        # 3) similarity vs product embeddings
        sims = cosine_similarity(q_emb, product_embeddings)[0]
        ranked = sims.argsort()[::-1]

        # 4) gather results (respect threshold & price filters)
        results: List[Dict] = []
        for p_idx in ranked:
            prod_score = float(sims[p_idx])
            if prod_score < threshold:
                continue

            # collect image entries for this product
            candidate_idxs = [i for i, entry in enumerate(image_index) if entry["product_idx"] == p_idx]
            if not candidate_idxs:
                continue

            image_entries = []
            for img_idx in candidate_idxs:
                entry = image_index[img_idx]
                # parse price
                p_price = safe_float(entry.get("price"))
                # image-level price filters
                if price_min is not None and p_price is not None and p_price < float(price_min):
                    continue
                if price_max is not None and p_price is not None and p_price > float(price_max):
                    continue

                # image-level similarity
                try:
                    img_emb = image_embeddings[img_idx].reshape(1, -1)
                    img_sim = float(cosine_similarity(q_emb, img_emb)[0][0])
                except Exception:
                    img_sim = prod_score

                image_entries.append({
                    "file": _image_url_out(entry.get("file", "")),
                    "price": p_price,
                    "score": float(img_sim)
                })

            if not image_entries:
                continue

            # sort images by image-level score (desc)
            image_entries.sort(key=lambda x: x["score"], reverse=True)

            # compute product-level min/max price (from available images)
            prices = [i["price"] for i in image_entries if i.get("price") is not None]
            min_price = min(prices) if prices else None
            max_price = max(prices) if prices else None

            results.append({
                "id": products[p_idx].get("id"),
                "name": products[p_idx].get("name"),
                "category": products[p_idx].get("category"),
                "score": float(prod_score),
                "min_price": min_price,
                "max_price": max_price,
                "images": image_entries
            })

            if len(results) >= int(top_k):
                break

        return {"query_matches": results}

    except HTTPException:
        raise
    except Exception as e:
        tb = traceback.format_exc()
        print("Unhandled exception in /match:\n", tb)
        return JSONResponse({"error": str(e), "trace": tb}, status_code=500)

# -----------------------
# static files (images)
# -----------------------
if os.path.isdir(DATA_DIR):
    app.mount("/static", StaticFiles(directory=DATA_DIR), name="static")

# -----------------------
# run
# -----------------------
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=int(os.getenv("PORT", 8000)), reload=True)
