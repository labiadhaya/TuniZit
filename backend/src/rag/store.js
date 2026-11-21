require("dotenv").config();

const { createClient } = require("@supabase/supabase-js");
const {
  classifyGeminiEmbeddingError,
  GeminiEmbeddingError,
  generateEmbedding,
} = require("./embedding");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_PUBLISHABLE_KEY,
);

const BATCH_SIZE = 10;
const DELAY_BETWEEN_EMBEDDINGS = 700;
const MAX_RETRIES = 5;
const INITIAL_RETRY_DELAY = 1000;
const MAX_RETRY_DELAY = 30000;
const STORED_CHUNKS_PAGE_SIZE = 1000;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function isRetryableRateLimitError(error) {
  const kind =
    error instanceof GeminiEmbeddingError
      ? error.kind
      : classifyGeminiEmbeddingError(error);

  return kind === "temporary_rate_limit";
}

function chunkKey(chunk) {
  const metadata = chunk.metadata || {};
  return JSON.stringify([
    chunk.document_name,
    metadata.page === undefined ? null : metadata.page,
    metadata.chunk_index === undefined ? null : metadata.chunk_index,
    chunk.content,
  ]);
}

async function generateWithRetry(text) {
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      return await generateEmbedding(text);
    } catch (error) {
      if (
        !isRetryableRateLimitError(error) ||
        attempt === MAX_RETRIES
      ) {
        throw error;
      }

      const delay = Math.min(
        INITIAL_RETRY_DELAY * 2 ** attempt,
        MAX_RETRY_DELAY,
      );

      console.log(`Rate limit. Waiting ${delay / 1000}s...`);
      await sleep(delay);
    }
  }
}

async function isDocumentIngested(documentName) {
  const { data, error } = await supabase
    .from("documents_chunks")
    .select("id")
    .eq("document_name", documentName)
    .filter("metadata->>ingestion_complete", "eq", "true")
    .limit(1);

  if (error) {
    throw new Error(`Supabase status query error: ${error.message}`);
  }

  return data.length > 0;
}

async function getStoredChunks(documentName) {
  const rows = [];

  for (let offset = 0; ; offset += STORED_CHUNKS_PAGE_SIZE) {
    const { data, error } = await supabase
      .from("documents_chunks")
      .select("id, content, metadata")
      .eq("document_name", documentName)
      .range(offset, offset + STORED_CHUNKS_PAGE_SIZE - 1);

    if (error) {
      throw new Error(`Supabase existing-chunks query error: ${error.message}`);
    }

    rows.push(...data);
    if (data.length < STORED_CHUNKS_PAGE_SIZE) break;
  }

  return rows;
}

async function storeDocumentChunks(documentName, chunks) {
  if (await isDocumentIngested(documentName)) {
    console.log(`${documentName} is already ingested. Skipping.`);
    return { inserted: 0, skipped: true };
  }

  const existingRows = await getStoredChunks(documentName);
  const storedByKey = new Map();
  for (const row of existingRows) {
    storedByKey.set(
      chunkKey({
        document_name: documentName,
        content: row.content,
        metadata: row.metadata,
      }),
      row,
    );
  }

  const pendingChunks = [];
  const seenKeys = new Set();
  for (const chunk of chunks) {
    const key = chunkKey(chunk);
    if (!storedByKey.has(key) && !seenKeys.has(key)) {
      pendingChunks.push(chunk);
      seenKeys.add(key);
    }
  }

  let insertedCount = 0;

  for (let i = 0; i < pendingChunks.length; i += BATCH_SIZE) {
    const batch = pendingChunks.slice(i, i + BATCH_SIZE);
    const records = [];

    console.log(
      `Processing batch ${Math.floor(i / BATCH_SIZE) + 1} | ${batch.length} chunks`,
    );

    for (let batchIndex = 0; batchIndex < batch.length; batchIndex++) {
      const chunk = batch[batchIndex];
      console.log(
        `Embedding: ${chunk.document_name} | Page ${chunk.metadata.page}`,
      );

      const embedding = await generateWithRetry(chunk.content);

      records.push({
        document_name: chunk.document_name,
        content: chunk.content,
        embedding,
        metadata: chunk.metadata,
      });

      if (i + batchIndex < pendingChunks.length - 1) {
        await sleep(DELAY_BETWEEN_EMBEDDINGS);
      }
    }

    const { data, error } = await supabase
      .from("documents_chunks")
      .insert(records)
      .select("id, content, metadata");

    if (error) {
      throw new Error(`Supabase insert error: ${error.message}`);
    }

    insertedCount += data.length;
    for (const row of data) {
      storedByKey.set(
        chunkKey({
          document_name: documentName,
          content: row.content,
          metadata: row.metadata,
        }),
        row,
      );
    }

    console.log(`Saved ${insertedCount}/${pendingChunks.length} new chunks`);
  }

  const finalChunk = chunks[chunks.length - 1];
  const finalRow = storedByKey.get(chunkKey(finalChunk));
  if (!finalRow) {
    throw new Error(`Could not find the final stored chunk for ${documentName}`);
  }

  if (!finalRow.metadata?.ingestion_complete) {
    const { error } = await supabase
      .from("documents_chunks")
      .update({
        metadata: { ...finalRow.metadata, ingestion_complete: true },
      })
      .eq("id", finalRow.id);

    if (error) {
      throw new Error(`Supabase completion update error: ${error.message}`);
    }
  }

  return { inserted: insertedCount, skipped: false };
}

async function storeChunks(chunks) {
  if (!Array.isArray(chunks) || chunks.length === 0) {
    throw new Error("No chunks to store");
  }

  const chunksByDocument = new Map();
  for (const chunk of chunks) {
    if (
      !chunk ||
      typeof chunk.document_name !== "string" ||
      typeof chunk.content !== "string"
    ) {
      throw new Error("Each chunk must include a document name and content");
    }

    const documentChunks = chunksByDocument.get(chunk.document_name) || [];
    documentChunks.push(chunk);
    chunksByDocument.set(chunk.document_name, documentChunks);
  }

  let inserted = 0;
  let skippedDocuments = 0;

  for (const [documentName, documentChunks] of chunksByDocument) {
    const result = await storeDocumentChunks(documentName, documentChunks);
    inserted += result.inserted;
    if (result.skipped) skippedDocuments++;
  }

  return { inserted, skippedDocuments };
}

module.exports = { isDocumentIngested, storeChunks };
