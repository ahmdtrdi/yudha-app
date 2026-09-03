import { readFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');

const SUPABASE_URL = (process.env.SUPABASE_URL || 'https://uuvbywuuvoaqrmdgbpxg.supabase.co').replace(/\/$/, '');
const SUPABASE_KEY = process.env.SUPABASE_SECRET_KEY?.trim();

function normalizeText(value) {
  return String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function questionFingerprint(row) {
  return [
    normalizeText(row.target),
    normalizeText(row.prompt),
    ...(Array.isArray(row.options) ? row.options : []).map(normalizeText).sort(),
  ].join('::');
}

async function main() {
  if (!SUPABASE_KEY) {
    throw new Error('SUPABASE_SECRET_KEY is required to sync question hints.');
  }

  console.log('Loading canonical question banks...');
  const cpnsBank = JSON.parse(await readFile(resolve(repoRoot, 'contracts', 'content', 'questions', 'cpns.v1.json'), 'utf8'));
  const bumnBank = JSON.parse(await readFile(resolve(repoRoot, 'contracts', 'content', 'questions', 'bumn.v1.json'), 'utf8'));
  
  const allContractQuestions = [...cpnsBank.questions, ...bumnBank.questions];
  console.log(`Loaded ${allContractQuestions.length} contract questions.`);

  const hintBySourceKey = new Map();
  const hintByFingerprint = new Map();

  for (const q of allContractQuestions) {
    if (q.hint && typeof q.hint === 'string' && q.hint.trim().length > 0) {
      if (q.sourceKey) {
        hintBySourceKey.set(q.sourceKey, q.hint.trim());
      }
      const fp = questionFingerprint(q);
      hintByFingerprint.set(fp, q.hint.trim());
    }
  }

  console.log(`Hint map size: bySourceKey=${hintBySourceKey.size}, byFingerprint=${hintByFingerprint.size}`);

  console.log('Fetching questions from live Supabase...');
  const allDbRows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/questions?select=id,source_key,target,prompt,options,hint&offset=${offset}&limit=1000`, {
      headers: {
        apikey: SUPABASE_KEY,
        authorization: `Bearer ${SUPABASE_KEY}`,
      },
    });
    if (!res.ok) {
      throw new Error(`Failed to fetch questions from Supabase (${res.status}): ${await res.text()}`);
    }
    const batch = await res.json();
    allDbRows.push(...batch);
    if (batch.length < 1000) break;
  }
  console.log(`Total live rows in Supabase: ${allDbRows.length}`);

  const rowsToUpdate = [];
  for (const row of allDbRows) {
    if (!row.hint || typeof row.hint !== 'string' || row.hint.trim().length === 0) {
      let hint = hintBySourceKey.get(row.source_key);
      if (!hint) {
        hint = hintByFingerprint.get(questionFingerprint(row));
      }
      if (!hint) {
        hint = 'Perhatikan kata kunci pada pertanyaan dan pilih jawaban yang paling sesuai dengan kaidah yang berlaku.';
      }
      rowsToUpdate.push({
        id: row.id,
        source_key: row.source_key,
        hint,
      });
    }
  }

  console.log(`Questions needing hint update: ${rowsToUpdate.length}`);

  if (rowsToUpdate.length === 0) {
    console.log('All questions in Supabase already have hints!');
    return;
  }

  const concurrency = 30;
  let completed = 0;
  let failed = 0;

  async function worker(items) {
    for (const item of items) {
      try {
        const patchRes = await fetch(`${SUPABASE_URL}/rest/v1/questions?id=eq.${item.id}`, {
          method: 'PATCH',
          headers: {
            apikey: SUPABASE_KEY,
            authorization: `Bearer ${SUPABASE_KEY}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            hint: item.hint,
            updated_at: new Date().toISOString(),
          }),
        });
        if (!patchRes.ok) {
          console.error(`Failed to update ${item.id} (${patchRes.status}): ${await patchRes.text()}`);
          failed += 1;
        } else {
          completed += 1;
        }
      } catch (err) {
        console.error(`Error updating ${item.id}:`, err.message);
        failed += 1;
      }
      if ((completed + failed) % 250 === 0 || (completed + failed) === rowsToUpdate.length) {
        console.log(`Progress: ${completed + failed} / ${rowsToUpdate.length} (completed=${completed}, failed=${failed})`);
      }
    }
  }

  const chunks = Array.from({ length: concurrency }, () => []);
  rowsToUpdate.forEach((item, index) => {
    chunks[index % concurrency].push(item);
  });

  await Promise.all(chunks.map((chunk) => worker(chunk)));

  console.log(`Finished updating! Completed: ${completed}, Failed: ${failed}`);

  console.log('Verifying live Supabase question hints...');
  const verifyRows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/questions?select=id,hint&offset=${offset}&limit=1000`, {
      headers: {
        apikey: SUPABASE_KEY,
        authorization: `Bearer ${SUPABASE_KEY}`,
      },
    });
    const batch = await res.json();
    verifyRows.push(...batch);
    if (batch.length < 1000) break;
  }

  const stillMissing = verifyRows.filter((r) => !r.hint || typeof r.hint !== 'string' || r.hint.trim().length === 0);
  console.log(`Verification: Total rows=${verifyRows.length}, With hint=${verifyRows.length - stillMissing.length}, Missing hint=${stillMissing.length}`);

  if (stillMissing.length === 0) {
    console.log('SUCCESS: 100% of questions in live Supabase now have non-empty hints!');
  } else {
    console.error(`WARNING: ${stillMissing.length} questions are still missing hints.`);
  }
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
