# Interview Speech Architecture

## Goal

Tambahkan voice interaction ke interview tanpa membongkar pipeline evaluasi yang sudah text-first.

Prinsip utamanya:

1. Audio adalah input-output UX layer, bukan sumber kebenaran domain.
2. Teks transcript tetap menjadi payload resmi ke `submitAnswer`.
3. TTS dan STT harus dapat diganti provider-nya tanpa mengubah orchestration interview.

## Recommended Flow

### Candidate answer

1. UI rekam audio kandidat.
2. UI upload audio ke `POST /interview/sessions/:sessionId/speech/transcriptions`.
3. Backend melakukan STT dan mengembalikan transcript.
4. UI tampilkan transcript untuk ditinjau atau diedit ringan.
5. UI kirim transcript final ke `POST /interview/sessions/:sessionId/turns`.

### Interviewer question

1. Backend tetap mengembalikan `nextQuestion.text` dari pipeline interview yang ada.
2. Jika `responseStyle = voice`, UI memanggil `GET /interview/sessions/:sessionId/speech/questions/:turnId/audio`.
3. Backend melakukan TTS dari teks pertanyaan yang sudah tersimpan dan mengembalikan audio stream.

## Why This Shape Fits The Current Backend

- `InterviewService` tetap fokus pada session lifecycle, scoring, rolling summary, dan final summary.
- Speech tidak menambah kompleksitas pada idempotency answer karena transcript dikirim sebagai teks biasa.
- Harness dan prompt iteration tetap relevan karena sumber evaluasi tetap teks.
- `responseStyle` yang sudah ada sekarang benar-benar menjadi kontrak produk, bukan placeholder.

## Current Provider Split

### TTS (Primary Free Tier: Groq Orpheus | Modular Alternative: ElevenLabs)

- Primary Provider: Groq Orpheus
- Default model: `canopylabs/orpheus-v1-english`
- Reason:
  - Free tier friendly, zero cost execution for voice generation
  - Built-in expressive vocal directions (`[cheerful]`, `[whisper]`, etc.)
  - Accessible via OpenAI-compatible `/audio/speech` endpoint on Groq
- Modular Alternative: ElevenLabs (`eleven_flash_v2_5`) selectable via `INTERVIEW_TTS_PROVIDER=elevenlabs`

### STT

- Provider: Groq Whisper
- Default model: `whisper-large-v3-turbo`
- Reason:
  - lebih hemat untuk transkripsi candidate answer
  - sudah satu keluarga integrasi dengan stack Groq yang dipakai interview LLM
  - cukup untuk turn-based voice button sebelum kita masuk ke streaming realtime

## Backend Components

### Provider abstraction

- `INTERVIEW_SPEECH_TRANSCRIPTION_CLIENT`
- `INTERVIEW_SPEECH_SYNTHESIS_CLIENT`

Kedua token ini membuat provider speech bisa diganti tanpa menyentuh controller atau orchestration interview.

### Services

- `GroqSttService`
  - upload audio ke endpoint transcription
  - mengembalikan teks transcript dan metadata dasar
- `GroqTtsService`
  - sintesis suara interviewer menggunakan Groq Orpheus (`canopylabs/orpheus-v1-english`) untuk Free Tier
- `ElevenLabsTtsService`
  - sintesis suara interviewer menggunakan ElevenLabs API (modular fallback)
- `InterviewSpeechService`
  - cek ownership session
  - validasi audio upload
  - membangun prompt STT ringan dari konteks interview
  - memastikan hanya `question` turn yang bisa disintesis

### Validation

- `InterviewAudioValidator`
  - batasi ukuran file
  - batasi mime type browser recorder yang umum

## API Contract

### Start session

`POST /interview/sessions`

`responseStyle` sekarang menerima:

- `text`
- `voice`

Jika `voice`, response question juga menyertakan `audioAvailable: true`.

### Transcribe answer audio

`POST /interview/sessions/:sessionId/speech/transcriptions`

Multipart field:

- `audio`

Response shape:

```json
{
  "sessionId": "uuid",
  "responseStyle": "voice",
  "transcript": {
    "text": "Saya tertarik melamar karena ...",
    "language": "id",
    "durationSeconds": 12.4,
    "provider": "groq"
  },
  "answer": {
    "type": "text",
    "text": "Saya tertarik melamar karena ..."
  }
}
```

### Synthesize interviewer question

`GET /interview/sessions/:sessionId/speech/questions/:turnId/audio`

Response:

- binary audio stream
- `Content-Type` mengikuti output ElevenLabs
- `X-Interview-Speech-Provider: elevenlabs`

## Environment Variables

Lihat `apps/backend-api/.env.example` untuk konfigurasi baru:

- `INTERVIEW_AUDIO_MAX_BYTES`
- `INTERVIEW_STT_BASE_URL`
- `INTERVIEW_STT_MODEL`
- `INTERVIEW_STT_TIMEOUT_MS`
- `INTERVIEW_STT_API_KEY` optional
- `ELEVENLABS_API_KEY`
- `INTERVIEW_TTS_BASE_URL`
- `INTERVIEW_TTS_VOICE_ID`
- `INTERVIEW_TTS_MODEL_ID`
- `INTERVIEW_TTS_OUTPUT_FORMAT`
- `INTERVIEW_TTS_TIMEOUT_MS`

## Recommended UI Behavior

Untuk voice mode, gunakan pola berikut:

1. Tap record.
2. Stop record.
3. Upload audio.
4. Tampilkan transcript.
5. Izinkan user edit singkat.
6. Submit transcript sebagai answer text.
7. Autoplay next interviewer audio jika tersedia.

Jangan submit audio mentah langsung ke `submitAnswer` karena itu akan mengikat domain interview ke format media.

## What This Does Not Solve Yet

- realtime streaming STT
- VAD atau endpoint detection di server
- transcript caching atau audit trail audio
- TTS caching per question turn
- background jobs untuk retry speech provider

## Next Good Iteration

1. Tambah persistence opsional untuk metadata speech per turn.
2. Tambah cache TTS by `questionTurnId` agar replay tidak memanggil ElevenLabs berulang.
3. Jika UI nanti butuh partial transcript live, tambahkan adapter streaming terpisah tanpa mengubah endpoint turn submission yang sekarang.
