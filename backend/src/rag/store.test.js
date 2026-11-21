const assert = require("node:assert/strict");
const Module = require("node:module");
const path = require("node:path");
const test = require("node:test");

const storeModulePath = path.resolve(__dirname, "store.js");
const originalLoad = Module._load;
let rows = [];
let nextId = 1;
let embed;

class MockGeminiEmbeddingError extends Error {
  constructor(kind) {
    super(kind);
    this.kind = kind;
    if (kind === "temporary_rate_limit") this.statusCode = 429;
  }
}

class MockSupabaseQuery {
  constructor() {
    this.operation = "select";
    this.equals = [];
    this.filters = [];
  }

  select() {
    return this;
  }

  eq(column, value) {
    this.equals.push([column, value]);
    return this;
  }

  filter(column, operator, value) {
    this.filters.push([column, operator, value]);
    return this;
  }

  limit(value) {
    this.limitValue = value;
    return this;
  }

  range(from, to) {
    this.rangeValue = [from, to];
    return this;
  }

  insert(records) {
    this.operation = "insert";
    this.records = records;
    return this;
  }

  update(values) {
    this.operation = "update";
    this.updateValues = values;
    return this;
  }

  then(resolve, reject) {
    try {
      return Promise.resolve(this.execute()).then(resolve, reject);
    } catch (error) {
      return Promise.reject(error).then(resolve, reject);
    }
  }

  execute() {
    if (this.operation === "insert") {
      const inserted = this.records.map((record) => ({
        id: nextId++,
        ...record,
      }));
      rows.push(...inserted);
      return { data: inserted, error: null };
    }

    if (this.operation === "update") {
      const row = rows.find((item) =>
        this.equals.every(([column, value]) => item[column] === value),
      );
      if (row) Object.assign(row, this.updateValues);
      return { data: row ? [row] : [], error: null };
    }

    let data = rows.filter((row) =>
      this.equals.every(([column, value]) => row[column] === value),
    );
    data = data.filter((row) =>
      this.filters.every(([column, , value]) => {
        if (column === "metadata->>ingestion_complete") {
          return String(row.metadata?.ingestion_complete) === value;
        }
        return false;
      }),
    );

    if (this.rangeValue) {
      data = data.slice(this.rangeValue[0], this.rangeValue[1] + 1);
    }
    if (this.limitValue !== undefined) {
      data = data.slice(0, this.limitValue);
    }

    return { data, error: null };
  }
}

Module._load = function (request, parent, isMain) {
  if (parent && path.resolve(parent.filename) === storeModulePath) {
    if (request === "dotenv") return { config: () => ({}) };
    if (request === "@supabase/supabase-js") {
      return {
        createClient: () => ({ from: () => new MockSupabaseQuery() }),
      };
    }
    if (request === "./embedding") {
      return {
        classifyGeminiEmbeddingError: (error) => error.kind || null,
        GeminiEmbeddingError: MockGeminiEmbeddingError,
        generateEmbedding: (...args) => embed(...args),
      };
    }
  }

  return originalLoad.call(this, request, parent, isMain);
};

let store;
try {
  store = require("./store");
} finally {
  Module._load = originalLoad;
}

function resetStoreState() {
  rows = [];
  nextId = 1;
}

function makeChunk(documentName, content, chunkIndex) {
  return {
    document_name: documentName,
    content,
    metadata: { page: 1, chunk_index: chunkIndex },
  };
}

test("store retries only temporary limits and resumes without re-embedding", async (t) => {
  await t.test("daily quota fails without retrying", async () => {
    resetStoreState();
    let attempts = 0;
    embed = async () => {
      attempts++;
      throw new MockGeminiEmbeddingError("daily_quota");
    };

    await assert.rejects(
      store.storeChunks([makeChunk("daily.pdf", "chunk", 0)]),
      (error) => error.kind === "daily_quota",
    );
    assert.equal(attempts, 1);
    assert.equal(rows.length, 0);
  });

  await t.test("temporary rate limit retries and then stores", async () => {
    resetStoreState();
    let attempts = 0;
    embed = async () => {
      attempts++;
      if (attempts === 1) {
        throw new MockGeminiEmbeddingError("temporary_rate_limit");
      }
      return [0.25];
    };

    const originalSetTimeout = global.setTimeout;
    global.setTimeout = (callback, _delay, ...args) =>
      originalSetTimeout(callback, 0, ...args);
    let result;
    try {
      result = await store.storeChunks([
        makeChunk("temporary.pdf", "chunk", 0),
      ]);
    } finally {
      global.setTimeout = originalSetTimeout;
    }

    assert.equal(attempts, 2);
    assert.equal(result.inserted, 1);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].metadata.ingestion_complete, true);
  });

  await t.test("previously stored chunks keep their embeddings", async () => {
    resetStoreState();
    const existing = makeChunk("resume.pdf", "stored chunk", 0);
    const originalEmbedding = [0.1, 0.2];
    rows.push({
      id: nextId++,
      ...existing,
      embedding: originalEmbedding,
    });

    let attempts = 0;
    embed = async () => {
      attempts++;
      return [0.3];
    };

    const result = await store.storeChunks([
      existing,
      makeChunk("resume.pdf", "missing chunk", 1),
    ]);

    assert.equal(attempts, 1);
    assert.equal(result.inserted, 1);
    assert.equal(rows.length, 2);
    assert.deepEqual(rows[0].embedding, originalEmbedding);
  });
});
