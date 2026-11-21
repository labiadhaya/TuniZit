// backend/src/config/scanGemini.js hathi config gemini nte3 narjes
const { GoogleGenAI } = require("@google/genai");

if (!process.env.GEMINI_API_KEY_FEATURE_B) {
  throw new Error("GEMINI_API_KEY_FEATURE_B is missing from .env");
}

module.exports = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY_FEATURE_B,
  apiVersion: "v1beta",
});
