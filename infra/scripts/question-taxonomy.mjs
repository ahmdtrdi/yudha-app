export const QUESTION_TAXONOMY_CONTENT_VERSION =
  'development-2026-09-taxonomy-v2';

export const QUESTION_TAXONOMY = Object.freeze({
  cpns: Object.freeze({
    twk: Object.freeze([
      'pancasila_dan_ideologi',
      'konstitusi_dan_negara',
      'sejarah_dan_kebangsaan',
      'bhinneka_tunggal_ika',
    ]),
    tiu: Object.freeze(['verbal', 'numerik', 'logis', 'figural']),
    tkp: Object.freeze([
      'pelayanan_dan_integritas',
      'kerja_sama_dan_komunikasi',
      'adaptasi_dan_pengembangan_diri',
      'pengambilan_keputusan_dan_kinerja',
    ]),
  }),
  bumn: Object.freeze({
    tkd: Object.freeze(['verbal', 'numerik', 'logis', 'figural']),
    akhlak: Object.freeze(['amanah', 'kompeten', 'harmonis', 'loyal']),
    wawasan_kebangsaan: Object.freeze([
      'pancasila',
      'uud_1945',
      'nkri',
      'bhinneka_tunggal_ika',
    ]),
  }),
});

const CATEGORY_LABELS = Object.freeze({
  twk: 'TWK',
  tiu: 'TIU',
  tkp: 'TKP',
  tkd: 'TKD',
  akhlak: 'AKHLAK',
  wawasan_kebangsaan: 'Wawasan Kebangsaan',
});

const SUBCATEGORY_LABELS = Object.freeze({
  pancasila_dan_ideologi: 'Pancasila dan Ideologi',
  konstitusi_dan_negara: 'Konstitusi dan Negara',
  sejarah_dan_kebangsaan: 'Sejarah dan Kebangsaan',
  bhinneka_tunggal_ika: 'Bhinneka Tunggal Ika',
  verbal: 'Verbal',
  numerik: 'Numerik',
  logis: 'Logis',
  figural: 'Figural',
  pelayanan_dan_integritas: 'Pelayanan dan Integritas',
  kerja_sama_dan_komunikasi: 'Kerja Sama dan Komunikasi',
  adaptasi_dan_pengembangan_diri: 'Adaptasi dan Pengembangan Diri',
  pengambilan_keputusan_dan_kinerja: 'Pengambilan Keputusan dan Kinerja',
  amanah: 'Amanah',
  kompeten: 'Kompeten',
  harmonis: 'Harmonis',
  loyal: 'Loyal',
  pancasila: 'Pancasila',
  uud_1945: 'UUD 1945',
  nkri: 'NKRI',
});

const SUBCATEGORY_ALIASES = new Map([
  ['kemampuan_verbal', 'verbal'],
  ['kemampuan_numerik', 'numerik'],
  ['kemampuan_logis', 'logis'],
  ['kemampuan_logika', 'logis'],
  ['logika', 'logis'],
  ['kemampuan_figural', 'figural'],
  ['pancasila_ideologi', 'pancasila_dan_ideologi'],
  ['konstitusi_negara', 'konstitusi_dan_negara'],
  ['sejarah_kebangsaan', 'sejarah_dan_kebangsaan'],
  ['pelayanan_integritas', 'pelayanan_dan_integritas'],
  ['kerja_sama_komunikasi', 'kerja_sama_dan_komunikasi'],
  ['adaptasi_pengembangan_diri', 'adaptasi_dan_pengembangan_diri'],
  ['pengambilan_keputusan_kinerja', 'pengambilan_keputusan_dan_kinerja'],
]);

const EXPLICIT_SUBCATEGORIES = new Map([
  ...assign('cpns', 'pancasila_dan_ideologi', [
    189, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 206, 217, 231,
    232, 234, 235, 247, 249,
  ]),
  ...assign('cpns', 'konstitusi_dan_negara', [
    205, 213, 214, 215, 216, 222, 223, 228, 238, 239, 245, 246, 250,
  ]),
  ...assign('cpns', 'sejarah_dan_kebangsaan', [
    191, 202, 203, 204, 207, 208, 209, 210, 211, 212, 221, 224, 227, 229,
    230, 236, 237, 240, 241, 242, 243, 244, 248,
  ]),
  ...assign('cpns', 'bhinneka_tunggal_ika', [
    190, 218, 219, 220, 225, 226, 233,
  ]),
  ...assign('bumn', 'amanah', [79, 84, 89, 93, 96]),
  ...assign('bumn', 'kompeten', [77, 80, 82, 83, 86, 90, 92, 98, 100]),
  ...assign('bumn', 'harmonis', [76, 78, 81, 85, 88, 94, 95, 97]),
  ...assign('bumn', 'loyal', [87, 91, 99]),
]);

export function normalizeQuestionTaxonomy(question) {
  const target = normalizeIdentifier(question.target);
  const category = normalizeIdentifier(question.category);
  const sourceKey = String(question.sourceKey ?? question.source_key ?? '').trim();
  const explicitSubcategory = EXPLICIT_SUBCATEGORIES.get(sourceKey);
  const rawSubcategory = explicitSubcategory ?? question.subcategory;
  const normalizedSubcategory = rawSubcategory == null
    ? null
    : normalizeIdentifier(rawSubcategory);
  const subcategory = SUBCATEGORY_ALIASES.get(normalizedSubcategory)
    ?? normalizedSubcategory;
  const allowed = QUESTION_TAXONOMY[target]?.[category];

  if (!allowed) {
    throw new Error(`Unknown question taxonomy path ${target}/${category} for ${sourceKey}.`);
  }
  if (!subcategory || !allowed.includes(subcategory)) {
    throw new Error(
      `Invalid question subcategory ${subcategory ?? '(empty)'} for ${target}/${category} (${sourceKey}).`,
    );
  }

  return {
    ...question,
    target,
    category,
    subcategory,
    primarySkillId: `${target}.${category}.${subcategory}`,
  };
}

export function questionTaxonomyPath(question) {
  const normalized = normalizeQuestionTaxonomy(question);
  return {
    target: normalized.target,
    category: normalized.category,
    subcategory: normalized.subcategory,
    primarySkillId: normalized.primarySkillId,
  };
}

export function buildQuestionTaxonomyContract() {
  return {
    schemaVersion: 1,
    contentVersion: QUESTION_TAXONOMY_CONTENT_VERSION,
    approvalStatus: 'development',
    smeApproved: false,
    approverReference: null,
    effectiveAt: '2026-09-01T00:00:00.000Z',
    targets: Object.entries(QUESTION_TAXONOMY).map(([target, categories]) => ({
      id: target,
      skills: Object.entries(categories).flatMap(([category, subcategories]) =>
        subcategories.map((subcategory) => ({
          id: `${target}.${category}.${subcategory}`,
          category,
          subcategory,
          label: `${CATEGORY_LABELS[category]} ${SUBCATEGORY_LABELS[subcategory]}`,
          enabled: true,
          disabledReason: null,
          curriculumWeight: 1,
          prerequisiteSkillIds: [],
          required: true,
        })),
      ),
      categories: Object.entries(categories).map(([id, subcategories]) => ({
        id,
        enabled: true,
        subcategories: [...subcategories],
      })),
    })),
  };
}

function assign(target, subcategory, ids) {
  return ids.map((id) => [`legacy:${target}:${id}`, subcategory]);
}

function normalizeIdentifier(value) {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}
