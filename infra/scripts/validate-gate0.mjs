import { readFile, readdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
export const repositoryRoot = resolve(scriptDirectory, '..', '..');

const requiredRestPaths = [
  '/auth/register', '/auth/login', '/lobby/summary', '/profile', '/profile/loadout',
  '/practice/dashboard', '/practice/sessions', '/practice/sessions/{id}',
  '/practice/sessions/{id}/answers', '/practice/sessions/{id}/finish', '/practice/history',
  '/analytics', '/leaderboard', '/leaderboard/me', '/store/items', '/store/beta-credits',
  '/store/purchases', '/hired-pass', '/hired-pass/beta-activate',
  '/hired-pass/rewards/{rewardId}/claim', '/interview/sessions', '/interview/sessions/{id}',
  '/interview/sessions/{id}/turns', '/interview/sessions/{id}/turns/stream',
  '/interview/sessions/{id}/complete', '/interview/sessions/{id}/speech/transcriptions',
  '/interview/sessions/{id}/speech/questions/{turnId}/audio',
];

export async function validateGate0(root = repositoryRoot) {
  const contracts = resolve(root, 'contracts');
  const taxonomy = await loadJson(resolve(contracts, 'content', 'taxonomy.v1.json'));
  const catalog = await loadJson(resolve(contracts, 'content', 'store-catalog.v1.json'));
  const seasonDirectory = resolve(contracts, 'content', 'seasons');
  const seasonFiles = (await readdir(seasonDirectory)).filter((file) => file.endsWith('.json'));
  const seasons = await Promise.all(seasonFiles.map((file) => loadJson(resolve(seasonDirectory, file))));
  const banks = await Promise.all(['cpns.v1.json', 'bumn.v1.json'].map((file) => loadJson(resolve(contracts, 'content', 'questions', file))));
  const openapi = await loadJson(resolve(contracts, 'openapi', 'yudha-api.v1.json'));

  validateTaxonomy(taxonomy);
  validateStoreCatalog(catalog);
  validateSeasons(seasons, catalog);
  for (const bank of banks) validateQuestionBank(bank, taxonomy);
  validateOpenApi(openapi);
  await validateSchemasAndFixtures(contracts);

  return {
    questions: Object.fromEntries(banks.map((bank) => [bank.target, bank.questions.length])),
    activeSeason: seasons.find((season) => season.releaseActive)?.season.id,
    smeApproved: banks.every((bank) => bank.smeApproved === true),
  };
}

export function validateTaxonomy(taxonomy) {
  assert(taxonomy?.schemaVersion === 1, 'Taxonomy schemaVersion must be 1.');
  assert(['development', 'sme_approved'].includes(taxonomy.approvalStatus), 'Invalid taxonomy approvalStatus.');
  assert(taxonomy.smeApproved === (taxonomy.approvalStatus === 'sme_approved'), 'Taxonomy SME approval fields are inconsistent.');
  assert(Number.isFinite(Date.parse(taxonomy.effectiveAt)), 'Taxonomy effectiveAt must be an ISO date-time.');
  assert(
    taxonomy.smeApproved ? nonEmpty(taxonomy.approverReference) : taxonomy.approverReference === null,
    'Taxonomy approver reference is inconsistent.',
  );
  unique(taxonomy.targets, (target) => target.id, 'taxonomy target');
  unique(taxonomy.targets.flatMap((target) => target.skills ?? []), (skill) => skill.id, 'taxonomy skill');
  const ids = new Set(taxonomy.targets.map((target) => target.id));
  assert(ids.has('cpns') && ids.has('bumn'), 'Taxonomy must contain CPNS and BUMN.');
  for (const target of taxonomy.targets) {
    unique(target.categories, (category) => category.id, `${target.id} category`);
    for (const category of target.categories) {
      assert(typeof category.enabled === 'boolean', `Category ${target.id}/${category.id} needs enabled.`);
      if (!category.enabled) assert(nonEmpty(category.disabledReason), `Disabled category ${category.id} needs a reason.`);
      unique(category.subcategories ?? [], (value) => value, `${target.id}/${category.id} subcategory`);
    }
    const categories = new Map(target.categories.map((category) => [category.id, category]));
    for (const skill of target.skills ?? []) {
      assert(skill.id.startsWith(`${target.id}.`), `Skill ${skill.id} must use the ${target.id} namespace.`);
      assert(nonEmpty(skill.label), `Skill ${skill.id} needs a label.`);
      assert(categories.has(skill.category), `Skill ${skill.id} has an unknown category.`);
      const category = categories.get(skill.category);
      if (skill.subcategory !== null) {
        assert(category.subcategories.includes(skill.subcategory), `Skill ${skill.id} has an invalid subcategory.`);
      }
      assert(typeof skill.enabled === 'boolean', `Skill ${skill.id} needs enabled.`);
      if (!skill.enabled) assert(nonEmpty(skill.disabledReason), `Disabled skill ${skill.id} needs a reason.`);
      assert(Number.isFinite(skill.curriculumWeight) && skill.curriculumWeight > 0, `Skill ${skill.id} has an invalid weight.`);
      assert(Array.isArray(skill.prerequisiteSkillIds), `Skill ${skill.id} needs prerequisiteSkillIds.`);
      assert(typeof skill.required === 'boolean', `Skill ${skill.id} needs required.`);
    }
    const targetSkillIds = new Set((target.skills ?? []).map((skill) => skill.id));
    for (const skill of target.skills ?? []) {
      for (const prerequisite of skill.prerequisiteSkillIds) {
        assert(targetSkillIds.has(prerequisite), `Skill ${skill.id} has unknown prerequisite ${prerequisite}.`);
      }
    }
  }
}

export function validateQuestionBank(bank, taxonomy) {
  assert(bank?.schemaVersion === 1, 'Question bank schemaVersion must be 1.');
  assert(['cpns', 'bumn'].includes(bank.target), 'Question bank target is invalid.');
  assert(bank.approvalStatus === 'development' || bank.approvalStatus === 'sme_approved', 'Question approvalStatus is invalid.');
  assert(bank.smeApproved === (bank.approvalStatus === 'sme_approved'), `${bank.target} SME approval fields are inconsistent.`);
  assert(
    bank.smeApproved ? nonEmpty(bank.approverReference) : bank.approverReference === null,
    `${bank.target} approver reference is inconsistent.`,
  );
  assert(Array.isArray(bank.questions) && bank.questions.length >= 100, `${bank.target} needs at least 100 questions.`);
  unique(bank.questions, (question) => question.sourceKey, `${bank.target} sourceKey`);

  const target = taxonomy.targets.find((candidate) => candidate.id === bank.target);
  const enabled = new Map(target.categories.filter((category) => category.enabled).map((category) => [category.id, category]));
  const skills = new Map(target.skills.filter((skill) => skill.enabled).map((skill) => [skill.id, skill]));
  const counts = new Map();
  for (const question of bank.questions) {
    assert(question.target === bank.target, `Target mismatch for ${question.sourceKey}.`);
    assert(Number.isInteger(question.revision) && question.revision > 0, `Invalid revision for ${question.sourceKey}.`);
    assert(enabled.has(question.category), `Unknown or disabled category for ${question.sourceKey}.`);
    const category = enabled.get(question.category);
    if (question.subcategory !== null) {
      assert(category.subcategories.includes(question.subcategory), `Invalid subcategory for ${question.sourceKey}.`);
    }
    const primarySkill = skills.get(question.primarySkillId);
    assert(primarySkill, `Unknown or disabled primary skill for ${question.sourceKey}.`);
    assert(
      primarySkill.category === question.category && primarySkill.subcategory === question.subcategory,
      `Primary skill path mismatch for ${question.sourceKey}.`,
    );
    assert(Array.isArray(question.prerequisiteSkillIds), `Missing prerequisites for ${question.sourceKey}.`);
    for (const prerequisite of question.prerequisiteSkillIds) {
      assert(skills.has(prerequisite), `Unknown prerequisite skill for ${question.sourceKey}.`);
    }
    assert(nonEmpty(question.prompt), `Empty prompt for ${question.sourceKey}.`);
    assert(Array.isArray(question.options) && question.options.length >= 2 && question.options.length <= 6, `Invalid options for ${question.sourceKey}.`);
    assert(question.options.every(nonEmpty), `Empty option for ${question.sourceKey}.`);
    assert(Number.isInteger(question.correctOptionIndex) && question.correctOptionIndex >= 0 && question.correctOptionIndex < question.options.length, `Invalid correct index for ${question.sourceKey}.`);
    assert(nonEmpty(question.explanation), `Empty explanation for ${question.sourceKey}.`);
    assert(['easy', 'medium', 'hard'].includes(question.difficulty), `Invalid difficulty for ${question.sourceKey}.`);
    assert(question.questionType === 'multiple_choice', `Invalid question type for ${question.sourceKey}.`);
    assert(
      question.expectedTimeMs === null || (Number.isInteger(question.expectedTimeMs) && question.expectedTimeMs > 0),
      `Invalid expected time for ${question.sourceKey}.`,
    );
    assert(Number.isInteger(question.standardTimeLimitMs) && question.standardTimeLimitMs > 0, `Invalid standard time for ${question.sourceKey}.`);
    assert(Number.isFinite(question.curriculumWeight) && question.curriculumWeight > 0, `Invalid curriculum weight for ${question.sourceKey}.`);
    assert(typeof question.assessmentEligible === 'boolean', `Invalid Assessment eligibility for ${question.sourceKey}.`);
    assert(['development', 'approved', 'under_review', 'invalidated', 'disabled'].includes(question.qualityState), `Invalid quality state for ${question.sourceKey}.`);
    assert(question.smeApproved === (question.qualityState === 'approved'), `Question approval fields are inconsistent for ${question.sourceKey}.`);
    assert(
      question.smeApproved
        ? nonEmpty(question.approverReference) && Number.isFinite(Date.parse(question.approvedAt))
        : question.approverReference === null && question.approvedAt === null,
      `Question approver metadata is inconsistent for ${question.sourceKey}.`,
    );
    assert(Number.isInteger(question.weight) && question.weight >= 1 && question.weight <= 4, `Invalid weight for ${question.sourceKey}.`);
    assert(['damage', 'heal'].includes(question.effect), `Invalid effect for ${question.sourceKey}.`);
    assert(Number.isInteger(question.damageValue) && question.damageValue >= 0, `Invalid damage value for ${question.sourceKey}.`);
    assert(Number.isInteger(question.healValue) && question.healValue >= 0, `Invalid heal value for ${question.sourceKey}.`);
    assert(Number.isInteger(question.timeLimitSeconds) && question.timeLimitSeconds > 0, `Invalid timer for ${question.sourceKey}.`);
    if (question.active) counts.set(question.category, (counts.get(question.category) ?? 0) + 1);
  }
  for (const category of enabled.keys()) {
    assert((counts.get(category) ?? 0) >= 20, `${bank.target}/${category} needs at least 20 active questions.`);
  }
}

export function validateStoreCatalog(catalog) {
  assert(catalog?.schemaVersion === 1, 'Store schemaVersion must be 1.');
  assert(typeof catalog.betaMode === 'boolean', 'Store betaMode must be boolean.');
  unique(catalog.items, (item) => item.id, 'store item');
  unique([...catalog.betaPackages, ...catalog.disabledPaidPackages], (item) => item.id, 'coin package');
  for (const item of catalog.items) {
    assert(
      ['character', 'tower', 'arena'].includes(item.type),
      `Invalid item type ${item.id}.`,
    );
    assert(['common', 'rare', 'epic', 'legendary'].includes(item.rarity), `Invalid rarity ${item.id}.`);
    assert(Number.isInteger(item.coinPrice) && item.coinPrice >= 0, `Invalid price ${item.id}.`);
  }
  const beta = catalog.betaPackages.find((item) => item.id === 'beta-100');
  for (const pack of [...catalog.betaPackages, ...catalog.disabledPaidPackages]) {
    assert(Number.isInteger(pack.coins) && pack.coins >= 0, `Invalid coin package ${pack.id}.`);
  }
  assert(beta?.coins === 100 && beta.priceLabel === 'GRATIS' && beta.repeatable === true, 'beta-100 package is invalid.');
}

export function validateSeasons(seasons, catalog) {
  assert(seasons.length > 0, 'At least one season manifest is required.');
  assert(seasons.filter((season) => season.releaseActive).length === 1, 'Exactly one release season must be active.');
  unique(seasons, (season) => season.season.id, 'season');
  const sorted = [...seasons].sort((a, b) => Date.parse(a.season.startsAt) - Date.parse(b.season.startsAt));
  for (let index = 0; index < sorted.length; index += 1) {
    const manifest = sorted[index];
    const start = Date.parse(manifest.season.startsAt);
    const end = Date.parse(manifest.season.endsAt);
    assert(Number.isFinite(start) && end > start, `Invalid season window ${manifest.season.id}.`);
    assert(/\+07:00$/.test(manifest.season.startsAt) && /\+07:00$/.test(manifest.season.endsAt), `Season ${manifest.season.id} must use +07:00.`);
    assert(/-01T00:00:00\+07:00$/.test(manifest.season.startsAt) && /-01T00:00:00\+07:00$/.test(manifest.season.endsAt), `Season ${manifest.season.id} must use WIB month boundaries.`);
    if (index > 0) assert(Date.parse(sorted[index - 1].season.endsAt) <= start, `Season ${manifest.season.id} overlaps.`);
    validateSeason(manifest, catalog);
  }
}

export function validateSeason(manifest, catalog) {
  const sources = new Set(['practice_completed', 'public_pvp_completed', 'ranked_completed', 'ranked_won', 'interview_completed', 'streak_day_created']);
  unique(manifest.missions, (mission) => mission.id, 'mission');
  unique(manifest.rewards, (reward) => reward.id, 'reward');
  for (const mission of manifest.missions) {
    assert(sources.has(mission.source), `Invalid mission source ${mission.id}.`);
    assert(['daily', 'weekly', 'season'].includes(mission.cadence), `Invalid cadence ${mission.id}.`);
    assert(Number.isInteger(mission.targetCount) && mission.targetCount > 0, `Invalid target ${mission.id}.`);
    assert(Number.isInteger(mission.passPoints) && mission.passPoints > 0, `Invalid points ${mission.id}.`);
  }
  const itemMap = new Map(catalog.items.map((item) => [item.id, item]));
  const milestones = new Map();
  for (const reward of manifest.rewards) {
    assert(['free', 'premium'].includes(reward.track), `Invalid reward track ${reward.id}.`);
    assert(Number.isInteger(reward.pointsRequired) && reward.pointsRequired >= 0, `Invalid reward threshold ${reward.id}.`);
    assert(Number.isInteger(reward.coins) && reward.coins >= 0, `Invalid reward coins ${reward.id}.`);
    if (reward.itemId) assert(itemMap.has(reward.itemId), `Unknown reward item ${reward.itemId}.`);
    const pair = milestones.get(reward.pointsRequired) ?? {};
    pair[reward.track] = reward;
    milestones.set(reward.pointsRequired, pair);
  }
  for (const [points, pair] of milestones) {
    assert(pair.free && pair.premium, `Milestone ${points} needs free and premium rewards.`);
    const exclusive = pair.premium.itemId && itemMap.get(pair.premium.itemId)?.passExclusive;
    const superiorCoins = pair.premium.coins > pair.free.coins;
    const exclusiveWithCoins = exclusive && pair.premium.coins >= pair.free.coins;
    assert(superiorCoins || exclusiveWithCoins, `Premium reward at ${points} is not superior.`);
  }
  assert([...itemMap.values()].some((item) => item.passExclusive), 'Catalog needs a Pass-exclusive item.');
  const days = Math.round((Date.parse(manifest.season.endsAt) - Date.parse(manifest.season.startsAt)) / 86400000);
  const weeks = Math.ceil(days / 7);
  const obtainable = manifest.missions.reduce((total, mission) => total + mission.passPoints * (mission.cadence === 'daily' ? days : mission.cadence === 'weekly' ? weeks : 1), 0);
  const maximumMilestone = Math.max(...manifest.rewards.map((reward) => reward.pointsRequired));
  assert(obtainable >= maximumMilestone, `Season maximum ${obtainable} cannot reach ${maximumMilestone}.`);
}

function validateOpenApi(openapi) {
  assert(openapi.openapi === '3.1.0', 'OpenAPI version must be 3.1.0.');
  assert(openapi.info?.version === '1.0.0', 'OpenAPI contract version must be 1.0.0.');
  for (const path of requiredRestPaths) assert(openapi.paths?.[path], `OpenAPI path missing: ${path}.`);
  assert(openapi.components?.schemas?.ErrorEnvelope, 'OpenAPI ErrorEnvelope schema is missing.');
  assert(openapi.components?.schemas?.Recommendation, 'OpenAPI Recommendation schema is missing.');
}

async function validateSchemasAndFixtures(contracts) {
  const schemaDirectory = resolve(contracts, 'schemas');
  const schemas = (await readdir(schemaDirectory)).filter((file) => file.endsWith('.json'));
  assert(schemas.length >= 4, 'Gate 0 requires four JSON schemas.');
  for (const file of schemas) {
    const schema = await loadJson(resolve(schemaDirectory, file));
    assert(schema.$schema === 'https://json-schema.org/draft/2020-12/schema', `${file} must use JSON Schema 2020-12.`);
  }
  for (const file of ['errors/idempotency-key-reused.json', 'errors/validation-failed.json']) {
    const fixture = await loadJson(resolve(contracts, 'fixtures', file));
    assert(nonEmpty(fixture.error?.code) && nonEmpty(fixture.error?.message) && nonEmpty(fixture.error?.requestId), `Invalid error fixture ${file}.`);
  }
  const replay = await loadJson(resolve(contracts, 'fixtures', 'idempotency', 'same-request-replay.json'));
  assert(replay.expected?.sameResponse === true && replay.expected?.duplicateSideEffects === false, 'Invalid replay fixture.');
}

async function loadJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

function unique(values, key, label) {
  assert(Array.isArray(values), `${label} collection must be an array.`);
  const ids = values.map(key);
  assert(ids.every(nonEmpty), `${label} IDs must be non-empty.`);
  assert(new Set(ids).size === ids.length, `Duplicate ${label} ID.`);
}

function nonEmpty(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = await validateGate0();
    process.stdout.write(`${JSON.stringify(result)}\n`);
    if (!result.smeApproved) process.stderr.write('WARNING: question content remains development-only and requires SME approval.\n');
  } catch (error) {
    process.stderr.write(`Gate 0 validation failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
