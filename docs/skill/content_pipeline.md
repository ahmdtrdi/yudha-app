# Skill: Content Pipeline & Question Seeding

> **Tujuan**: Panduan eksekusi cepat bagi AI Agent dan developer untuk menghasilkan, memvalidasi, menyinkronkan, dan mengekspansi bank soal (termasuk soal HOTS) ke dalam database YUDHA.

---

## 1. Quick Execution (TL;DR)

```powershell
# 1. Menjalankan unit test taksonomi & kontrak kurikulum
node --test infra/scripts/question-taxonomy.test.mjs
node --test infra/scripts/learning-contracts.test.mjs

# 2. Menghasilkan / Sinkronisasi canonical questions
node infra/scripts/sync-learning-content.mjs

# 3. Ekspansi bank soal HOTS (High Order Thinking Skills)
node infra/scripts/expand-hots-question-bank.mjs
```

---

## 2. Peta File & Skrip Konten di `infra/scripts/`

| File | Fungsi / Deskripsi |
|---|---|
| `infra/scripts/question-taxonomy.mjs` | Modul kanonik taksonomi, alias subkategori, dan generator kontrak `primarySkillId`. |
| `infra/scripts/question-taxonomy.test.mjs` | Test otomatis memastikan kepatuhan 100% path taksonomi CPNS & BUMN. |
| `infra/scripts/sync-learning-content.mjs` | Skrip utama untuk sinkronisasi kurikulum, validasi integritas soal, dan update manifest. |
| `infra/scripts/expand-hots-question-bank.mjs` | Skrip generator dan validasi untuk memperkaya variasi soal berbasis HOTS. |
| `infra/scripts/learning-fixtures.mjs` | Fixture mock data untuk testing solo learning flow, balanced standard sessions, dll. |

---

## 3. Aturan Standar Pembuatan & Validasi Soal

1. **Format Pilihan Ganda (Standard MCQ)**:
   - Wajib memiliki opsi jawaban yang jelas (umumnya A, B, C, D, E).
   - Jawaban benar (`correct_answer`) harus terverifikasi dan menyertakan pembahasan (`explanation`) yang komprehensif.
2. **Kesesuaian Taksonomi**:
   - Nilai `target`, `category`, `subcategory`, dan `primarySkillId` wajib merujuk ke [`docs/skill/question_taxonomy.md`](./question_taxonomy.md).
3. **Kualitas HOTS (High-Order Thinking Skills)**:
   - Soal penalaran analitis, studi kasus integritas/pelayanan publik, dan numerik logika harus memiliki stimulus konteks yang realistis.
4. **Idempotensi Sinkronisasi**:
   - Skrip tidak boleh menduplikasi soal saat dijalankan berulang kali (gunakan `source_key` atau constraint unik).
