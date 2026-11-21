const { GoogleGenAI } = require("@google/genai");

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY_FEATURE_A,
});

const EMBEDDING_MODEL = "gemini-embedding-2";
const EMBEDDING_DIMENSION = 768;
const QUERY_EMBEDDING_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const QUERY_EMBEDDING_CACHE_MAX_ENTRIES = 500;

const errorMessages = {
  daily_quota:
    "Le quota quotidien des embeddings est atteint. Réessayez après sa réinitialisation.",
  temporary_rate_limit:
    "Le service d'embedding est temporairement limité. Réessayez dans quelques instants.",
  quota_exhausted:
    "Une limite d'utilisation Gemini est atteinte. Réessayez plus tard.",
};

class GeminiEmbeddingError extends Error {
  constructor(kind) {
    super(errorMessages[kind]);
    this.name = "GeminiEmbeddingError";
    this.kind = kind;
    this.code = {
      daily_quota: "GEMINI_DAILY_EMBEDDING_QUOTA",
      temporary_rate_limit: "GEMINI_EMBEDDING_RATE_LIMIT",
      quota_exhausted: "GEMINI_EMBEDDING_QUOTA_EXCEEDED",
    }[kind];
    this.httpStatusCode =
      kind === "temporary_rate_limit" ? 503 : 429;

    if (kind === "temporary_rate_limit") {
      this.statusCode = 429;
    }
  }
}

function normalizeEmbeddingText(text) {
  if (typeof text !== "string" || !text.trim()) {
    throw new Error("Text cannot be empty");
  }

  return text.normalize("NFC").replace(/\s+/g, " ").trim();
}

function buildEmbeddingCacheKey(text, model, dimension, taskType) {
  return JSON.stringify([
    model,
    dimension,
    taskType,
    normalizeEmbeddingText(text),
  ]);
}

function isValidEmbedding(embedding, dimension) {
  return (
    Array.isArray(embedding) &&
    embedding.length === dimension &&
    embedding.every((value) => Number.isFinite(value))
  );
}

function createQueryEmbeddingCache(
  embed,
  {
    model = EMBEDDING_MODEL,
    dimension = EMBEDDING_DIMENSION,
    taskType = "RETRIEVAL_QUERY",
    maxEntries = QUERY_EMBEDDING_CACHE_MAX_ENTRIES,
    ttlMs = QUERY_EMBEDDING_CACHE_TTL_MS,
    now = Date.now,
  } = {},
) {
  if (typeof embed !== "function") {
    throw new TypeError("An embedding function is required");
  }
  if (!Number.isInteger(dimension) || dimension <= 0) {
    throw new TypeError("Embedding dimension must be a positive integer");
  }
  if (!Number.isInteger(maxEntries) || maxEntries <= 0) {
    throw new TypeError("Cache size must be a positive integer");
  }
  if (!Number.isFinite(ttlMs) || ttlMs <= 0) {
    throw new TypeError("Cache TTL must be positive");
  }

  const cache = new Map();
  const inFlight = new Map();

  return async function generateCachedEmbedding(text) {
    const normalizedText = normalizeEmbeddingText(text);
    const key = buildEmbeddingCacheKey(
      normalizedText,
      model,
      dimension,
      taskType,
    );
    const currentTime = now();
    const cached = cache.get(key);

    if (cached) {
      if (
        cached.expiresAt > currentTime &&
        isValidEmbedding(cached.embedding, dimension)
      ) {
        cache.delete(key);
        cache.set(key, cached);
        return [...cached.embedding];
      }

      cache.delete(key);
    }

    const pending = inFlight.get(key);
    if (pending) {
      return [...(await pending)];
    }

    const request = (async () => {
      const embedding = await embed(normalizedText);
      if (!isValidEmbedding(embedding, dimension)) {
        throw new Error(`Invalid embedding dimension: ${embedding?.length}`);
      }

      const storedEmbedding = [...embedding];
      const expiresAt = now() + ttlMs;

      for (const [cacheKey, entry] of cache) {
        if (entry.expiresAt <= now()) {
          cache.delete(cacheKey);
        }
      }

      if (cache.has(key)) {
        cache.delete(key);
      }
      while (cache.size >= maxEntries) {
        cache.delete(cache.keys().next().value);
      }
      cache.set(key, { embedding: storedEmbedding, expiresAt });

      return storedEmbedding;
    })();

    inFlight.set(key, request);
    try {
      return [...(await request)];
    } finally {
      if (inFlight.get(key) === request) {
        inFlight.delete(key);
      }
    }
  };
}

function getErrorText(error) {
  return [error?.message, error?.body, error?.error]
    .map((value) => {
      if (typeof value === "string") return value;
      if (value === undefined || value === null) return "";
      try {
        return JSON.stringify(value);
      } catch {
        return "";
      }
    })
    .join(" ");
}

function classifyGeminiEmbeddingError(error) {
  const status = Number(error?.status ?? error?.statusCode);
  const text = getErrorText(error);
  const isRateLimit =
    status === 429 || /\b429\b|RESOURCE_EXHAUSTED/i.test(text);

  if (!isRateLimit) return null;

  if (/daily|per[\s_-]*day|requests?\s+per\s+day/i.test(text)) {
    return "daily_quota";
  }

  if (
    /per[\s_-]*(?:minute|second)|requests?\s+per\s+(?:minute|second)|too many requests|rate[_\s-]*limit|retry (?:after|in)/i.test(
      text,
    )
  ) {
    return "temporary_rate_limit";
  }

  return status === 429 && !/RESOURCE_EXHAUSTED/i.test(text)
    ? "temporary_rate_limit"
    : "quota_exhausted";
}

function toGeminiEmbeddingError(error) {
  const kind = classifyGeminiEmbeddingError(error);
  return kind ? new GeminiEmbeddingError(kind) : error;
}

async function generateEmbedding(text, taskType = "RETRIEVAL_DOCUMENT") {
  if (typeof text !== "string" || !text.trim()) {
    throw new Error("Text cannot be empty");
  }

  let response;
  try {
    response = await ai.models.embedContent({
      model: EMBEDDING_MODEL,
      contents: text,
      config: {
        outputDimensionality: EMBEDDING_DIMENSION,
        taskType,
      },
    });
  } catch (error) {
    throw toGeminiEmbeddingError(error);
  }

  const embedding = response.embeddings?.[0]?.values;

  if (!isValidEmbedding(embedding, EMBEDDING_DIMENSION)) {
    throw new Error(`Invalid embedding dimension: ${embedding?.length}`);
  }

  return embedding;
}

const generateQuestionEmbedding = createQueryEmbeddingCache(
  (text) => generateEmbedding(text, "RETRIEVAL_QUERY"),
  {
    model: EMBEDDING_MODEL,
    dimension: EMBEDDING_DIMENSION,
    taskType: "RETRIEVAL_QUERY",
  },
);

module.exports = {
  EMBEDDING_DIMENSION,
  EMBEDDING_MODEL,
  GeminiEmbeddingError,
  buildEmbeddingCacheKey,
  classifyGeminiEmbeddingError,
  createQueryEmbeddingCache,
  generateEmbedding,
  generateQuestionEmbedding,
  toGeminiEmbeddingError,
};
