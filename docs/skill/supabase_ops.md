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

---

## 4. Mengisi Data Learning Analytics Secara Manual

Gunakan fixture hanya untuk akun development/staging yang boleh menerima data sintetis. Workflow ini menulis melalui Supabase REST API dengan service-role, memberi label `synthetic_fixture`, dan tetap mematuhi ledger `learning_attempts` yang append-only.

```powershell
# Jalankan dari root repository. Nilai konfirmasi wajib sama persis dengan user ID.
node infra/scripts/learning-v2-cli.mjs fixture seed `
  --user-id <USER_UUID> `
  --confirm-disposable <USER_UUID> `
  --run-key <RUN_KEY> `
  --scenario mixed
```

Fixture `mixed` menambahkan 39 percobaan Solo pada empat skill, lalu mengantrekan rebuild proyeksi. Jalankan backend worker atau tunggu worker deployment memproses job sebelum membaca `GET /learning/dashboard` dan `GET /learning/recommendations/current`.

Jika data uji harus dikeluarkan dari analitik, jangan menghapus atau mengubah `learning_attempts`. Invalidasi run secara auditable:

```powershell
node infra/scripts/learning-v2-cli.mjs fixture invalidate `
  --user-id <USER_UUID> `
  --confirm-disposable <USER_UUID> `
  --run-key <RUN_KEY_YANG_SAMA> `
  --reason "manual analytics fixture finished"
```

Postcheck minimum:

1. Run berstatus `active` di `learning_fixture_runs`.
2. Tepat 39 attempt memiliki `fixture_run_id` tersebut.
3. Empat job `fixture_seeded` selesai tanpa `last_error`.
4. `learner_skill_state` berisi hasil proyeksi dan satu `learning_recommendations` aktif tersedia.
