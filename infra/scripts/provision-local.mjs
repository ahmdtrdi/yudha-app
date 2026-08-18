import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const infraDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..');

run('npm', ['exec', '--', 'supabase', 'db', 'reset']);
const status = run('npm', ['exec', '--', 'supabase', 'status', '-o', 'env'], true);
const local = parseEnvironment(status.stdout);
const contentEnvironment = {
  ...process.env,
  SUPABASE_URL: local.API_URL ?? local.SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY: local.SERVICE_ROLE_KEY ?? local.SUPABASE_SERVICE_ROLE_KEY,
};
run(process.execPath, ['scripts/sync-content.mjs'], false, contentEnvironment);
if (process.argv.includes('--verify-idempotency')) {
  const replay = run(
    process.execPath,
    ['scripts/sync-content.mjs'],
    true,
    contentEnvironment,
  );
  process.stdout.write(replay.stdout);
  const output = replay.stdout.trim().split(/\r?\n/).at(-1);
  const report = JSON.parse(output).questions;
  if (
    report.inserted !== 0 ||
    report.updated !== 0 ||
    report.invalid !== 0 ||
    report.duplicate !== 0 ||
    report.skipped !== 350
  ) {
    process.stderr.write(
      `Idempotency verification failed: ${JSON.stringify(report)}\n`,
    );
    process.exit(1);
  }
}

function run(command, args, capture = false, env = process.env) {
  const result = spawnSync(command, args, {
    cwd: infraDirectory,
    env,
    encoding: 'utf8',
    shell: process.platform === 'win32',
    stdio: capture ? 'pipe' : 'inherit',
  });
  if (result.status !== 0) {
    if (capture && result.stderr) process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
  return result;
}

function parseEnvironment(output) {
  return Object.fromEntries(output.split(/\r?\n/).map((line) => line.match(/^([A-Z0-9_]+)=(?:"(.*)"|(.*))$/)).filter(Boolean).map((match) => [match[1], match[2] ?? match[3] ?? '']));
}
