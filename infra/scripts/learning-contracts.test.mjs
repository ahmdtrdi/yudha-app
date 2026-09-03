import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const ROOT = new URL("../../", import.meta.url);

test("Learning V2 OpenAPI and fixtures evolve together without removing legacy analytics", async () => {
  const openapi = await json("contracts/openapi/yudha-api.v1.json");
  const dashboard = await json(
    "contracts/fixtures/learning-v2-dashboard-mixed.json",
  );
  const emptyDashboard = await json(
    "contracts/fixtures/learning-v2-dashboard-empty.json",
  );
  const lowConfidenceDashboard = await json(
    "contracts/fixtures/learning-v2-dashboard-low-confidence.json",
  );
  const fullDashboard = await json(
    "contracts/fixtures/learning-v2-dashboard-full.json",
  );
  const recommendation = await json(
    "contracts/fixtures/learning-v2-recommendation-current.json",
  );
  const hint = await json("contracts/fixtures/learning-v2-practice-hint.json");
  const lobby = await json("contracts/fixtures/gate1/lobby-summary.json");

  assert.ok(openapi.paths["/analytics"]);
  assert.ok(openapi.paths["/learning/dashboard"]);
  assert.ok(openapi.paths["/learning/recommendations/current"]);
  assert.ok(
    openapi.paths["/learning/recommendations/{recommendationId}/events"],
  );
  assert.ok(
    openapi.paths["/practice/sessions/{id}/questions/{sessionQuestionId}/hint"],
  );
  for (const fixture of [
    emptyDashboard,
    dashboard,
    lowConfidenceDashboard,
    fullDashboard,
  ]) {
    validateSchema(
      fixture.data,
      openapi.components.schemas.LearningDashboard,
      openapi,
      "$.data",
    );
  }
  assert.equal(dashboard.data.calculationVersion, "learning-v1");
  assert.equal(dashboard.data.summary.pace.value, null);
  assert.equal(dashboard.data.assessment.status, "not_available");
  assert.equal(dashboard.data.activity.recentSessions.length, 1);
  assert.equal(dashboard.data.competition.tier, "warrior");
  assert.equal(
    emptyDashboard.data.summary.unseenIndependentAccuracy.value,
    null,
  );
  assert.equal(
    lowConfidenceDashboard.data.skillStates[0].status,
    "collecting_data",
  );
  assert.equal(fullDashboard.data.assessment.improvementPercentagePoints, 8);
  assert.equal(
    fullDashboard.data.competition.soloComparison.gapPercentagePoints,
    7.5,
  );
  assert.equal(
    recommendation.data.availability.compatibilityAdapter,
    "practice_fixed_five",
  );
  assert.equal(typeof hint.data.hint, "string");
  assert.equal(lobby.data.learningNextAction, null);
});

async function json(relativePath) {
  return JSON.parse(await readFile(new URL(relativePath, ROOT), "utf8"));
}

function validateSchema(value, schema, openapi, path) {
  if (schema.$ref) {
    const name = schema.$ref.split("/").at(-1);
    return validateSchema(
      value,
      openapi.components.schemas[name],
      openapi,
      path,
    );
  }
  if (schema.oneOf) {
    const matches = schema.oneOf.filter((candidate) => {
      try {
        validateSchema(value, candidate, openapi, path);
        return true;
      } catch {
        return false;
      }
    });
    assert.equal(matches.length, 1, `${path} must match exactly one schema`);
    return;
  }
  if ("const" in schema) assert.deepEqual(value, schema.const, `${path} const`);
  if (schema.enum) assert.ok(schema.enum.includes(value), `${path} enum`);
  if (schema.type) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    assert.ok(
      types.some((type) => matchesType(value, type)),
      `${path} type`,
    );
  }
  if (value === null) return;
  if (schema.required) {
    for (const key of schema.required) {
      assert.ok(Object.hasOwn(value, key), `${path}.${key} is required`);
    }
  }
  if (schema.properties && typeof value === "object" && !Array.isArray(value)) {
    for (const [key, child] of Object.entries(schema.properties)) {
      if (Object.hasOwn(value, key)) {
        validateSchema(value[key], child, openapi, `${path}.${key}`);
      }
    }
  }
  if (Array.isArray(value)) {
    if (schema.minItems !== undefined) {
      assert.ok(value.length >= schema.minItems, `${path} minItems`);
    }
    if (schema.maxItems !== undefined) {
      assert.ok(value.length <= schema.maxItems, `${path} maxItems`);
    }
    if (schema.items) {
      value.forEach((item, index) =>
        validateSchema(item, schema.items, openapi, `${path}[${index}]`),
      );
    }
  }
}

function matchesType(value, type) {
  if (type === "null") return value === null;
  if (type === "array") return Array.isArray(value);
  if (type === "object") {
    return value !== null && typeof value === "object" && !Array.isArray(value);
  }
  if (type === "integer") return Number.isInteger(value);
  return typeof value === type;
}
