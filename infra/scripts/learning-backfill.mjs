import { createHash } from 'node:crypto';
import { stableJson } from './sync-content.mjs';

const CLASSIFICATION_VERSION = 'evidence-v1';

export async function runLegacyBackfill(client, options) {
  const source = normalizeSource(options.source);
  const apply = options.apply === true;
  const runKey = required(options.runKey, 'runKey');
  const existingRuns = await client.selectAll(
    'learning_backfill_runs',
    '*',
    `run_key=eq.${encodeURIComponent(runKey)}`,
  );
  if (existingRuns.length > 0) {
    const previous = existingRuns[0];
    if (previous.source !== source || Boolean(previous.dry_run) === apply) {
      throw new Error('Backfill run key was already used for different input.');
    }
    if (previous.status !== 'completed') {
      throw new Error(`Backfill run ${runKey} is ${previous.status}.`);
    }
    return { ...previous.report, replayed: true };
  }

  const sourceRows =
    source === 'legacy_solo'
      ? await loadPracticeSource(client)
      : await loadPvpSource(client);
  const desired = sourceRows.map((row) => toAttempt(source, row));
  const ledgerSource = source === 'legacy_solo' ? 'solo' : 'pvp';
  const existingAttempts = await client.selectAll(
    'learning_attempts',
    'id,source_attempt_key,source_payload_hash',
    `source=eq.${ledgerSource}`,
  );
  const existingByKey = new Map(
    existingAttempts.map((row) => [row.source_attempt_key, row]),
  );
  const inserts = [];
  let skipped = 0;
  for (const attempt of desired) {
    const existing = existingByKey.get(attempt.source_attempt_key);
    if (!existing) {
      inserts.push(attempt);
      continue;
    }
    if (existing.source_payload_hash !== attempt.source_payload_hash) {
      throw new Error(
        `Canonical source collision for ${attempt.source_attempt_key}.`,
      );
    }
    skipped += 1;
  }
  const report = {
    source,
    dryRun: !apply,
    scanned: sourceRows.length,
    eligible: desired.length,
    inserted: apply ? inserts.length : 0,
    wouldInsert: inserts.length,
    skipped,
    unsupportedProficiency: desired.length,
    excludedTargets:
      sourceRows.excludedTargets ?? 0,
  };

  if (!apply) return report;

  const [run] = await client.insertReturning('learning_backfill_runs', [
    {
      run_key: runKey,
      source,
      dry_run: false,
      status: 'running',
      source_watermark: sourceWatermark(sourceRows),
      report: {},
    },
  ]);
  try {
    const inserted = await client.insertReturning('learning_attempts', inserts);
    const allByKey = new Map(existingByKey);
    for (const row of inserted) allByKey.set(row.source_attempt_key, row);
    const classificationRows = desired.map((attempt) => {
      const stored = allByKey.get(attempt.source_attempt_key);
      if (!stored?.id) {
        throw new Error(
          `Attempt lookup failed for ${attempt.source_attempt_key}.`,
        );
      }
      return legacyClassification(stored.id, source);
    });
    const existingClassifications = await client.selectAll(
      'learning_attempt_classifications',
      'attempt_id,classification_version',
      `classification_version=eq.${CLASSIFICATION_VERSION}`,
    );
    const classifiedIds = new Set(
      existingClassifications.map((row) => row.attempt_id),
    );
    await client.insert(
      'learning_attempt_classifications',
      classificationRows.filter((row) => !classifiedIds.has(row.attempt_id)),
    );
    await client.updateWhere(
      'learning_backfill_runs',
      `id=eq.${encodeURIComponent(run.id)}`,
      {
        status: 'completed',
        completed_at: new Date().toISOString(),
        report,
      },
    );
    return { ...report, replayed: false };
  } catch (error) {
    await client.updateWhere(
      'learning_backfill_runs',
      `id=eq.${encodeURIComponent(run.id)}`,
      {
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message,
        report,
      },
    );
    throw error;
  }
}

async function loadPracticeSource(client) {
  const [answers, sessions] = await Promise.all([
    client.selectAll(
      'practice_answers',
      'id,session_id,user_id,question_id,selected_option_index,is_correct,answered_at',
      'canonical_attempt_id=is.null',
    ),
    client.selectAll(
      'practice_sessions',
      'id,user_id,target,category,subcategory,started_at,finished_at',
    ),
  ]);
  const sessionsById = new Map(sessions.map((row) => [row.id, row]));
  const rows = [];
  let excludedTargets = 0;
  for (const answer of answers) {
    const session = sessionsById.get(answer.session_id);
    if (!session || !['cpns', 'bumn'].includes(session.target)) {
      excludedTargets += 1;
      continue;
    }
    rows.push({ ...answer, session });
  }
  rows.excludedTargets = excludedTargets;
  return rows;
}

async function loadPvpSource(client) {
  const [logs, matches] = await Promise.all([
    client.selectAll(
      'match_logs',
      'id,match_result_id,player_id,question_id,action_type,selected_option_index,is_correct,response_time_ms,action_timestamp',
      'player_id=not.is.null&is_correct=not.is.null',
    ),
    client.selectAll(
      'match_results',
      'id,target,mode,ended_at',
      'mode=in.(casual,ranked,private)',
    ),
  ]);
  const matchById = new Map(matches.map((row) => [row.id, row]));
  const rows = [];
  let excludedTargets = 0;
  for (const log of logs) {
    const match = matchById.get(log.match_result_id);
    if (!match || !['cpns', 'bumn'].includes(match.target)) {
      excludedTargets += 1;
      continue;
    }
    rows.push({ ...log, match });
  }
  rows.excludedTargets = excludedTargets;
  return rows;
}

function toAttempt(source, row) {
  const solo = source === 'legacy_solo';
  const snapshot = solo
    ? {
        source: 'solo',
        answerId: row.id,
        sessionId: row.session_id,
        userId: row.user_id,
        target: row.session.target,
        questionId: row.question_id,
        selectedOptionIndex: row.selected_option_index,
        isCorrect: row.is_correct,
        answeredAt: row.answered_at,
      }
    : {
        source: 'pvp',
        logId: row.id,
        matchId: row.match_result_id,
        userId: row.player_id,
        target: row.match.target,
        mode: row.match.mode,
        questionId: row.question_id,
        selectedOptionIndex: row.selected_option_index,
        isCorrect: row.is_correct,
        actionAt: row.action_timestamp,
      };
  return {
    source: solo ? 'solo' : 'pvp',
    source_attempt_key: `${solo ? 'practice' : 'pvp'}:${row.id}`,
    source_payload_hash: sha256(snapshot),
    data_fidelity: source,
    user_id: solo ? row.user_id : row.player_id,
    target: solo ? row.session.target : row.match.target,
    source_session_key: solo ? row.session_id : row.match_result_id,
    pvp_mode: solo ? null : row.match.mode,
    session_completion_state: solo
      ? row.session.finished_at
        ? 'compatibility_completed'
        : 'in_progress'
      : null,
    question_id: row.question_id,
    question_revision_id: null,
    taxonomy_version_id: null,
    skill_id: null,
    category: solo ? row.session.category : null,
    subcategory: solo ? row.session.subcategory : null,
    selected_option_index: row.selected_option_index,
    is_correct: row.is_correct,
    hint_requested: null,
    timed_out: solo ? null : row.action_type === 'timeout',
    first_attempt: null,
    seen_before: null,
    client_active_response_time_ms: null,
    server_elapsed_time_ms: null,
    background_duration_ms: null,
    effective_response_time_ms: null,
    timing_invalidity_reason: 'legacy_timing_not_authoritative',
    answered_at: solo ? row.answered_at : row.action_timestamp,
    source_event_at: solo ? row.answered_at : row.action_timestamp,
  };
}

function legacyClassification(attemptId, source) {
  const reasons = [
    'revision_unknown',
    'skill_eligibility_unknown',
    'hint_eligibility_unknown',
    'exposure_eligibility_unknown',
    'timing_eligibility_unknown',
  ];
  if (source === 'legacy_pvp') reasons.push('competition_context_separate');
  const snapshot = {
    attemptId,
    classificationVersion: CLASSIFICATION_VERSION,
    reasons,
  };
  return {
    attempt_id: attemptId,
    classification_version: CLASSIFICATION_VERSION,
    classifier_input_hash: sha256(snapshot),
    valid_for_activity_accuracy: false,
    valid_for_independent_accuracy: false,
    valid_for_unseen_independent_accuracy: false,
    valid_for_assisted_accuracy: false,
    valid_for_pace_analytics: false,
    valid_for_fluency_baseline: false,
    valid_for_retention: false,
    exclusion_reasons: reasons,
  };
}

function sourceWatermark(rows) {
  const values = rows.map((row) =>
    String(row.answered_at ?? row.action_timestamp),
  );
  return {
    rowCount: rows.length,
    latestSourceEventAt: values.sort().at(-1) ?? null,
  };
}

function normalizeSource(value) {
  if (value === 'practice' || value === 'legacy_solo') return 'legacy_solo';
  if (value === 'pvp' || value === 'legacy_pvp') return 'legacy_pvp';
  throw new Error('source must be practice or pvp.');
}

function sha256(value) {
  return createHash('sha256').update(stableJson(value)).digest('hex');
}

function required(value, label) {
  if (!value?.trim()) throw new Error(`${label} is required.`);
  return value.trim();
}
