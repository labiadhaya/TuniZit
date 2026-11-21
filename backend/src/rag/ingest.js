require("dotenv").config();

const path = require("path");
const fs = require("fs");

const { extractPDFWithOCR } = require("./ocr");
const { createDocumentChunks } = require("./chunk");
const { isDocumentIngested, storeChunks } = require("./store");

// PDF files inside backend/data/documents
const DATA_DIR = path.join(__dirname, "../../data/documents");

const PDF_FILES = [
  "Production-olives-bio.pdf",
  "Rapport-global-Filiere-oleicole-2019--FAO.pdf",
  "Techniques de production en oléiculture.pdf",
];

async function ingestPDF(fileName) {
  console.log("\n====================================");
  console.log(`STARTING: ${fileName}`);
  console.log("====================================");

  const filePath = path.join(DATA_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    return;
  }

  if (await isDocumentIngested(fileName)) {
    console.log(`${fileName} was already ingested. Skipping.`);
    return;
  }

  // 1. OCR Extraction
  console.log("\n[1/4] Extracting PDF with OCR...");

  const extracted = await extractPDFWithOCR(filePath);

  console.log(`Pages extracted: ${extracted.totalPages}`);

  // 2. Cleaning and Chunking
  console.log("\n[2/4] Cleaning and chunking...");

  const chunks = createDocumentChunks(extracted.pages, fileName);

  console.log(`Generated chunks: ${chunks.length}`);

  if (chunks.length === 0) {
    console.log("No valid chunks found. Skipping...");
    return;
  }

  // 3. Embeddings + Supabase storage
  console.log("\n[3/4] Generating embeddings and storing...");

  const inserted = await storeChunks(chunks);

  // 4. Summary
  console.log("\n[4/4] INGESTION COMPLETED!");

  console.log({
    document: fileName,
    pages: extracted.totalPages,
    chunks: chunks.length,
    inserted: inserted.inserted,
  });
}

async function main() {
  console.log("====================================");
  console.log("       TUNIZIT RAG INGESTION");
  console.log("====================================");

  for (const fileName of PDF_FILES) {
    try {
      await ingestPDF(fileName);
    } catch (error) {
      console.error(`Failed to ingest ${fileName}:`);
      console.error(error.message);
    }
  }

  console.log("\n====================================");
  console.log("ALL DOCUMENTS PROCESSED");
  console.log("====================================");
}

main().catch((error) => {
  console.error("Ingestion failed:", error);
  process.exitCode = 1;
});
