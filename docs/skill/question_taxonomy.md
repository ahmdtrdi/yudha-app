# Skill: Question Taxonomy & Categorization (YUDHA Learning System)

> **Tujuan**: Single Source of Truth bagi AI Agent, developer, dan content creator untuk memahami, mengelompokkan, dan menormalisasi seluruh bank soal dalam platform YUDHA (CPNS & BUMN).

---

## 1. Peta Taksonomi Kanonik (Overview Diagram)

Platform YUDHA membagi seluruh bank soal ke dalam 2 target utama: **BUMN** dan **CPNS**. Setiap target memiliki kategori dan subkategori resmi:

```text
                                  YUDHA QUESTION TAXONOMY
                                             │
             ┌───────────────────────────────┴───────────────────────────────┐
             │                                                               │
         [ BUMN ]                                                        [ CPNS ]
             │                                                               │
   ┌─────────┼─────────────────────┐                       ┌─────────────────┼─────────────────┐
   │         │                     │                       │                 │                 │
 [TKD]   [AKHLAK]        [WAWASAN KEBANGSAAN]            [TWK]             [TIU]             [TKP]
   │         │                     │                       │                 │                 │
   ├─ Verbal ├─ Amanah             ├─ Pancasila            ├─ Pancasila &    ├─ Verbal         ├─ Pelayanan &
   ├─ Numerik├─ Kompeten           ├─ UUD 1945             │  Ideologi       ├─ Numerik        │  Integritas
   ├─ Logis  ├─ Harmonis           ├─ NKRI                 ├─ Konstitusi &   ├─ Logis          ├─ Kerja Sama &
   └─ Figural└─ Loyal              └─ Bhinneka Tunggal Ika │  Negara         └─ Figural        │  Komunikasi
                                                           ├─ Sejarah &                        ├─ Adaptasi &
                                                           │  Kebangsaan                       │  Pengembangan Diri
                                                           └─ Bhinneka Tunggal                 └─ Pengambilan Keputusan
                                                              Ika                                 & Kinerja
```

---

## 2. Struktur Lengkap Target, Kategori, Subkategori & Skill ID

Setiap soal di YUDHA diidentifikasi secara unik oleh `primarySkillId` dengan format:
$$\text{primarySkillId} = \texttt{<target>.<category>.<subcategory>}$$

### A. Target: BUMN (`target = 'bumn'`)

| Kategori (`category`) | Label Kategori | Subkategori (`subcategory`) | Label Subkategori | `primarySkillId` |
|---|---|---|---|---|
| `tkd` | TKD | `verbal` | Kemampuan Verbal | `bumn.tkd.verbal` |
| `tkd` | TKD | `numerik` | Kemampuan Numerik | `bumn.tkd.numerik` |
| `tkd` | TKD | `logis` | Kemampuan Logis | `bumn.tkd.logis` |
| `tkd` | TKD | `figural` | Kemampuan Figural | `bumn.tkd.figural` |
| `akhlak` | AKHLAK | `amanah` | Amanah | `bumn.akhlak.amanah` |
| `akhlak` | AKHLAK | `kompeten` | Kompeten | `bumn.akhlak.kompeten` |
| `akhlak` | AKHLAK | `harmonis` | Harmonis | `bumn.akhlak.harmonis` |
| `akhlak` | AKHLAK | `loyal` | Loyal | `bumn.akhlak.loyal` |
| `wawasan_kebangsaan` | Wawasan Kebangsaan | `pancasila` | Pancasila | `bumn.wawasan_kebangsaan.pancasila` |
| `wawasan_kebangsaan` | Wawasan Kebangsaan | `uud_1945` | UUD 1945 | `bumn.wawasan_kebangsaan.uud_1945` |
| `wawasan_kebangsaan` | Wawasan Kebangsaan | `nkri` | NKRI | `bumn.wawasan_kebangsaan.nkri` |
| `wawasan_kebangsaan` | Wawasan Kebangsaan | `bhinneka_tunggal_ika` | Bhinneka Tunggal Ika | `bumn.wawasan_kebangsaan.bhinneka_tunggal_ika` |

---

### B. Target: CPNS (`target = 'cpns'`)

| Kategori (`category`) | Label Kategori | Subkategori (`subcategory`) | Label Subkategori | `primarySkillId` |
|---|---|---|---|---|
| `twk` | TWK | `pancasila_dan_ideologi` | Pancasila & Ideologi | `cpns.twk.pancasila_dan_ideologi` |
| `twk` | TWK | `konstitusi_dan_negara` | Konstitusi & Negara | `cpns.twk.konstitusi_dan_negara` |
| `twk` | TWK | `sejarah_dan_kebangsaan` | Sejarah & Kebangsaan | `cpns.twk.sejarah_dan_kebangsaan` |
| `twk` | TWK | `bhinneka_tunggal_ika` | Bhinneka Tunggal Ika | `cpns.twk.bhinneka_tunggal_ika` |
| `tiu` | TIU | `verbal` | Kemampuan Verbal | `cpns.tiu.verbal` |
| `tiu` | TIU | `numerik` | Kemampuan Numerik | `cpns.tiu.numerik` |
| `tiu` | TIU | `logis` | Kemampuan Logis | `cpns.tiu.logis` |
| `tiu` | TIU | `figural` | Kemampuan Figural | `cpns.tiu.figural` |
| `tkp` | TKP | `pelayanan_dan_integritas` | Pelayanan & Integritas | `cpns.tkp.pelayanan_dan_integritas` |
| `tkp` | TKP | `kerja_sama_dan_komunikasi` | Kerja Sama & Komunikasi | `cpns.tkp.kerja_sama_dan_komunikasi` |
| `tkp` | TKP | `adaptasi_dan_pengembangan_diri` | Adaptasi & Pengembangan Diri | `cpns.tkp.adaptasi_dan_pengembangan_diri` |
| `tkp` | TKP | `pengambilan_keputusan_dan_kinerja` | Pengambilan Keputusan & Kinerja | `cpns.tkp.pengambilan_keputusan_dan_kinerja` |

---

## 3. Aturan Normalisasi & Aliasing (Legacy to Canonical)

Saat mengimpor atau memproses data soal lama (legacy), normalisasi slug harus dilakukan sesuai fungsi di `infra/scripts/question-taxonomy.mjs`:

```javascript
// Mapping dari alias umum / legacy ke Canonical Subcategory
const SUBCATEGORY_ALIASES = {
  'kemampuan_verbal': 'verbal',
  'kemampuan_numerik': 'numerik',
  'kemampuan_logis': 'logis',
  'kemampuan_logika': 'logis',
  'logika': 'logis',
  'kemampuan_figural': 'figural',
  'pancasila_ideologi': 'pancasila_dan_ideologi',
  'konstitusi_negara': 'konstitusi_dan_negara',
  'sejarah_kebangsaan': 'sejarah_dan_kebangsaan',
  'pelayanan_integritas': 'pelayanan_dan_integritas',
  'kerja_sama_komunikasi': 'kerja_sama_dan_komunikasi',
  'adaptasi_pengembangan_diri': 'adaptasi_dan_pengembangan_diri',
  'pengambilan_keputusan_kinerja': 'pengambilan_keputusan_dan_kinerja',
};
```

---

## 4. Struktur Database & Model Data

Di Supabase / Postgres (`public.questions`), taksonomi disimpan dalam kolom:
- `target`: `varchar` (`'cpns'` / `'bumn'`)
- `category`: `varchar` (e.g., `'twk'`, `'tiu'`, `'tkp'`, `'tkd'`, `'akhlak'`, `'wawasan_kebangsaan'`)
- `subcategory`: `varchar` (e.g., `'pancasila_dan_ideologi'`, `'verbal'`, `'amanah'`)
- `primary_skill_id`: `varchar` (e.g., `'cpns.twk.pancasila_dan_ideologi'`)

### SQL Constraint / Check (Reference)
Setiap update pada tabel `questions` harus mematuhi validasi relasi berikut:
```sql
(target = 'cpns' AND category = 'twk' AND subcategory IN ('pancasila_dan_ideologi', 'konstitusi_dan_negara', 'sejarah_dan_kebangsaan', 'bhinneka_tunggal_ika')) OR
(target = 'cpns' AND category = 'tiu' AND subcategory IN ('verbal', 'numerik', 'logis', 'figural')) OR
(target = 'cpns' AND category = 'tkp' AND subcategory IN ('pelayanan_dan_integritas', 'kerja_sama_dan_komunikasi', 'adaptasi_dan_pengembangan_diri', 'pengambilan_keputusan_dan_kinerja')) OR
(target = 'bumn' AND category = 'wawasan_kebangsaan' AND subcategory IN ('pancasila', 'uud_1945', 'nkri', 'bhinneka_tunggal_ika')) OR
(target = 'bumn' AND category = 'tkd' AND subcategory IN ('verbal', 'numerik', 'logis', 'figural')) OR
(target = 'bumn' AND category = 'akhlak' AND subcategory IN ('amanah', 'kompeten', 'harmonis', 'loyal'))
```

---

## 5. Cara Validasi Soal

Jika Anda menambahkan soal baru atau memodifikasi script generator, jalankan tes taksonomi:
```powershell
node --test infra/scripts/question-taxonomy.test.mjs
```
Dokumen dan aturan ini adalah **kanonik** dan harus selalu dijadikan referensi utama dalam pembuatan soal, Solo practice arena, AI question generation, dan pelaporan learning analytics.
