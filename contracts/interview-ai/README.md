# Interview AI Contracts

Folder ini menyimpan contract tipis antara mobile app, backend API, dan output terstruktur dari LLM.

## Backend Ownership

- Mobile hanya mengirim intent sesi dan jawaban user.
- Backend bertanggung jawab mengambil context perusahaan dari storage internal.
- Prompt, harness, dan pemilihan model tidak di-hardcode di mobile.
- Knob harness disiapkan lewat environment backend, bukan dokumen implementasi di repo.

## Endpoint MVP

### `POST /interview/sessions`

Memulai sesi baru. Backend akan resolve context perusahaan berdasarkan identifier yang dikirim mobile.

Request:

```json
{
  "mode": "realistic",
  "targetRole": "Management Trainee",
  "companyId": "bumn_taspen",
  "language": "id",
  "responseStyle": "text"
}
```

Gunakan `mode: "realistic"` untuk simulasi interview tanpa feedback di tengah sesi. Gunakan `mode: "coaching"` untuk latihan interaktif dengan feedback setelah setiap jawaban.

Response:

```json
{
  "sessionId": "sess_123",
  "status": "active",
  "companyId": "bumn_taspen",
  "openingQuestion": {
    "turnId": "turn_q_001",
    "text": "Ceritakan tentang diri Anda dan alasan Anda tertarik bergabung di perusahaan ini."
  }
}
```

### `POST /interview/sessions/:sessionId/turns`

Mengirim jawaban user. Backend akan menggabungkan transcript session dengan context perusahaan yang tersimpan di backend.

Request:

```json
{
  "idempotencyKey": "answer_01_8f33a1",
  "answer": {
    "type": "text",
    "text": "Saya tertarik bergabung karena ingin berkontribusi pada layanan publik..."
  }
}
```

Response:

```json
{
  "sessionId": "sess_123",
  "status": "active",
  "evaluation": {
    "overallScore": 78,
    "dimensions": {
      "relevance": 82,
      "clarity": 75,
      "structure": 70,
      "confidence": 79,
      "impact": 74,
      "authenticity": 88
    },
    "strengths": [
      "Jawaban relevan dengan motivasi melamar.",
      "Nada jawaban terdengar tulus."
    ],
    "improvements": [
      "Tambahkan contoh konkret agar lebih meyakinkan.",
      "Struktur jawaban bisa dibuat lebih runtut."
    ],
    "suggestedRewrite": "Saya tertarik bergabung dengan perusahaan ini karena ..."
  },
  "nextQuestion": {
    "turnId": "turn_q_002",
    "text": "Ceritakan situasi ketika Anda menghadapi konflik dalam tim."
  }
}
```

### `GET /interview/sessions/:sessionId`

Mengambil state sesi, transcript, dan ringkasan evaluasi terakhir.

### `POST /interview/sessions/:sessionId/complete`

Menutup sesi dan menghasilkan final summary.

## Structured LLM Output

Gunakan schema di `contracts/interview-ai/interview-evaluation.schema.json` agar parsing backend tetap stabil walau provider LLM berubah.

Field `candidateFacts` menyimpan fakta eksplisit dari jawaban kandidat, seperti nama, status pendidikan, atau bidang studi. Fakta ini dipakai backend sebagai memori percakapan singkat agar pertanyaan lanjutan tetap natural tanpa mengarang informasi kandidat.

## Idempotency

Mobile wajib membuat `idempotencyKey` baru untuk setiap jawaban. Retry transport untuk jawaban yang sama harus memakai key yang sama agar backend tidak memanggil LLM dua kali.
