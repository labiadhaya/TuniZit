const path = require("path");
const fs = require("fs");

const { extractPDFWithOCR } = require("./ocr");
const { createDocumentChunks } = require("./chunk");

async function main() {
  const documentName = "Transf-Olives-Bio.pdf";

  const pdfPath = path.join(__dirname, "../../data/documents", documentName);

  try {
    console.log("Starting OCR...");

    const result = await extractPDFWithOCR(pdfPath);

    console.log("\nStarting Chunking...");

    const chunks = createDocumentChunks(result.pages, documentName);

    console.log("Total pages:", result.totalPages);
    console.log("Total chunks:", chunks.length);

    console.log("\nFirst chunk:");
    console.log(chunks[0]);

    const outputPath = path.join(__dirname, "chunks-preview.json");

    fs.writeFileSync(outputPath, JSON.stringify(chunks, null, 2), "utf8");

    console.log("\nSaved:", outputPath);
  } catch (error) {
    console.error("Chunking error:", error);
  }
}

main();
