const fs = require("fs");
const path = require("path");
const pdfjsLib = require("pdfjs-dist/legacy/build/pdf.mjs");
const { createCanvas } = require("@napi-rs/canvas");
const { createWorker } = require("tesseract.js");

async function extractPDFWithOCR(filePath) {
  const data = new Uint8Array(fs.readFileSync(filePath));

  const pdf = await pdfjsLib.getDocument({
    data,
    useSystemFonts: true,
  }).promise;

  console.log(`PDF Pages: ${pdf.numPages}`);

  const worker = await createWorker("ara+fra+eng");

  const pages = [];

  try {
    for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
      console.log(`Processing page ${pageNum}/${pdf.numPages}`);

      const page = await pdf.getPage(pageNum);
      const viewport = page.getViewport({ scale: 2 });

      const canvas = createCanvas(
        Math.ceil(viewport.width),
        Math.ceil(viewport.height),
      );

      const context = canvas.getContext("2d");

      await page.render({
        canvas,
        canvasContext: context,
        viewport,
      }).promise;

      const imageBuffer = canvas.toBuffer("image/png");

      const { data: result } = await worker.recognize(imageBuffer);

      pages.push({
        pageNumber: pageNum,
        text: result.text.trim(),
      });

      console.log(`Extracted ${result.text.length} characters`);
    }
  } finally {
    await worker.terminate();
  }

  return {
    totalPages: pdf.numPages,
    pages,
  };
}

module.exports = { extractPDFWithOCR };
