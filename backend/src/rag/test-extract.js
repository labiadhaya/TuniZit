const path = require("path");
const { extractPDFWithOCR } = require("./ocr");

async function main() {
  const pdfPath = path.join(
    __dirname,
    "../../data/documents/Transf-Olives-Bio.pdf",
  );

  try {
    const result = await extractPDFWithOCR(pdfPath);

    console.log("\n========== OCR RESULT ==========");
    console.log("Pages:", result.totalPages);
    console.log("Characters:", result.text.length);
    console.log(result.text.substring(0, 3000));
  } catch (error) {
    console.error("OCR Error:", error);
  }
}

main();
