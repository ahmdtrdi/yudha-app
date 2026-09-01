import assert from 'node:assert/strict';
import test from 'node:test';
import {
  normalizeQuestionTaxonomy,
  QUESTION_TAXONOMY,
} from './question-taxonomy.mjs';

test('normalizes ability aliases without the kemampuan prefix', () => {
  assert.deepEqual(
    normalizeQuestionTaxonomy({
      sourceKey: 'canonical:cpns:1',
      target: 'cpns',
      category: 'tiu',
      subcategory: 'kemampuan_logis',
    }),
    {
      sourceKey: 'canonical:cpns:1',
      target: 'cpns',
      category: 'tiu',
      subcategory: 'logis',
      primarySkillId: 'cpns.tiu.logis',
    },
  );
});

test('classifies legacy questions that previously had no subcategory', () => {
  assert.equal(
    normalizeQuestionTaxonomy({
      sourceKey: 'legacy:cpns:202',
      target: 'cpns',
      category: 'twk',
      subcategory: null,
    }).subcategory,
    'sejarah_dan_kebangsaan',
  );
  assert.equal(
    normalizeQuestionTaxonomy({
      sourceKey: 'legacy:bumn:79',
      target: 'bumn',
      category: 'akhlak',
      subcategory: null,
    }).subcategory,
    'amanah',
  );
});

test('defines exactly the product taxonomy shown in the practice catalog', () => {
  assert.deepEqual(QUESTION_TAXONOMY.cpns.tiu, [
    'verbal',
    'numerik',
    'logis',
    'figural',
  ]);
  assert.deepEqual(QUESTION_TAXONOMY.bumn.tkd, [
    'verbal',
    'numerik',
    'logis',
    'figural',
  ]);
  assert.deepEqual(QUESTION_TAXONOMY.cpns.twk, [
    'pancasila_dan_ideologi',
    'konstitusi_dan_negara',
    'sejarah_dan_kebangsaan',
    'bhinneka_tunggal_ika',
  ]);
});
