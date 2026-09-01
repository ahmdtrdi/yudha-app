# Skill: Deploy Web to Vercel (YUDHA Frontend)

> **Tujuan**: Panduan eksekusi kilat bagi AI Agent dan developer untuk mendeploy aplikasi Flutter Web (`apps/mobile`) ke Vercel menggunakan akun yang sudah login di CLI maupun konfigurasi Vercel yang sudah terhubung.

---

## 1. Quick Execution (TL;DR untuk AI Agent)

Jika Anda adalah AI Agent yang diminta untuk melakukan deploy ke Vercel, jalankan langkah berikut secara berurutan:

```powershell
# 1. Pastikan berada di root direktori project
cd C:\Ido\Contest\pidi\yudha-app

# 2. Verifikasi status akun Vercel
vercel whoami

# 3. Deploy Preview (staging / test)
vercel --cwd apps/mobile

# 4. Atau Deploy langsung ke Production
vercel --prod --cwd apps/mobile
```

*(Catatan: Konfigurasi project ID `.vercel/project.json` sudah terhubung ke project `yudha-app` milik tim `team_Uxof9SZvuPWoP83EMK8HzyKb`)*.

---

## 2. Arsitektur & Konfigurasi Deployment

Aplikasi frontend YUDHA dibangun menggunakan **Flutter Web** yang di-build dalam mode static release dan dilayani melalui server routing Vercel (`apps/mobile/vercel.mjs`).

### File Konfigurasi Kunci:
1. **`.vercel/project.json`** (Root):
   - `projectId`: `prj_NIAKg8GHwICjHV58VYakGWgujGTq`
   - `orgId`: `team_Uxof9SZvuPWoP83EMK8HzyKb`
   - `projectName`: `yudha-app`
2. **`apps/mobile/vercel.mjs`**:
   - `installCommand`: `bash tool/install_flutter.sh`
   - `buildCommand`: `bash tool/build_web.sh`
   - `outputDirectory`: `build/web`
   - `rewrites`: Meneruskan `/api-proxy/:path*` ke `process.env.YUDHA_API_BASE_URL` dan single-page fallback `/(.*)` ke `/index.html`.
3. **`apps/mobile/tool/install_flutter.sh`**:
   - Mendownload Flutter SDK versi **3.44.6** (atau sesuai env `FLUTTER_VERSION`).
   - Menjalankan `flutter precache --web` dan `flutter pub get`.
4. **`apps/mobile/tool/build_web.sh`**:
   - Menghasilkan file `.dart_tool/vercel-defines.env` dari environment variables Vercel.
   - Menjalankan `flutter build web --release --no-wasm-dry-run --dart-define-from-file=...`.

---

## 3. Environment Variables yang Wajib di Vercel Dashboard

Pastikan environment variables berikut sudah terpasang di Vercel Project Settings (Production / Preview):

| Nama Environment Variable | Deskripsi / Nilai | Sifat |
|---|---|---|
| `SUPABASE_URL` | URL instance Supabase project YUDHA (e.g. `https://xxx.supabase.co`) | **Wajib** |
| `SUPABASE_PUBLISHABLE_KEY` | Public Anon/Publishable Key Supabase | **Wajib** |
| `YUDHA_API_BASE_URL` | Base URL Backend REST API (e.g. `https://api.yudha.app` atau link backend Vercel/Railway) | **Wajib** |
| `YUDHA_GAME_BASE_URL` | Base URL Game Realtime Server (e.g. `https://game.yudha.app`) | **Wajib** |
| `FIREBASE_WEB_VAPID_KEY` | Public VAPID Key untuk Web Push Notification Firebase | Opsional |
| `FLUTTER_VERSION` | Versi Flutter SDK (Default: `3.44.6`) | Opsional |

---

## 4. Checklist Pra-Deploy & Post-Deploy

### Sebelum Deploy:
- [ ] Pastikan kode di `apps/mobile` tidak mengalami error static analysis:
  ```powershell
  cd apps/mobile
  flutter analyze
  ```
- [ ] Pastikan tidak ada file binary atau folder build lama yang terkunci di git.

### Setelah Deploy:
- [ ] Buka URL deployment yang dihasilkan oleh CLI Vercel.
- [ ] Buka Developer Console (F12) di browser:
  - Pastikan tidak ada error 404 pada asset `flutter.js` atau `main.dart.js`.
  - Pastikan panggilan ke `/api-proxy/` berhasil ter-forward ke backend REST.
- [ ] Cek alur autentikasi (Login / Sign Up) apakah Supabase client berhasil inisialisasi.

---

## 5. Troubleshooting Umum

1. **Error `Missing required build environment variable` di build logs**:
   - *Penyebab*: Salah satu dari 4 variabel wajib di Bagian 3 belum dimasukkan ke dashboard Vercel.
   - *Solusi*: Masuk ke Vercel Dashboard > Project Settings > Environment Variables, tambahkan variabel yang hilang, lalu lakukan redeploy.
2. **Error `YUDHA_API_BASE_URL is required to configure the API proxy`**:
   - *Penyebab*: File `apps/mobile/vercel.mjs` membutuhkan env `YUDHA_API_BASE_URL` saat evaluate config.
   - *Solusi*: Pastikan `YUDHA_API_BASE_URL` terpasang di scope build & runtime.
3. **PWA / Service Worker Stale Cache**:
   - *Penyebab*: Browser menyimpan service worker `yudha_service_worker.js` versi lama.
   - *Solusi*: Header `Cache-Control: no-cache, no-store, must-revalidate` sudah diset otomatis di `apps/mobile/vercel.mjs`. Lakukan Hard Refresh (`Ctrl+F5` atau `Cmd+Shift+R`).
