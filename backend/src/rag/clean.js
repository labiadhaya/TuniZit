function cleanOCRText(text) {
  if (!text) return "";

  return (
    text
      // Normalize Arabic characters
      .normalize("NFC")
      .replace(/[أإآ]/g, "ا")
      .replace(/ى/g, "ي")
      .replace(/ـ/g, "")

      // Remove invisible and control characters
      .replace(/[\u200B-\u200F\u202A-\u202E\uFEFF]/g, "")

      // Remove OCR noise while preserving Arabic, French and numbers
      .replace(/[^\p{Script=Arabic}a-zA-ZÀ-ÿ0-9\s.,;:!?؟،؛()«»"'/%+-]/gu, " ")

      // Normalize whitespace
      .replace(/[ \t]+/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim()
  );
}

function cleanPage(text) {
  const cleaned = cleanOCRText(text);

  return cleaned
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => {
      if (!line) return false;

      const lettersAndNumbers = (line.match(/[\p{L}\p{N}]/gu) || []).length;

      // Ignore lines dominated by OCR symbols
      return lettersAndNumbers >= 3 && lettersAndNumbers / line.length >= 0.35;
    })
    .join("\n")
    .trim();
}

module.exports = {
  cleanOCRText,
  cleanPage,
};
