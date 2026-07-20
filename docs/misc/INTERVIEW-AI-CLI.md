# Interview AI CLI Guide

Panduan ini menjelaskan cara menjalankan interview AI dari terminal untuk menguji kualitas respons Groq, context perusahaan, dan alur percakapan tanpa bergantung pada Supabase.

## Prasyarat

- Jalankan command dari folder `apps/backend-api`.
- Pastikan dependency backend sudah terpasang dengan `npm install`.
- Buat file `.env` dari `.env.example`.
- Isi `GROQ_API_KEY` dengan API key Groq milik Anda.

```bash
cd apps/backend-api
cp .env.example .env
```

Minimal environment untuk CLI:

```dotenv
GROQ_API_KEY=your_groq_api_key_here
INTERVIEW_LLM_MODEL=openai/gpt-oss-120b
```

Jangan commit file `.env` atau membagikan API key melalui chat, screenshot, maupun pull request.

## Menjalankan Interview

Jalankan simulasi interaktif:

```bash
npm run interview:harness -- --mode=realistic --turns=5
```

CLI akan meminta Anda memilih perusahaan:

```text
Pilih perusahaan untuk simulasi:
1. PT Pertamina (Persero)
2. PT Bank Mandiri (Persero) Tbk
3. Kementerian Keuangan Republik Indonesia
Pilihan [1-3]:
```

Setelah memilih perusahaan, jawab pertanyaan interviewer melalui terminal. Ketik `:quit` untuk menghentikan sesi lebih awal.

Context perusahaan dibaca dari fixture JSON lokal. Supabase tidak diperlukan untuk menjalankan harness ini.

## Mode Interview

Gunakan `realistic` untuk simulasi interview seperti kondisi nyata. Feedback per jawaban disimpan secara internal dan hanya ringkasan akhir yang ditampilkan.

```bash
npm run interview:harness -- --mode=realistic --turns=5
```

Gunakan `coaching` untuk latihan interaktif. Evaluasi, kekuatan, saran perbaikan, dan contoh rewrite ditampilkan setelah setiap jawaban.

```bash
npm run interview:harness -- --mode=coaching --turns=5
```

## Memilih Perusahaan Langsung

Gunakan `--company` untuk melewati menu interaktif:

```bash
npm run interview:harness -- --mode=realistic --turns=5 --company=pertamina
npm run interview:harness -- --mode=realistic --turns=5 --company=bank-mandiri
npm run interview:harness -- --mode=realistic --turns=5 --company=kementerian-keuangan
```

| Company ID             | Nama                                    | Default role                   |
| ---------------------- | --------------------------------------- | ------------------------------ |
| `pertamina`            | PT Pertamina (Persero)                  | Management Trainee             |
| `bank-mandiri`         | PT Bank Mandiri (Persero) Tbk           | Officer Development Program    |
| `kementerian-keuangan` | Kementerian Keuangan Republik Indonesia | Staf Pengelola Keuangan Negara |

Gunakan `--role` untuk menguji posisi lain:

```bash
npm run interview:harness -- --mode=realistic --turns=5 --company=pertamina --role="Data Analyst"
```

## Memeriksa Prompt Tanpa Memanggil Groq

Gunakan `--dry-run` untuk melihat prompt lengkap tanpa memakai API key dan tanpa mengonsumsi kuota Groq:

```bash
npm run interview:harness -- --dry-run --company=bank-mandiri
```

Gunakan `--show-prompt` untuk menampilkan prompt pada setiap putaran interview live:

```bash
npm run interview:harness -- --mode=coaching --turns=2 --company=pertamina --show-prompt
```

Hindari `--show-prompt` pada terminal yang direkam atau dibagikan karena prompt dapat memuat jawaban kandidat.

## Referensi Opsi

| Opsi            | Nilai                   | Default                        | Kegunaan                                |
| --------------- | ----------------------- | ------------------------------ | --------------------------------------- |
| `--mode`        | `realistic`, `coaching` | `realistic`                    | Menentukan kapan feedback ditampilkan.  |
| `--turns`       | Bilangan positif        | `INTERVIEW_MAX_TURNS` atau `5` | Membatasi jumlah jawaban kandidat.      |
| `--company`     | Company ID              | Menu interaktif                | Memilih fixture perusahaan lokal.       |
| `--role`        | Teks bebas              | Role bawaan fixture            | Menguji posisi yang berbeda.            |
| `--dry-run`     | Tanpa nilai             | Nonaktif                       | Menampilkan preview prompt tanpa Groq.  |
| `--show-prompt` | Tanpa nilai             | Nonaktif                       | Menampilkan prompt pada interview live. |

## Membaca Hasil

Setiap panggilan Groq yang berhasil mencatat latency dan penggunaan token:

```text
Groq completion model=openai/gpt-oss-120b latencyMs=1284 promptTokens=1083 completionTokens=402 totalTokens=1485
```

Pada akhir sesi, CLI menampilkan ringkasan:

- `overallScore`: rata-rata penilaian seluruh jawaban.
- `dimensions`: rata-rata relevance, clarity, structure, confidence, impact, dan authenticity.
- `strengths`: kekuatan kandidat yang terdeteksi selama sesi.
- `improvements`: saran perbaikan jawaban kandidat.
- `answerCount`: jumlah jawaban yang dievaluasi.

## Environment Opsional

Nilai bawaan berikut sudah cocok untuk pengujian MVP:

```dotenv
INTERVIEW_LLM_BASE_URL=https://api.groq.com/openai/v1
INTERVIEW_LLM_MODEL=openai/gpt-oss-120b
INTERVIEW_LLM_TIMEOUT_MS=15000
INTERVIEW_LLM_MAX_OUTPUT_TOKENS=2048
INTERVIEW_LLM_MAX_RETRIES=1
INTERVIEW_LLM_REASONING_EFFORT=low
INTERVIEW_MAX_TURNS=5
```

Naikkan `INTERVIEW_LLM_TIMEOUT_MS` jika koneksi sering lambat. Jangan menurunkan `INTERVIEW_LLM_MAX_OUTPUT_TOKENS` terlalu jauh karena output JSON terstruktur dapat terpotong.

## Troubleshooting

### `INTERVIEW_LLM_API_KEY is missing`

Isi `GROQ_API_KEY` di `apps/backend-api/.env`, lalu jalankan ulang harness dari folder `apps/backend-api`.

### `The interview model is temporarily unavailable`

Periksa log tepat sebelum error. Penyebab yang umum adalah API key tidak valid, rate limit Groq, model sedang tidak tersedia, atau output JSON dari model gagal memenuhi schema setelah retry.

### `The interview model timed out`

Naikkan timeout di `.env`:

```dotenv
INTERVIEW_LLM_TIMEOUT_MS=30000
```

### `Unknown --company value`

Gunakan salah satu ID yang tersedia:

```text
pertamina
bank-mandiri
kementerian-keuangan
```

### Menguji Prompt Saat Groq Tidak Tersedia

Gunakan dry-run:

```bash
npm run interview:harness -- --dry-run --company=pertamina
```

## Lokasi Fixture

Fixture perusahaan lokal tersimpan di:

```text
apps/backend-api/src/interview/harness/fixtures/companies
```

Fixture berisi profile, context terkurasi, prioritas context, default role, dan URL sumber resmi. Data ini dipakai untuk eksperimen lokal sebelum context perusahaan dikelola melalui Supabase.
