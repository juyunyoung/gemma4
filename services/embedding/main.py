from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import os

app = FastAPI(title="BGE-M3 Embedding Server")

MODEL_NAME = os.getenv("MODEL_NAME", "BAAI/bge-m3")
model: SentenceTransformer | None = None


@app.on_event("startup")
async def load_model():
    global model
    model = SentenceTransformer(MODEL_NAME)
    print(f"모델 로드 완료: {MODEL_NAME}")


class EmbedRequest(BaseModel):
    texts: list[str]


class EmbedResponse(BaseModel):
    embeddings: list[list[float]]
    model: str
    dimensions: int


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_NAME, "loaded": model is not None}


@app.post("/embed", response_model=EmbedResponse)
def embed(req: EmbedRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="모델 로딩 중")
    if not req.texts:
        raise HTTPException(status_code=400, detail="texts 배열이 비어 있습니다")

    embeddings = model.encode(req.texts, normalize_embeddings=True).tolist()
    return EmbedResponse(
        embeddings=embeddings,
        model=MODEL_NAME,
        dimensions=len(embeddings[0]),
    )
