import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runLegacyBackfill } from './learning-backfill.mjs';
import {
  invalidateLearningFixture,
  queueTargetedRebuild,
  seedLearningFixture,
} from './learning-fixtures.mjs';
import { RestClient, syncContent } from './sync-content.mjs';

export async function runLearningCli(argv, environment = process.env) {
  const [command, action, ...raw] = argv;
  const options = parseOptions(raw);
  if (command === 'sync') return syncContent(environment);
  const client = createClient(environment);
  if (command === 'backfill') {
    const source = action;
    if (!source) throw new Error('backfill requires practice or pvp.');
    return runLegacyBackfill(client, {
      source,
      apply: Boolean(options.apply),
      runKey:
        options['run-key'] ??
        `${source}:${options.apply ? 'apply' : 'dry-run'}:${new Date().toISOString()}`,
    });
  }
  if (command === 'fixture' && action === 'seed') {
    return seedLearningFixture(client, {
      userId: options['user-id'],
      confirmDisposable: options['confirm-disposable'],
      runKey: options['run-key'],
      scenario: options.scenario ?? 'mixed',
      baseTime: options['base-time'],
    });
  }
  if (command === 'fixture' && action === 'invalidate') {
    return invalidateLearningFixture(client, {
      userId: options['user-id'],
      confirmDisposable: options['confirm-disposable'],
      runKey: options['run-key'],
      reason: options.reason ?? 'synthetic fixture invalidated',
    });
  }
  if (command === 'rebuild') {
    const taxonomyVersionId = options['taxonomy-version-id'] ?? null;
    const skillId = options['skill-id'] ?? null;
    if (Boolean(taxonomyVersionId) !== Boolean(skillId)) {
      throw new Error(
        'taxonomy-version-id and skill-id must be supplied together for a targeted rebuild.',
      );
    }
    await queueTargetedRebuild(client, {
      userId: options['user-id'],
      target: options.target,
      taxonomyVersionId,
      skillId,
      reason: 'manual_rebuild',
    });
    return {
      userId: options['user-id'],
      target: options.target,
      taxonomyVersionId,
      skillId,
      queued: true,
    };
  }
  throw new Error(
    'Usage: learning-v2-cli.mjs sync | backfill <practice|pvp> [--apply] --run-key <key> | fixture <seed|invalidate> ... | rebuild ...',
  );
}

function createClient(environment) {
  const baseUrl = required(environment.SUPABASE_URL, 'SUPABASE_URL').replace(
    /\/$/,
    '',
  );
  const secret = required(
    environment.SUPABASE_SECRET_KEY ?? environment.SUPABASE_SERVICE_ROLE_KEY,
    'SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY',
  );
  return new RestClient(baseUrl, secret);
}

function parseOptions(values) {
  const options = {};
  for (let index = 0; index < values.length; index += 1) {
    const token = values[index];
    if (!token.startsWith('--')) throw new Error(`Unexpected argument ${token}.`);
    const key = token.slice(2);
    if (key === 'apply') {
      options.apply = true;
      continue;
    }
    const value = values[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`${token} requires a value.`);
    }
    options[key] = value;
    index += 1;
  }
  return options;
}

function required(value, label) {
  if (!value?.trim()) throw new Error(`${label} is required.`);
  return value.trim();
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runLearningCli(process.argv.slice(2))
    .then((report) => process.stdout.write(`${JSON.stringify(report)}\n`))
    .catch((error) => {
      process.stderr.write(`Learning V2 workflow failed: ${error.message}\n`);
      process.exitCode = 1;
    });
}
