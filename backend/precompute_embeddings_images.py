# precompute_embeddings_images.py
import os, json, numpy as np
from sentence_transformers import SentenceTransformer
from PIL import Image

BASE = os.path.dirname(__file__)
DATA_DIR = os.path.join(BASE, "data", "products")
MODEL_NAME = "clip-ViT-B-32"   # good balance; change if you want

OUT_PRODUCT = os.path.join(DATA_DIR, "product_embeddings.npy")
OUT_IMAGE = os.path.join(DATA_DIR, "image_embeddings.npy")
OUT_INDEX = os.path.join(DATA_DIR, "image_index.json")

def load_products():
    with open(os.path.join(DATA_DIR, "products.json"), "r", encoding="utf-8") as f:
        return json.load(f)

def compute_img_emb(model, img_path):
    img = Image.open(img_path).convert("RGB")
    emb = model.encode(img, convert_to_numpy=True)
    return emb

def main():
    products = load_products()
    model = SentenceTransformer(MODEL_NAME)

    product_embs = []
    image_embs = []
    image_index = []  # list of {product_idx, file, price}

    for p_idx, prod in enumerate(products):
        imgs = prod.get("images", [])
        per_prod_embs = []
        for im in imgs:
            # im expected to be dict: {"file": "...", "price": "..."}
            if isinstance(im, dict):
                fname = im.get("file")
                price = im.get("price")
            else:
                # fallback if images are strings
                fname = im
                price = prod.get("price", None)

            img_path = os.path.join(DATA_DIR, fname)
            if not os.path.exists(img_path):
                print(f"[WARN] Missing image {img_path} — skipping this image")
                continue
            try:
                emb = compute_img_emb(model, img_path)
            except Exception as e:
                print(f"[WARN] Failed encoding {img_path}: {e}")
                continue

            per_prod_embs.append(emb)
            image_embs.append(emb)
            image_index.append({"product_idx": p_idx, "file": fname, "price": str(price)})

        if len(per_prod_embs) == 0:
            # If no images for product, push zero vector (model dim)
            dim = model.get_sentence_embedding_dimension()
            product_embs.append(np.zeros(dim, dtype=np.float32))
            print(f"[WARN] No valid images for product {prod.get('id')}; using zero vector")
        else:
            avg = np.mean(np.stack(per_prod_embs, axis=0), axis=0)
            # normalize
            avg = avg / (np.linalg.norm(avg) + 1e-10)
            product_embs.append(avg.astype(np.float32))

    product_embs = np.stack(product_embs, axis=0)
    image_embs = np.stack(image_embs, axis=0) if image_embs else np.zeros((0, product_embs.shape[1]), dtype=np.float32)

    np.save(OUT_PRODUCT, product_embs)
    np.save(OUT_IMAGE, image_embs)
    with open(OUT_INDEX, "w", encoding="utf-8") as f:
        json.dump(image_index, f, indent=2)

    print("Saved product_embeddings:", OUT_PRODUCT, "shape:", product_embs.shape)
    print("Saved image_embeddings:", OUT_IMAGE, "shape:", image_embs.shape)
    print("Saved image_index:", OUT_INDEX, "entries:", len(image_index))

if __name__ == "__main__":
    main()
