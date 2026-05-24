# Mewarnai — Game Mewarnai Anak

Aplikasi Android: upload/foto → ubah jadi sketsa hitam-putih → warnai pakai krayon → simpan ke galeri.

- **Game**: Godot 4.6 (GDScript, export Android)
- **Backend**: FastAPI + OpenCV (konversi foto → sketsa)

---

## Fitur

- Pilih foto dari galeri / SD card (SAF) atau ambil dari kamera
- Konversi foto jadi sketsa garis (pencil sketch, OpenCV)
- Mewarnai bebas pakai krayon (drag), 12 warna + color picker, 3 ukuran brush
- Undo (20 langkah), autosave tiap 30 detik
- Galeri karya: lihat full screen, lanjut warnai draft, bagikan, hapus
- UI ramah anak: tombol bouncy, krayon animasi, background bergerak, background music

---

## Struktur

```
mewarnai/
├── specs.md                 # spesifikasi fitur & keputusan teknis
├── backend/                 # FastAPI server
│   ├── main.py              # endpoint /health, /process-image
│   ├── image_processor.py   # pipeline foto → sketsa (OpenCV)
│   └── requirements.txt
└── godot/                   # project Godot
    ├── project.godot
    ├── scenes/              # Main, Upload, Coloring, Gallery
    ├── scripts/             # GDScript (autoload + scene + widget)
    ├── addons/GodotGetImage/ # plugin galeri/kamera Android
    └── assets/audio/bgm.mp3 # musik latar (sediakan sendiri)
```

---

## Setup Backend

Butuh Python 3.13+. Pakai `uv` (atau venv biasa).

```bash
cd backend
uv venv
uv pip install -r requirements.txt
.venv\Scripts\uvicorn.exe main:app --host 0.0.0.0 --port 8000
```

Cek: buka `http://localhost:8000/health` → `{"status":"ok"}`

Deploy produksi: jalankan di VPS, buka port 8000.

---

## Setup Game (Godot)

1. Download **Godot 4.6** (Standard) dari https://godotengine.org
2. Import project dari folder `godot/`
3. Set alamat server di [godot/scripts/GlobalConfig.gd](godot/scripts/GlobalConfig.gd):
   ```gdscript
   const API_BASE_URL_DEFAULT = "http://IP_VPS_ANDA:8000"
   ```
4. Tekan F5 untuk jalankan (desktop pakai FileDialog untuk pilih foto)

---

## Build Android

1. Project → **Install Android Build Template**
2. Editor Settings → Export → Android: set path **Android SDK** + **JDK 17**
3. Enable plugin: Project Settings → Plugins → **GodotGetImage** ✓
4. Export → Android preset:
   - **Use Gradle Build** ✓ (wajib agar plugin ter-bundle)
   - **Permissions**: `CAMERA`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`
   - **Keystore** (release): `mewarnai-release.keystore`, alias `mewarnai`
5. Export Project → hasil `.apk`

### Keystore

File `godot/mewarnai-release.keystore` (di-ignore git). **Backup & jaga password** — hilang = tak bisa update app di Play Store.

Generate ulang:
```bash
keytool -genkeypair -v -keystore mewarnai-release.keystore -alias mewarnai \
  -keyalg RSA -keysize 2048 -validity 10000
```

---

## Musik Latar

Taruh file `bgm.mp3` (atau `bgm.ogg`) di `godot/assets/audio/`. Royalty-free dari Pixabay/OpenGameArt/Kenney. App tetap jalan tanpa file (silent). Tombol 🔊/🔇 di dashboard.

---

## Alur

```
Upload → POST /process-image (VPS) → sketsa PNG
       → Coloring (warnai, autosave) → Gallery (lihat/lanjut/bagikan)
```

Sketsa butuh server. Mewarnai, galeri, simpan = 100% offline di device.
