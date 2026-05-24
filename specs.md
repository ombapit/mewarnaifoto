# Mewarnai App — Game Specs

## Stack
- **Frontend / Game**: Godot 4.x (Android export)
- **Backend**: FastAPI (Python 3.13)
- **Image Processing**: OpenCV + PIL (sketch conversion)
- **Storage**: Local device + optional cloud sync

---

## Core Features

### 1. Upload Foto
- User pilih foto dari galeri device atau ambil kamera langsung
- Preview foto sebelum diproses
- Validasi: format JPG/PNG, max 10MB
- Godot → `FileDialog` + `CameraServer` → kirim ke FastAPI via multipart upload

### 2. Konversi ke Sketch (FastAPI)
**Pipeline:**
```
foto asli
  → grayscale
  → gaussian blur
  → edge detection (Canny / Pencil Sketch OpenCV)
  → threshold + invert
  → output PNG transparan (garis hitam, background putih)
```
- Endpoint: `POST /process-image`
- Response: PNG sketch siap warnai
- Simpan sketch + foto asli per user session

### 3. Mode Mewarnai
- Canvas berbasis Godot `SubViewport` + `Polygon2D` / flood fill shader
- **Flood fill**: tap area → isi warna (shader-based, cepat)
- Toolbar krayon:
  - Pilih warna dari palette (12 warna default + custom color picker)
  - Ukuran brush: kecil / sedang / besar
  - Eraser / undo (max 20 langkah)
  - Zoom in/out dengan pinch gesture
- Garis sketch tetap hitam di atas layer warna (layer system)

### 4. Preview & Galeri
- **Full screen preview**: tombol preview → tampil gambar penuh tanpa UI
- **Simpan**: export hasil mewarnai ke JPG ke galeri device
- **Galeri in-game**: grid thumbnail semua karya selesai
  - Tap → lihat full screen
  - Long press → opsi: hapus, share, set wallpaper

### 5. Sticker & Dekorasi
- Mode dekorasi aktif setelah selesai mewarnai (layer terpisah, tidak merusak gambar)
- **Sticker**: koleksi bintang, bunga, emoji, hewan kecil — drag & drop, resize, rotate
- **Frame**: pilih frame foto (polaroid, bunga, geometris) yang membungkus hasil akhir
- **Teks**: tambah teks dengan font lucu, pilih warna + ukuran
- Sticker & teks di-flatten saat export ke JPG

## Technical Decisions

| Topik | Keputusan |
|-------|-----------|
| User system | No login — guest only, UUID lokal di-generate sekali simpan di `user://uuid.dat` |
| Auto-save | Setiap 30 detik + saat app pause/background (`NOTIFICATION_WM_WINDOW_FOCUS_OUT`) |
| Backend | VPS (cloud) — FastAPI + Uvicorn, domain/IP dikonfigurasi di `config.gd` |
| Export resolusi | Full resolution foto asli (tidak di-downscale saat export JPG) |
| Working canvas | Downscale ke max 2048px sisi terpanjang saat proses & edit (performa), upsample ke full res saat export |
| Flood fill | CPU BFS (GDScript) untuk akurasi, max canvas 2048×2048 — bisa upgrade ke compute shader v2 |
| Layer order | `background (putih)` → `color fill` → `sketch garis` → `magic brush` → `sticker/teks` |
| Save format | `artwork_{uuid}_{timestamp}/` folder: `meta.json` + `layer_color.png` + `layer_sticker.png` + `thumb.jpg` |
| Share | Android native `Intent` via Godot `JavaClassWrapper` — support WhatsApp, Instagram, dll |
| Offline | Fitur inti (warnai, galeri, sticker) 100% offline. Konversi sketch butuh VPS. |
| Error sketch | Jika upload gagal/timeout → tampil retry dialog, max 3x retry dengan exponential backoff |
| Sticker assets | PNG individual, bundled di `res://assets/stickers/`, dikategorikan folder |
| Watermark | Tidak ada |

---

## Architecture

```
[Godot Android App]
    ↕ HTTP/REST
[FastAPI Server]
    ↕
[OpenCV Processing]
    ↕
[File Storage / SQLite]
```

### API Endpoints
| Method | Endpoint | Fungsi |
|--------|----------|--------|
| POST | `/process-image` | Upload foto → return sketch PNG (2048px max) |
| GET | `/health` | Cek koneksi VPS sebelum upload |

> Galeri, save, delete — semua lokal device. Tidak perlu endpoint server.

---

## Tech Dependencies

### Godot
- `HTTPRequest` node — komunikasi ke FastAPI
- `Image` + `ImageTexture` — handle PNG sketch
- Custom shader — flood fill + brush effects
- `FileAccess` — simpan/load lokal

### FastAPI
```
fastapi
uvicorn
python-multipart
opencv-python
Pillow
numpy
```

---

## Milestones

| Phase | Scope | Target |
|-------|-------|--------|
| MVP | Upload + Sketch + Basic Color + Gallery | 3 minggu |
| v1.1 | Sticker & Dekorasi | +2 minggu |
| v1.2 | AI Palette + Challenge Mode | +3 minggu |
| v2.0 | Multiplayer + AR Mode | +1 bulan |

---

## Platform
- Android 8.0+ (API 26)
- Portrait mode primary
- Tablet support (responsive UI)
- Offline mode: semua fitur inti jalan tanpa internet (server opsional untuk AI features)
