const assert = require("node:assert/strict");
const Module = require("node:module");
const path = require("node:path");
const test = require("node:test");

const sdkRequests = [];
const embeddingModulePath = path.resolve(__dirname, "embedding.js");
const originalLoad = Module._load;

Module._load = function (request, parent, isMain) {
  if (
    request === "@google/genai" &&
    parent &&
    path.resolve(parent.filename) === embeddingModulePath
  ) {
    return {
      GoogleGenAI: class {
        constructor() {
          this.models = {
            embedContent: async (requestOptions) => {
              sdkRequests.push(requestOptions);
              return {
                embeddings: [{ values: Array(768).fill(0.125) }],
              };
            },
          };
        }
      },
    };
  }

  return originalLoad.call(this, request, parent, isMain);
};

let embedding;
try {
  embedding = require("./embedding");
} finally {
  Module._load = originalLoad;
}

const {
  EMBEDDING_DIMENSION,
  EMBEDDING_MODEL,
  GeminiEmbeddingError,
  buildEmbeddingCacheKey,
  classifyGeminiEmbeddingError,
  createQueryEmbeddingCache,
  generateQuestionEmbedding,
  toGeminiEmbeddingError,
} = embedding;

test("question embeddings normalize text and reuse a valid cached vector", async () => {
  const first = await generateQuestionEmbedding("  زيتون\tوقت\nالجني  ");
  first[0] = 99;

  const second = await generateQuestionEmbedding("زيتون وقت الجني");

  assert.equal(sdkRequests.length, 1);
  assert.equal(sdkRequests[0].model, EMBEDDING_MODEL);
  assert.equal(sdkRequests[0].contents, "زيتون وقت الجني");
  assert.equal(sdkRequests[0].config.outputDimensionality, EMBEDDING_DIMENSION);
  assert.equal(sdkRequests[0].config.taskType, "RETRIEVAL_QUERY");
  assert.equal(second[0], 0.125);
});

test("document embeddings preserve the original chunk text", async () => {
  const text = "  texte du chunk  \n avec espaces ";

  await embedding.generateEmbedding(text);

  const request = sdkRequests.at(-1);
  assert.equal(request.contents, text);
  assert.equal(request.config.taskType, "RETRIEVAL_DOCUMENT");
});

test("embedding cache keys include model, dimension, and task type", () => {
  const defaultKey = buildEmbeddingCacheKey(
    "Question",
    "gemini-embedding-2",
    768,
    "RETRIEVAL_QUERY",
  );

  assert.notEqual(
    defaultKey,
    buildEmbeddingCacheKey("Question", "another-model", 768, "RETRIEVAL_QUERY"),
  );
  assert.notEqual(
    defaultKey,
    buildEmbeddingCacheKey("Question", "gemini-embedding-2", 3072, "RETRIEVAL_QUERY"),
  );
  assert.notEqual(
    defaultKey,
    buildEmbeddingCacheKey("Question", "gemini-embedding-2", 768, "RETRIEVAL_DOCUMENT"),
  );
});

test("embedding cache enforces its size limit and expires entries", async () => {
  let time = 0;
  let calls = 0;
  const cachedEmbedding = createQueryEmbeddingCache(
    async (text) => {
      calls++;
      return [text.length, 1];
    },
    {
      model: "test-model",
      dimension: 2,
      maxEntries: 1,
      ttlMs: 100,
      now: () => time,
    },
  );

  await cachedEmbedding("first");
  await cachedEmbedding("second");
  await cachedEmbedding("first");
  assert.equal(calls, 3);

  time += 101;
  await cachedEmbedding("first");
  assert.equal(calls, 4);
});

test("concurrent identical questions share one embedding request", async () => {
  let calls = 0;
  const cachedEmbedding = createQueryEmbeddingCache(
    () => {
      calls++;
      return Promise.resolve([1, 2]);
    },
    { model: "test-model", dimension: 2 },
  );

  const results = await Promise.all([
    cachedEmbedding("same question"),
    cachedEmbedding(" same   question "),
  ]);

  assert.equal(calls, 1);
  assert.deepEqual(results, [
    [1, 2],
    [1, 2],
  ]);
});

test("failed or invalid embedding responses are not cached", async () => {
  let calls = 0;
  const cachedEmbedding = createQueryEmbeddingCache(
    async () => {
      calls++;
      if (calls === 1) throw new Error("temporary failure");
      if (calls === 2) return [1];
      return [1, 2];
    },
    { model: "test-model", dimension: 2 },
  );

  await assert.rejects(cachedEmbedding("question"), /temporary failure/);
  await assert.rejects(cachedEmbedding("question"), /Invalid embedding dimension/);
  assert.deepEqual(await cachedEmbedding("question"), [1, 2]);
  assert.deepEqual(await cachedEmbedding("question"), [1, 2]);
  assert.equal(calls, 3);
});

test("Gemini daily quota errors are classified without retaining API details", () => {
  const upstreamError = new Error(
    JSON.stringify({
      error: {
        code: 429,
        status: "RESOURCE_EXHAUSTED",
        message:
          "Quota exceeded for metric embed_content_free_tier_requests; limit 1000 requests per day.",
      },
    }),
  );
  upstreamError.status = 429;

  const safeError = toGeminiEmbeddingError(upstreamError);

  assert.ok(safeError instanceof GeminiEmbeddingError);
  assert.equal(safeError.kind, "daily_quota");
  assert.equal(safeError.httpStatusCode, 429);
  assert.equal(safeError.statusCode, undefined);
  assert.doesNotMatch(safeError.message, /RESOURCE_EXHAUSTED|free_tier|1000/);
});

test("temporary Gemini rate limits are distinguished from daily quota errors", () => {
  const error = Object.assign(
    new Error(
      JSON.stringify({
        error: {
          code: 429,
          status: "RESOURCE_EXHAUSTED",
          message: "Requests per minute limit exceeded.",
        },
      }),
    ),
    { status: 429 },
  );

  assert.equal(classifyGeminiEmbeddingError(error), "temporary_rate_limit");

  const safeError = toGeminiEmbeddingError(error);
  assert.ok(safeError instanceof GeminiEmbeddingError);
  assert.equal(safeError.kind, "temporary_rate_limit");
  assert.equal(safeError.httpStatusCode, 503);
  assert.equal(safeError.statusCode, 429);
});

test("unknown RESOURCE_EXHAUSTED quota is not mislabeled as temporary", () => {
  const error = Object.assign(
    new Error(
      JSON.stringify({
        error: {
          code: 429,
          status: "RESOURCE_EXHAUSTED",
          message: "Quota exceeded for an unspecified limit.",
        },
      }),
    ),
    { status: 429 },
  );

  const safeError = toGeminiEmbeddingError(error);

  assert.ok(safeError instanceof GeminiEmbeddingError);
  assert.equal(safeError.kind, "quota_exhausted");
  assert.equal(safeError.httpStatusCode, 429);
  assert.equal(safeError.statusCode, undefined);
  assert.doesNotMatch(safeError.message, /RESOURCE_EXHAUSTED|unspecified/);
});
