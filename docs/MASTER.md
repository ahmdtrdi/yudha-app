# YUDHA Repository Master Guide

Dokumen ini adalah pintu masuk untuk memahami cara repository YUDHA bekerja. Untuk keputusan produk, scope, model data, dan kontrak API, sumber utama tetap [`PRD.md`](PRD.md).

## 1. Cara Repository Bekerja

YUDHA adalah monorepo dengan tiga aplikasi utama:

```text
Flutter mobile app
├─ REST ───────→ NestJS App Backend (:3000) ──→ Supabase + Groq/ElevenLabs
└─ Socket.IO ──→ NestJS Game Backend (:3001) ─→ match state + Supabase/Redis
```

- `apps/mobile/`: aplikasi Flutter, navigasi, state UI, REST client, dan Socket.IO client.
- `apps/backend-api/`: NestJS REST API untuk auth, profile, practice, leaderboard, dan AI interview.
- `apps/backend-game/`: NestJS realtime server untuk matchmaking dan battle.
- `contracts/`: bentuk payload dan event yang dipakai bersama.
- `infra/supabase/`: schema, migration, dan panduan pemulihan database Supabase.
- `apps/games/data/`: sumber data pertanyaan game.

Perubahan kontrak REST/Socket, model inti, atau scope fitur harus dicatat di `PRD.md` dalam perubahan yang sama. Kode menunjukkan kondisi implementasi saat ini; PRD juga dapat memuat fitur yang masih direncanakan.

## 2. Cara Membaca Dokumentasi

```text
docs/
├─ PRD.md                         # sumber utama keputusan produk dan arsitektur
├─ MASTER.md                      # peta repo, dokumentasi, dan cara menjalankan app
├─ devlog/
│  ├─ AI-DEVLOG.md                # riwayat pekerjaan AI
│  ├─ BE-DEVLOG.md                # riwayat pekerjaan backend
│  └─ FE-DEVLOG.md                # riwayat pekerjaan frontend
├─ agent/
│  ├─ AGENTS.md                   # aturan kerja umum agent/developer
│  └─ FE-AGENTS.md                # aturan kerja khusus frontend
├─ design/
│  ├─ FE-DESIGN.md                # design system frontend
│  └─ GAME-DESIGN.md              # aturan visual dan mekanik arena
└─ misc/
   ├─ INTERVIEW-AI-CLI.md         # panduan harness interview lokal
   ├─ INTERVIEW-SPEECH-ARCHITECTURE.md
   └─ PULL_REQUEST_TEMPLATE.md
```

Urutan prioritas ketika dokumen berbeda:

1. `PRD.md` untuk keputusan produk, arsitektur, data, dan kontrak.
2. Kode serta migration terbaru untuk perilaku yang sudah benar-benar berjalan.
3. Dokumen di `design/` untuk aturan desain dan `misc/` untuk panduan khusus lainnya.
4. `devlog/` untuk riwayat dan konteks keputusan, bukan spesifikasi terbaru.

File di `agent/` mengatur cara kerja contributor/agent. Saat struktur atau aturan dokumentasi berubah, perbarui `MASTER.md` dan referensi operasional yang terkait.

## 3. Menjalankan Aplikasi

### Prasyarat

- Node.js 20 atau lebih baru dan npm.
- Flutter SDK dengan Dart yang kompatibel dengan `^3.11.1`.
- Project Supabase beserta URL dan key.
- Redis untuk alur realtime yang memerlukannya.

### Siapkan database

Schema dan migration tersedia di `infra/supabase/`. Ikuti [`infra/supabase/README.md`](../infra/supabase/README.md) sebelum membuat atau memulihkan database. PRD menetapkan `infra/supabase/bootstrapv2.sql` sebagai ringkasan schema otoritatif saat ini; jangan menjalankan bootstrap ke database berisi data tanpa meninjau SQL terlebih dahulu.

### Jalankan App Backend

```powershell
Set-Location apps/backend-api
Copy-Item .env.example .env
npm install
npm run start:dev
```

Isi minimal `SUPABASE_URL`, `SUPABASE_KEY`, dan `SUPABASE_SERVICE_ROLE_KEY` di `.env`. Fitur AI interview juga memerlukan `GROQ_API_KEY`; voice TTS memerlukan `ELEVENLABS_API_KEY`. Service berjalan di `http://localhost:3000` secara default.

### Jalankan Game Backend

Buka terminal kedua:

```powershell
Set-Location apps/backend-game
Copy-Item .env.example .env
npm install
npm run start:dev
```

Isi kredensial Supabase dan konfigurasi Redis di `.env`. Implementasi saat ini menjalankan game server di `http://localhost:3001`.

### Jalankan Flutter Mobile

Buka terminal ketiga:

```powershell
Set-Location apps/mobile
flutter pub get
flutter run `
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your_publishable_key
```

Android Emulator memakai default `http://10.0.2.2:3000` dan `http://10.0.2.2:3001` untuk mengakses host. Untuk perangkat fisik atau target lain, tambahkan:

```powershell
--dart-define=YUDHA_API_BASE_URL=http://YOUR_HOST_IP:3000 `
--dart-define=YUDHA_GAME_BASE_URL=http://YOUR_HOST_IP:3001
```

Mobile app tetap dapat boot tanpa konfigurasi Supabase, tetapi fitur berbasis autentikasi akan nonaktif.

## 4. Pemeriksaan Sebelum Merge

Jalankan pemeriksaan yang sesuai dengan area perubahan:

```powershell
# Di masing-masing apps/backend-* folder
npm run build
npm run test
npm run lint

# Di apps/mobile
flutter analyze
flutter test
```

Checklist dokumentasi:

- kontrak atau keputusan produk berubah → perbarui `docs/PRD.md`;
- perubahan kode selesai → tambahkan ringkasan ke devlog role terkait;
- panduan repo atau susunan dokumen berubah → perbarui `docs/MASTER.md`;
- jangan memakai devlog sebagai sumber spesifikasi terbaru.
