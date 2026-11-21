const { PDFParse } = require("pdf-parse");
const fs = require("fs");

async function extractPDF(filePath) {
  const dataBuffer = new Uint8Array(fs.readFileSync(filePath));

  const parser = new PDFParse({
    data: dataBuffer,
  });

  try {
    const result = await parser.getText();

    return {
      text: result.text,
      totalPages: result.total,
    };
  } finally {
    await parser.destroy();
  }
}

module.exports = { extractPDF };
