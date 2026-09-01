import { createHash } from 'node:crypto';

const REVISION_COLUMNS = [
  'id',
  'question_id',
  'revision',
  'content_hash',
].join(',');

export async function syncLearningContent(client, taxonomy, banks) {
  const taxonomyVersion = await ensureTaxonomyVersion(client, taxonomy);
  const skills = taxonomy.targets.flatMap((target) =>
    target.skills.map((skill) => ({
      taxonomy_version_id: taxonomyVersion.id,
      skill_id: skill.id,
      target: target.id,
      category: skill.category,
      subcategory: skill.subcategory,
      label: skill.label,
      enabled: skill.enabled,
      disabled_reason: skill.disabledReason,
      curriculum_weight: skill.curriculumWeight,
      prerequisite_skill_ids: skill.prerequisiteSkillIds,
      is_required: skill.required,
    })),
  );
  const skillReport = await syncSkills(client, taxonomyVersion.id, skills);
  const revisionReport = await syncQuestionRevisions(
    client,
    taxonomyVersion.id,
    banks,
  );

  return {
    taxonomyVersionId: taxonomyVersion.id,
    contentVersion: taxonomy.contentVersion,
    skills: skillReport,
    revisions: revisionReport,
  };
}

async function ensureTaxonomyVersion(client, taxonomy) {
  const existing = await client.selectAll(
    'learning_taxonomy_versions',
    'id,schema_version,content_version,approval_status,sme_approved,approver_reference,effective_at',
  );
  const match = existing.find(
    (row) => row.content_version === taxonomy.contentVersion,
  );
  const expected = {
    schema_version: taxonomy.schemaVersion,
    content_version: taxonomy.contentVersion,
    approval_status: taxonomy.approvalStatus,
    sme_approved: taxonomy.smeApproved,
    approver_reference: taxonomy.approverReference,
    effective_at: new Date(taxonomy.effectiveAt).toISOString(),
  };
  if (match) {
    assertSameSnapshot(
      'taxonomy version',
      pick(match, Object.keys(expected)),
      expected,
    );
    return match;
  }
  const [created] = await client.insertReturning(
    'learning_taxonomy_versions',
    [expected],
  );
  if (!created?.id) throw new Error('Taxonomy version insert returned no ID.');
  return created;
}

async function syncSkills(client, taxonomyVersionId, desired) {
  const existing = await client.selectAll(
    'learning_skills',
    'taxonomy_version_id,skill_id,target,category,subcategory,label,enabled,disabled_reason,curriculum_weight,prerequisite_skill_ids,is_required',
    `taxonomy_version_id=eq.${encodeURIComponent(taxonomyVersionId)}`,
  );
  const byId = new Map(existing.map((row) => [row.skill_id, row]));
  const inserts = [];
  let skipped = 0;
  for (const skill of desired) {
    const match = byId.get(skill.skill_id);
    if (!match) {
      inserts.push(skill);
      continue;
    }
    assertSameSnapshot(
      `skill ${skill.skill_id}`,
      normalizeNumbers(pick(match, Object.keys(skill))),
      normalizeNumbers(skill),
    );
    skipped += 1;
  }
  await client.insert('learning_skills', inserts);
  return { inserted: inserts.length, skipped };
}

async function syncQuestionRevisions(client, taxonomyVersionId, banks) {
  const [questions, existingRevisions, existingMappings] = await Promise.all([
    client.selectAll('questions', 'id,source_key'),
    client.selectAll('question_revisions', REVISION_COLUMNS),
    client.selectAll(
      'question_skill_mappings',
      'question_revision_id,taxonomy_version_id,skill_id,mapping_type,mapping_weight,approval_status,approver_reference,approved_at,provenance',
      `taxonomy_version_id=eq.${encodeURIComponent(taxonomyVersionId)}`,
    ),
  ]);
  const questionBySource = new Map(
    questions.map((question) => [question.source_key, question]),
  );
  const revisionsByQuestion = groupBy(
    existingRevisions,
    (revision) => revision.question_id,
  );
  const desired = [];
  let skipped = 0;

  for (const bank of banks) {
    for (const question of bank.questions) {
      const storedQuestion = questionBySource.get(question.sourceKey);
      if (!storedQuestion) {
        throw new Error(`Question ${question.sourceKey} was not synchronized.`);
      }
      const contentHash = learningRevisionHash(bank, question);
      const revisions = revisionsByQuestion.get(storedQuestion.id) ?? [];
      const existing = revisions.find(
        (revision) => revision.content_hash === contentHash,
      );
      if (existing) {
        if (Number(existing.revision) !== question.revision) {
          throw new Error(
            `Question ${question.sourceKey} declares revision ${question.revision}, but matching content is revision ${existing.revision}.`,
          );
        }
        skipped += 1;
        continue;
      }
      const expectedRevision =
        Math.max(0, ...revisions.map((revision) => Number(revision.revision))) +
        1;
      if (question.revision !== expectedRevision) {
        throw new Error(
          `Question ${question.sourceKey} must declare revision ${expectedRevision} for changed content.`,
        );
      }
      desired.push({
        row: toRevisionRow(storedQuestion.id, bank, question, contentHash),
        question,
        bank,
      });
    }
  }

  const inserted = await client.insertReturning(
    'question_revisions',
    desired.map((entry) => entry.row),
  );
  const insertedByKey = new Map(
    inserted.map((revision) => [
      `${revision.question_id}\u0000${revision.content_hash}`,
      revision,
    ]),
  );
  const allRevisions = [
    ...existingRevisions,
    ...inserted,
  ];
  const currentRevisionBySource = new Map();
  for (const bank of banks) {
    for (const question of bank.questions) {
      const storedQuestion = questionBySource.get(question.sourceKey);
      const contentHash = learningRevisionHash(bank, question);
      const revision =
        insertedByKey.get(`${storedQuestion.id}\u0000${contentHash}`) ??
        allRevisions.find(
          (candidate) =>
            candidate.question_id === storedQuestion.id &&
            candidate.content_hash === contentHash,
        );
      if (!revision) {
        throw new Error(`Revision lookup failed for ${question.sourceKey}.`);
      }
      currentRevisionBySource.set(question.sourceKey, {
        revision,
        question,
        bank,
      });
    }
  }

  const mappingKeys = new Set(
    existingMappings.map((mapping) => mappingKey(mapping)),
  );
  const mappingInserts = [];
  let mappingsSkipped = 0;
  for (const entry of currentRevisionBySource.values()) {
    const mappings = [
      { skillId: entry.question.primarySkillId, mappingType: 'primary' },
      ...entry.question.prerequisiteSkillIds.map((skillId) => ({
        skillId,
        mappingType: 'prerequisite',
      })),
    ];
    for (const mapping of mappings) {
      const row = {
        question_revision_id: entry.revision.id,
        taxonomy_version_id: taxonomyVersionId,
        skill_id: mapping.skillId,
        mapping_type: mapping.mappingType,
        mapping_weight: 1,
        approval_status: entry.question.smeApproved
          ? 'sme_approved'
          : 'development',
        approved_at: entry.question.approvedAt,
        approver_reference: entry.question.approverReference,
        provenance: 'content_sync',
      };
      const key = mappingKey(row);
      if (mappingKeys.has(key)) {
        mappingsSkipped += 1;
      } else {
        mappingKeys.add(key);
        mappingInserts.push(row);
      }
    }
  }
  await client.insert('question_skill_mappings', mappingInserts);

  return {
    inserted: inserted.length,
    skipped,
    mappingsInserted: mappingInserts.length,
    mappingsSkipped,
  };
}

export function learningRevisionHash(bank, question) {
  const snapshot = {
    sourceKey: question.sourceKey,
    contentVersion: bank.contentVersion,
    target: question.target,
    category: question.category,
    subcategory: question.subcategory,
    prompt: question.prompt,
    options: question.options,
    correctOptionIndex: question.correctOptionIndex,
    explanation: question.explanation,
    hint: question.hint,
    difficulty: question.difficulty,
    questionType: question.questionType,
    expectedTimeMs: question.expectedTimeMs,
    standardTimeLimitMs: question.standardTimeLimitMs,
    curriculumWeight: question.curriculumWeight,
    assessmentEligible: question.assessmentEligible,
    qualityState: question.qualityState,
    active: question.active,
    smeApproved: question.smeApproved,
    approvedAt: question.approvedAt,
    approverReference: question.approverReference,
  };
  return createHash('sha256')
    .update(stableJson(snapshot))
    .digest('hex');
}

function toRevisionRow(questionId, bank, question, contentHash) {
  return {
    question_id: questionId,
    revision: question.revision,
    source_key: question.sourceKey,
    content_version: bank.contentVersion,
    content_hash: contentHash,
    target: question.target,
    category: question.category,
    subcategory: question.subcategory,
    prompt: question.prompt,
    options: question.options,
    correct_option_index: question.correctOptionIndex,
    explanation: question.explanation,
    hint: question.hint,
    difficulty: question.difficulty,
    question_type: question.questionType,
    expected_time_ms: question.expectedTimeMs,
    standard_time_limit_ms: question.standardTimeLimitMs,
    curriculum_weight: question.curriculumWeight,
    assessment_eligible: question.assessmentEligible,
    quality_state: question.qualityState,
    is_active: question.active,
    sme_approved: question.smeApproved,
    approved_at: question.approvedAt,
    approver_reference: question.approverReference,
  };
}

function mappingKey(mapping) {
  return [
    mapping.question_revision_id,
    mapping.taxonomy_version_id,
    mapping.skill_id,
    mapping.mapping_type,
  ].join('\u0000');
}

function groupBy(values, key) {
  const groups = new Map();
  for (const value of values) {
    const id = key(value);
    const group = groups.get(id) ?? [];
    group.push(value);
    groups.set(id, group);
  }
  return groups;
}

function pick(value, keys) {
  return Object.fromEntries(keys.map((key) => [key, value[key]]));
}

function normalizeNumbers(value) {
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [
      key,
      typeof item === 'string' && /^-?\d+(\.\d+)?$/.test(item)
        ? Number(item)
        : item,
    ]),
  );
}

function assertSameSnapshot(label, actual, expected) {
  const actualJson = stableJson(actual);
  const expectedJson = stableJson(expected);
  if (actualJson !== expectedJson) {
    throw new Error(
      `Immutable ${label} differs from ${expectedJson}; found ${actualJson}. Create a new content version instead of rewriting it.`,
    );
  }
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}
