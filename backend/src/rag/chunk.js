const { cleanPage } = require("./clean");

function chunkText(text, chunkSize = 1000, overlap = 150) {
  const cleanText = text.replace(/\s+/g, " ").trim();

  if (!cleanText) return [];

  const chunks = [];
  let start = 0;

  while (start < cleanText.length) {
    let end = Math.min(start + chunkSize, cleanText.length);

    if (end < cleanText.length) {
      const section = cleanText.slice(start, end);

      const minBoundary = Math.floor(chunkSize * 0.7);

      const boundary = Math.max(
        section.lastIndexOf(". "),
        section.lastIndexOf("۔ "),
        section.lastIndexOf("؟ "),
        section.lastIndexOf("! "),
        section.lastIndexOf("، "),
      );

      if (boundary >= minBoundary) {
        end = start + boundary + 1;
      }
    }

    const content = cleanText.slice(start, end).trim();

    if (content) {
      chunks.push(content);
    }

    if (end >= cleanText.length) break;

    start = Math.max(start + 1, end - overlap);
  }

  return chunks;
}

function createDocumentChunks(pages, documentName) {
  const allChunks = [];

  for (const page of pages) {
    const cleanedText = cleanPage(page.text);

    if (cleanedText.length < 40) {
      console.log(`Skipping noisy page ${page.pageNumber}`);
      continue;
    }

    const chunks = chunkText(cleanedText, 1000, 150);

    chunks.forEach((content, index) => {
      allChunks.push({
        document_name: documentName,
        content,
        metadata: {
          page: page.pageNumber,
          chunk_index: index,
          source: documentName,
          language: "ar",
          extraction_method: "ocr",
        },
      });
    });
  }

  return allChunks;
}

module.exports = {
  chunkText,
  createDocumentChunks,
};
