from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import Response, HTMLResponse
from image_processor import photo_to_sketch

app = FastAPI(title="Mewarnai API", version="1.0.0")

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10MB

CONTACT_EMAIL = "davidsuwandi@gmail.com"
EFFECTIVE_DATE = "25 Mei 2026"


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/privacy", response_class=HTMLResponse)
def privacy():
    return f"""<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kebijakan Privasi - Mewarnai</title>
<style>
  body {{ font-family: -apple-system, Segoe UI, Roboto, sans-serif; max-width: 760px;
         margin: 0 auto; padding: 24px; line-height: 1.6; color: #222; }}
  h1 {{ color: #e85a5a; }}
  h2 {{ color: #7c50c8; margin-top: 28px; }}
  code {{ background: #f3f3f3; padding: 2px 6px; border-radius: 4px; }}
  footer {{ margin-top: 40px; font-size: 0.9em; color: #777; }}
</style>
</head>
<body>
<h1>Kebijakan Privasi - Mewarnai</h1>
<p><em>Berlaku sejak: {EFFECTIVE_DATE}</em></p>

<p>Aplikasi <strong>Mewarnai</strong> ("Aplikasi") dirancang untuk anak-anak. Kami
menghargai privasi pengguna, khususnya anak-anak, dan berkomitmen melindunginya.
Kebijakan ini menjelaskan data apa yang kami proses dan bagaimana penggunaannya.</p>

<h2>1. Data yang Kami Proses</h2>
<ul>
  <li><strong>Foto:</strong> Saat Anda memilih foto dari galeri atau kamera, foto
  dikirim ke server kami hanya untuk diubah menjadi sketsa garis. Foto
  <strong>diproses sementara di memori dan tidak disimpan</strong> di server kami.
  Hasil sketsa dikirim kembali ke perangkat.</li>
  <li><strong>Karya mewarnai:</strong> Semua gambar yang Anda warnai disimpan
  <strong>hanya di perangkat Anda</strong>, tidak diunggah ke server.</li>
  <li><strong>ID anonim lokal:</strong> Aplikasi membuat ID acak yang disimpan di
  perangkat untuk keperluan internal. ID ini tidak mengandung informasi pribadi.</li>
</ul>
<p>Kami <strong>tidak meminta nama, email, lokasi, kontak, atau data pribadi</strong>
lain. Tidak ada pendaftaran akun.</p>

<h2>2. Iklan</h2>
<p>Aplikasi menampilkan iklan melalui <strong>Google AdMob</strong>. Karena Aplikasi
ditujukan untuk anak-anak, kami mengaktifkan pengaturan
<em>child-directed treatment</em> sehingga hanya iklan yang sesuai untuk keluarga
(rating G) yang ditampilkan, tanpa iklan berbasis minat/personalisasi.</p>
<p>Google dapat memproses data terbatas (mis. pengenal perangkat) untuk menayangkan
iklan non-personalisasi. Lihat kebijakan Google:
<a href="https://policies.google.com/privacy">policies.google.com/privacy</a> dan
<a href="https://support.google.com/admob/answer/6128543">kebijakan AdMob untuk anak</a>.</p>

<h2>3. Privasi Anak (COPPA / GDPR-K)</h2>
<p>Aplikasi mematuhi peraturan perlindungan anak. Kami tidak mengumpulkan data
pribadi dari anak. Iklan dibatasi pada konten yang aman untuk keluarga.</p>

<h2>4. Berbagi Data</h2>
<p>Kami tidak menjual atau membagikan data pribadi. Foto tidak disimpan maupun
dibagikan. Satu-satunya pihak ketiga adalah Google AdMob untuk penayangan iklan.</p>

<h2>5. Keamanan</h2>
<p>Pengiriman foto ke server menggunakan koneksi terenkripsi (HTTPS). Foto tidak
dipertahankan setelah diproses.</p>

<h2>6. Perubahan Kebijakan</h2>
<p>Kebijakan ini dapat diperbarui sewaktu-waktu. Tanggal berlaku akan diperbarui di
bagian atas halaman ini.</p>

<h2>7. Kontak</h2>
<p>Pertanyaan tentang privasi: <a href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a></p>

<footer>&copy; 2026 Mewarnai. Semua hak dilindungi.</footer>
</body>
</html>"""


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
