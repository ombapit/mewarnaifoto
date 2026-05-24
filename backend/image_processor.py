import cv2
import numpy as np
from PIL import Image
import io

MAX_SIZE = 2048


def _resize_if_needed(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    if max(h, w) <= MAX_SIZE:
        return img
    scale = MAX_SIZE / max(h, w)
    new_w, new_h = int(w * scale), int(h * scale)
    return cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)


def photo_to_sketch(image_bytes: bytes) -> bytes:
    arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Cannot decode image")

    img = _resize_if_needed(img)

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Pencil sketch: divide gray by blurred inverse
    inv = cv2.bitwise_not(gray)
    blurred = cv2.GaussianBlur(inv, (21, 21), 0)
    sketch = cv2.divide(gray, cv2.bitwise_not(blurred), scale=256.0)

    # Strengthen lines
    _, binary = cv2.threshold(sketch, 230, 255, cv2.THRESH_BINARY)

    # Convert to RGBA — lines black, background white, transparent later if needed
    rgba = cv2.cvtColor(binary, cv2.COLOR_GRAY2BGRA)
    # Make white areas transparent so Godot can overlay on colored canvas
    white_mask = (binary == 255)
    rgba[white_mask, 3] = 0   # transparent background
    rgba[~white_mask, 3] = 255  # opaque black lines

    pil_img = Image.fromarray(cv2.cvtColor(rgba, cv2.COLOR_BGRA2RGBA))
    buf = io.BytesIO()
    pil_img.save(buf, format="PNG")
    return buf.getvalue()
