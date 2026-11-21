// backend/src/config/gemini.js hathi 7tit fiha config gemin kol wa7da te3mel wa7ed b esem el fonctionnalite nte3ha
const { GoogleGenAI } = require("@google/genai");

if (!process.env.GEMINI_API_KEY_FEATURE_A) {
  throw new Error("GEMINI_API_KEY_FEATURE_A is missing from .env");
}

const genAI = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY_FEATURE_A,
});

module.exports = genAI;
