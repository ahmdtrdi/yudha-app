import { createHash } from 'node:crypto';
import { stableJson } from './sync-content.mjs';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CLASSIFICATION_VERSION = 'evidence-v1';

export async function seedLearningFixture(client, options) {
  const userId = confirmedUser(options);
  const runKey = required(options.runKey, 'runKey');
  const scenario = options.scenario ?? 'mixed';
  if (scenario !== 'mixed') throw new Error('Only the mixed scenario is supported.');
  const [profile] = await client.selectAll(
    'profiles',
    'id,target',
    `id=eq.${encodeURIComponent(userId)}`,
  );
  if (!profile) throw new Error('Disposable fixture profile was not found.');
  if (!['cpns', 'bumn'].includes(profile.target)) {
    throw new Error('Fixture profile target must be cpns or bumn.');
  }
  const existingRuns = await client.selectAll(
    'learning_fixture_runs',
    '*',
    `user_id=eq.${encodeURIComponent(userId)}&run_key=eq.${encodeURIComponent(runKey)}`,
  );
  if (existingRuns.length > 0) {
    const run = existingRuns[0];
    if (run.target !== profile.target || run.scenario !== scenario) {
      throw new Error('Fixture run key was already used for different input.');
    }
    if (run.status !== 'active') {
      throw new Error('An invalidated fixture run cannot be seeded again.');
    }
    const attempts = await client.selectAll(
      'learning_attempts',
      'id',
      `fixture_run_id=eq.${encodeURIComponent(run.id)}`,
    );
    if (attempts.length !== 39) {
      throw new Error(
        `Fixture run is partial (${attempts.length}/39 attempts). Invalidate it and use a new run key.`,
      );
    }
    return {
      runId: run.id,
      runKey,
      userId,
      target: profile.target,
      scenario,
      attempts: attempts.length,
      replayed: true,
    };
  }

  const taxonomyVersions = await client.selectAll(
    'learning_taxonomy_versions',
    'id,effective_at,created_at',
  );
  const taxonomy = taxonomyVersions.sort(compareNewest)[0];
  if (!taxonomy) throw new Error('Learning taxonomy has not been synchronized.');
  const skills = await client.selectAll(
    'learning_skills',
    '*',
    `taxonomy_version_id=eq.${encodeURIComponent(taxonomy.id)}&target=eq.${profile.target}&enabled=eq.true`,
  );
  if (skills.length < 4) {
    throw new Error('Mixed fixture requires four enabled target skills.');
  }
  const mappings = await client.selectAll(
    'question_skill_mappings',
    'question_revision_id,skill_id',
    `taxonomy_version_id=eq.${encodeURIComponent(taxonomy.id)}&mapping_type=eq.primary`,
  );
  const revisions = await client.selectAll(
    'question_revisions',
    'id,question_id,content_version,category,subcategory,difficulty,correct_option_index,expected_time_ms,standard_time_limit_ms,curriculum_weight,quality_state,is_active',
    'is_active=eq.true',
  );
  const revisionById = new Map(revisions.map((row) => [row.id, row]));
  const inventoryBySkill = new Map();
  for (const mapping of mappings) {
    const revision = revisionById.get(mapping.question_revision_id);
    if (!revision || ['invalidated', 'disabled'].includes(revision.quality_state)) {
      continue;
    }
    const values = inventoryBySkill.get(mapping.skill_id) ?? [];
    values.push(revision);
    inventoryBySkill.set(mapping.skill_id, values);
  }
  const selectedSkills = [...skills]
    .sort((left, right) => left.skill_id.localeCompare(right.skill_id))
    .slice(0, 4);
  const requiredCounts = [9, 16, 10, 4];
  for (let index = 0; index < selectedSkills.length; index += 1) {
    const inventory = inventoryBySkill.get(selectedSkills[index].skill_id) ?? [];
    if (inventory.length < requiredCounts[index]) {
      throw new Error(
        `Skill ${selectedSkills[index].skill_id} needs ${requiredCounts[index]} active revisions for the mixed fixture; found ${inventory.length}.`,
      );
    }
  }

  const baseTime = options.baseTime
    ? new Date(options.baseTime)
    : new Date();
  if (Number.isNaN(baseTime.getTime())) throw new Error('baseTime is invalid.');
  const [run] = await client.insertReturning('learning_fixture_runs', [
    {
      run_key: runKey,
      user_id: userId,
      target: profile.target,
      scenario,
      status: 'active',
      metadata: {
        synthetic: true,
        disposableUserConfirmed: true,
        baseTime: baseTime.toISOString(),
        taxonomyVersionId: taxonomy.id,
        calculationVersion: 'learning-v1',
      },
    },
  ]);
  const attempts = [];
  const classifications = [];
  const exposures = new Map();
  let ordinal = 0;
  for (let skillIndex = 0; skillIndex < selectedSkills.length; skillIndex += 1) {
    const skill = selectedSkills[skillIndex];
    const inventory = inventoryBySkill.get(skill.skill_id);
    const count = requiredCounts[skillIndex];
    for (let item = 0; item < count; item += 1) {
      const revision = inventory[item];
      const exposure = exposures.get(revision.question_id);
      const exposureCount = exposure?.count ?? 0;
      const hinted = skillIndex === 3 && item % 3 === 0;
      const isCorrect =
        skillIndex === 0
          ? item < 5
          : skillIndex === 1
            ? item < 15
            : skillIndex === 2
              ? item < 8
              : item % 2 === 0;
      const sourceEventAt = new Date(
        baseTime.getTime() - ordinal * 12 * 60 * 60 * 1000,
      ).toISOString();
      const sourceKey = `fixture:${runKey}:${String(ordinal + 1).padStart(3, '0')}`;
      const snapshot = {
        runId: run.id,
        sourceKey,
        userId,
        target: profile.target,
        taxonomyVersionId: taxonomy.id,
        skillId: skill.skill_id,
        questionRevisionId: revision.id,
        isCorrect,
        hinted,
        seenBefore: exposureCount > 0,
        sourceEventAt,
      };
      attempts.push({
        source: 'solo',
        source_attempt_key: sourceKey,
        source_payload_hash: sha256(snapshot),
        data_fidelity: 'synthetic_fixture',
        fixture_run_id: run.id,
        user_id: userId,
        target: profile.target,
        source_session_key: `fixture-session:${runKey}:${ordinal + 1}`,
        learning_objective: 'collect_evidence',
        requested_mechanic_mode: 'standard',
        effective_mechanic_mode: 'standard',
        question_selection_type: 'recommended',
        session_completion_state: 'compatibility_completed',
        question_id: revision.question_id,
        question_revision_id: revision.id,
        taxonomy_version_id: taxonomy.id,
        skill_id: skill.skill_id,
        content_version: revision.content_version,
        category: revision.category,
        subcategory: revision.subcategory,
        difficulty: revision.difficulty,
        expected_time_ms: revision.expected_time_ms,
        standard_time_limit_ms: revision.standard_time_limit_ms,
        curriculum_weight: Number(revision.curriculum_weight),
        question_quality_state: revision.quality_state,
        selected_option_index: isCorrect
          ? revision.correct_option_index
          : (revision.correct_option_index + 1) % 4,
        is_correct: isCorrect,
        hint_requested: hinted,
        timed_out: false,
        first_attempt: true,
        seen_before: exposureCount > 0,
        exposure_count_before: exposureCount,
        explanation_viewed: true,
        opened_at: new Date(Date.parse(sourceEventAt) - 20_000).toISOString(),
        answered_at: sourceEventAt,
        client_active_response_time_ms: 20_000,
        server_elapsed_time_ms: 20_000,
        background_duration_ms: 0,
        effective_response_time_ms: 20_000,
        timing_invalidity_reason: null,
        source_event_at: sourceEventAt,
      });
      classifications.push({
        sourceKey,
        hinted,
        unseen: exposureCount === 0,
      });
      exposures.set(revision.question_id, {
        count: exposureCount + 1,
        firstPresentedAt: exposure?.firstPresentedAt ?? sourceEventAt,
        lastPresentedAt: sourceEventAt,
      });
      ordinal += 1;
    }
  }
  const inserted = await client.insertReturning('learning_attempts', attempts);
  const insertedByKey = new Map(
    inserted.map((row) => [row.source_attempt_key, row]),
  );
  await client.insert(
    'learning_attempt_classifications',
    classifications.map((classification) => {
      const attempt = insertedByKey.get(classification.sourceKey);
      const exclusionReasons = [];
      if (classification.hinted) exclusionReasons.push('hint_assisted');
      if (!classification.unseen) exclusionReasons.push('previously_exposed');
      return {
        attempt_id: attempt.id,
        classification_version: CLASSIFICATION_VERSION,
        classifier_input_hash: sha256({
          attemptId: attempt.id,
          classificationVersion: CLASSIFICATION_VERSION,
          hinted: classification.hinted,
          unseen: classification.unseen,
        }),
        valid_for_activity_accuracy: true,
        valid_for_independent_accuracy: !classification.hinted,
        valid_for_unseen_independent_accuracy:
          !classification.hinted && classification.unseen,
        valid_for_assisted_accuracy: classification.hinted,
        valid_for_pace_analytics: !classification.hinted,
        valid_for_fluency_baseline:
          !classification.hinted && classification.unseen,
        valid_for_retention: false,
        exclusion_reasons: exclusionReasons,
      };
    }),
  );
  await client.upsert(
    'learner_question_exposures',
    [...exposures.entries()].map(([questionId, exposure]) => ({
      user_id: userId,
      question_id: questionId,
      exposure_count: exposure.count,
      first_presented_at: exposure.firstPresentedAt,
      last_presented_at: exposure.lastPresentedAt,
      last_source: 'solo',
      updated_at: baseTime.toISOString(),
    })),
    'user_id,question_id',
  );
  for (const skill of selectedSkills) {
    await queueTargetedRebuild(client, {
      userId,
      target: profile.target,
      taxonomyVersionId: taxonomy.id,
      skillId: skill.skill_id,
      reason: 'fixture_seeded',
    });
  }
  return {
    runId: run.id,
    runKey,
    userId,
    target: profile.target,
    scenario,
    attempts: inserted.length,
    skills: selectedSkills.map((skill) => skill.skill_id),
    replayed: false,
  };
}

export async function invalidateLearningFixture(client, options) {
  const userId = confirmedUser(options);
  const runKey = required(options.runKey, 'runKey');
  const reason = required(options.reason, 'reason');
  const [run] = await client.selectAll(
    'learning_fixture_runs',
    '*',
    `user_id=eq.${encodeURIComponent(userId)}&run_key=eq.${encodeURIComponent(runKey)}`,
  );
  if (!run) throw new Error('Fixture run was not found.');
  if (run.status === 'invalidated') {
    return { runId: run.id, runKey, invalidated: 0, replayed: true };
  }
  const attempts = await client.selectAll(
    'learning_attempts',
    'id,target,taxonomy_version_id,skill_id',
    `fixture_run_id=eq.${encodeURIComponent(run.id)}`,
  );
  const existing = await client.selectAll(
    'learning_attempt_invalidations',
    'attempt_id',
  );
  const invalidated = new Set(existing.map((row) => row.attempt_id));
  const inserts = attempts
    .filter((attempt) => !invalidated.has(attempt.id))
    .map((attempt) => ({
      attempt_id: attempt.id,
      reason,
      metadata: { fixtureRunId: run.id, runKey },
    }));
  await client.insert('learning_attempt_invalidations', inserts);
  await client.updateWhere(
    'learning_fixture_runs',
    `id=eq.${encodeURIComponent(run.id)}`,
    {
      status: 'invalidated',
      invalidated_at: new Date().toISOString(),
      invalidation_reason: reason,
    },
  );
  const skills = new Map(
    attempts
      .filter((attempt) => attempt.taxonomy_version_id && attempt.skill_id)
      .map((attempt) => [
        `${attempt.taxonomy_version_id}:${attempt.skill_id}`,
        attempt,
      ]),
  );
  for (const attempt of skills.values()) {
    await queueTargetedRebuild(client, {
      userId,
      target: attempt.target,
      taxonomyVersionId: attempt.taxonomy_version_id,
      skillId: attempt.skill_id,
      reason: 'fixture_invalidated',
    });
  }
  return {
    runId: run.id,
    runKey,
    invalidated: inserts.length,
    replayed: false,
  };
}

export async function queueTargetedRebuild(client, options) {
  const userId = requiredUuid(options.userId, 'userId');
  if (!['cpns', 'bumn'].includes(options.target)) {
    throw new Error('target must be cpns or bumn.');
  }
  await client.rpc('enqueue_learning_projection', {
    p_user_id: userId,
    p_target: options.target,
    p_taxonomy_version_id: options.taxonomyVersionId ?? null,
    p_skill_id: options.skillId ?? null,
    p_reason: options.reason ?? 'manual_rebuild',
    p_source_attempt_id: null,
  });
}

function confirmedUser(options) {
  const userId = requiredUuid(options.userId, 'userId');
  const confirmation = requiredUuid(
    options.confirmDisposable,
    'confirmDisposable',
  );
  if (userId !== confirmation) {
    throw new Error(
      'confirmDisposable must exactly match userId before synthetic evidence can be changed.',
    );
  }
  return userId;
}

function compareNewest(left, right) {
  return (
    String(right.effective_at).localeCompare(String(left.effective_at)) ||
    String(right.created_at).localeCompare(String(left.created_at)) ||
    String(left.id).localeCompare(String(right.id))
  );
}

function sha256(value) {
  return createHash('sha256').update(stableJson(value)).digest('hex');
}

function requiredUuid(value, label) {
  const result = required(value, label);
  if (!UUID_PATTERN.test(result)) throw new Error(`${label} must be a UUID.`);
  return result;
}

function required(value, label) {
  if (!value?.trim()) throw new Error(`${label} is required.`);
  return value.trim();
}
