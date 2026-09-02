# Skill: Supabase & Database Operations

> **Tujuan**: Panduan eksekusi cepat bagi AI Agent dan developer untuk mengelola migrasi schema, bootstrap database, postchecks, dan pengujian SQL di Supabase/PostgreSQL.

---

## 1. Quick Rules & Prinsip Database

1. **Bootstrap & Schema Reference**:
   - `infra/supabase/bootstrapv2.sql` adalah schema otoritatif dan komprehensif.
   - **PERINGATAN**: Jangan menjalankan `bootstrapv2.sql` pada database yang sudah aktif berisi data produksi/staging tanpa review mendalam karena dapat me-reset tabel.
2. **Aturan Migrasi Inkremental**:
   - File migrasi baru diletakkan di `infra/supabase/migrations/` dengan format: `YYYYMMDDHHMMSS_deskripsi_singkat.sql`.
   - Selalu buat migrasi yang *idempotent* atau aman (gunakan `IF EXISTS`, `IF NOT EXISTS`, transaction `BEGIN ... COMMIT`).
3. **Postcheck Verification**:
   - Script verifikasi pasca-migrasi diletakkan di `infra/supabase/postchecks/`.
   - Postcheck memastikan data yang termigrasi tetap mematuhi constraint (misal canonical taxonomy).

---

## 2. Struktur Direktori Database (`infra/supabase/`)

```text
infra/supabase/
├─ bootstrapv2.sql            # Otoritatif full schema bootstrap
├─ migrations/                # SQL migration berurutan berdasarkan timestamp
│  ├─ 20260901090000_learning_v2_analytics_foundation.sql
│  ├─ 20260901130000_normalize_question_taxonomy.sql
│  ├─ 20260901140000_canonicalize_question_categories.sql
│  └─ 20260901160000_solo_three_card_hand.sql
├─ postchecks/                # Script verifikasi integritas data setelah migrasi
├─ tests/                     # File test SQL (misal: pgTAP atau skenario Solo test)
└─ seed_interview_companies.sql
```

---

## 3. Checklist Menambahkan Migration Baru

1. Buat file migration di `infra/supabase/migrations/` dengan timestamp saat ini:
   ```sql
   BEGIN;

   -- Modifikasi tabel / index / RLS policies
   ALTER TABLE public.questions ...;

   COMMIT;
   ```
2. Jika migrasi menyangkut normalisasi data penting, buat file postcheck pendamping di `infra/supabase/postchecks/`.
3. Jalankan script/test terkait di `infra/scripts/` untuk memastikan backend dan contract tetap sinkron.
4. Catat perubahan schema ke dalam `docs/devlog/BE-DEVLOG.md` dan perbarui `PRD.md` jika mengubah kontrak publik.
