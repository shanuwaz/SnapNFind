# 🛍️ SnapNFind — AI-Powered Visual Product Search

> **SnapNFind** is an AI-powered visual product search engine that lets users upload an image (or paste an image URL) and instantly discover visually similar products.  
> Built with **Flutter** (frontend) and **FastAPI** (backend), powered by **CLIP-based image embeddings** for similarity search.


## 🚀 Overview

SnapNFind combines **computer vision** and **AI-powered embeddings** to help users visually match and discover products from an existing catalog.  
It’s a demonstration of an **image similarity search system** that can be extended into e-commerce, fashion search, or visual recommender applications.

### ✨ Core Features
- 🖼️ **Upload or paste** any product image (clothing, footwear, accessories, etc.)
- 🤖 **AI-based feature extraction** using CLIP (Contrastive Language–Image Pretraining)
- 🔎 **Similarity scoring** between uploaded and catalog images
- 💰 **Smart filtering** (price range, top-k results, similarity threshold)
- 🌑 **Pitch-black modern UI** with gradient header and filter modal
- 💫 **Responsive Flutter frontend** (works on Web, Android, and Desktop)
- 📦 **FastAPI backend** serving similarity matches + static images

---

## 🧩 Tech Stack

| Layer | Technology |
|:------|:------------|
| **Frontend** | Flutter (Dart), Material Design, Image Picker, HTTP API |
| **Backend** | FastAPI, Python 3, Sentence-Transformers (CLIP ViT-B/32), Scikit-Learn |
| **Embedding Model** | `clip-ViT-B-32` from HuggingFace / Sentence-Transformers |
| **Database (Local)** | JSON file (`products.json`) + precomputed embeddings |
| **Hosting** | Render (Backend API) + Netlify (Frontend Web App) |
| **Visualization** | Gradient + dark mode UI with interactive filter modal |

---

## 🧠 How It Works

1. **User Input**
   - Upload an image (`jpg/jpeg/png`) or provide an image URL.
   - Optionally set *price filters* and *similarity threshold* via filter icon.

2. **Image Embedding (Backend)**
   - FastAPI encodes the query image using **CLIP-ViT-B-32**.
   - The image is converted into a fixed-size embedding vector (512D).

3. **Similarity Computation**
   - The query embedding is compared with **precomputed product embeddings**.
   - Cosine similarity determines how visually close two products are.

4. **Filtering & Ranking**
   - Results are filtered by similarity score and price range.
   - Top-K results are returned, ordered by similarity.

5. **Frontend Display**
   - Flutter visualizes results with:
     - Product name & category
     - Multiple image thumbnails per product
     - Prices and confidence scores
     - Click-to-expand previews

---

## 🧰 Project Structure

SnapNFind/
│
├── backend/
│ ├── main.py # FastAPI app
│ ├── precompute_embeddings_images.py # Precomputes product/image embeddings
│ ├── requirements.txt # Python dependencies
│ ├── data/
│ │ └── products/
│ │ ├── products.json # Product metadata
│ │ ├── c1_1.jpeg ... # Sample product images
│ │ ├── product_embeddings.npy
│ │ ├── image_embeddings.npy
│ │ └── image_index.json
│ └── README.md
│
├── vis_rec/ # Flutter frontend (SnapNFind App)
│ ├── lib/
│ │ └── main.dart # Main Flutter UI logic
│ ├── pubspec.yaml
│ ├── build/ # (generated)
│ └── README.md
│
└── README.md # ← You are here


---

## ⚙️ Local Setup & Run

### 🐍 Backend (FastAPI)

#### Step 1. Create & activate virtual environment
bash
cd backend
python -m venv .backvenv
source .backvenv/bin/activate   # Windows: .venv\Scripts\activate

##### Step 2. Install dependencies
pip install -r requirements.txt

Step 3. Run precomputation (if not done)
python precompute_embeddings_images.py

Step 4. Start backend server
uvicorn main:app --reload --port 8000

---The API runs at http://127.0.0.1:8000

Test with:

curl -X POST "http://127.0.0.1:8000/match" \
  -F "file=@data/products/c1_1.jpeg" \
  -F "top_k=6" -F "threshold=0.7"




Model Details
Model	Source	Embedding Dim	Description
CLIP ViT-B/32	Hugging Face / OpenAI	512	Multimodal model for joint vision-language embeddings
Usage	Converts images to feature vectors for cosine similarity comparison

💅 UI / UX Highlights
Feature	Description
🎨 Pitch-black theme	Full black UI with purple-pink gradient accent
🌈 Gradient title text	“SnapNFind” branding with animated color blend
⚙️ Filter modal	Slide-up sheet for price & similarity settings
🖼️ Live preview	Uploaded image preview before search
🧩 Responsive layout	Works perfectly on web, desktop, and mobile
💫 Image carousel	Scrollable image thumbnails with click-to-zoom dialogs
📊 Evaluation Metrics (for research context)
Metric	Description
Cosine Similarity	Measures closeness of embeddings between uploaded and product images.
Threshold filtering	Discards results below similarity cutoff.
Top-K accuracy	Measures how often correct category appears in top-K results.
🔍 Future Improvements

 Integrate Hugging Face Inference API for cloud embedding (no heavy model download)

 Add Vector Database (e.g., FAISS or Pinecone) for scalable search

 Include category-based weighting

 Add user login + favorites system

 Implement progressive loading & shimmer animations for results

 Deploy full-stack via Docker + CI/CD

🧑‍💻 Author

Shanuwaz Shaikh
📧 shaikhshanuwaz533@gmail.com
💡 MCA Student @ VIT Chennai | AI & Cloud Developer | Flutter + ML + DevOps Enthusiast
