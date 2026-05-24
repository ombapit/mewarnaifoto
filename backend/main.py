from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import Response
from image_processor import photo_to_sketch

app = FastAPI(title="Mewarnai API", version="1.0.0")

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10MB


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/process-image")
async def process_image(file: UploadFile = File(...)):
    if file.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(status_code=415, detail="Format tidak didukung. Gunakan JPG/PNG.")

    data = await file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Ukuran file maksimal 10MB.")

    try:
        sketch_bytes = photo_to_sketch(data)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    return Response(
        content=sketch_bytes,
        media_type="image/png",
        headers={"Content-Disposition": "inline; filename=sketch.png"},
    )
