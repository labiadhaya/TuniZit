const genAI = require("../config/gemini");
const {
  askTunizit,
  retrieveTunizitContext,
  sanitizeHistory,
} = require("../rag/chat");
const { GeminiEmbeddingError } = require("../rag/embedding");

const SYSTEM_INSTRUCTION = `
Tu es Tunizit AI, un assistant agricole intelligent spécialisé
dans l'agriculture tunisienne.

LANGUES:
- Comprends et réponds en arabe, tunisien, français et anglais.
- Adapte toujours ta réponse à la langue de l'utilisateur.
- Utilise un langage simple et accessible aux agriculteurs.
- Comprends la darija tunisienne (Derja Tounsi) en alphabet arabe ou en Arabizi
  (lettres latines, chiffres comme 3, 7 et 9, et mélange tunisien/français).
- Ne confonds pas l'Arabizi avec le français ou l'anglais; déduis son sens du contexte.
- Si l'utilisateur écrit en tunisien, réponds naturellement en derja et, si possible,
  avec le même alphabet que sa question.
- Utilise des termes agricoles simples et garde les noms scientifiques exacts.
- Si une expression est ambiguë, demande une précision en tunisien sans demander
  à l'utilisateur de traduire sa question.

EXPERTISE:
- Oléiculture tunisienne.
- Plantation, taille, fertilisation et irrigation.
- Maladies et ravageurs.
- Santé des cultures.
- Agriculture générale.

FIABILITÉ:
- Utilise prioritairement les documents agricoles récupérés.
- Ne fabrique jamais de données, chiffres ou références.
- Signale les informations incertaines.
- Ne prétends jamais qu'une information vient d'un document
  si elle n'est pas présente dans le contexte récupéré.
- Si les documents sont insuffisants, indique-le clairement.
- Ne donne pas de dosage phytosanitaire sans référence fiable
  et vérification de l'homologation en Tunisie.

CONTEXTE:
- Tiens compte des régions et du climat tunisien.
- Demande des précisions lorsque cela est nécessaire.

FORMAT:
- Réponses claires, pratiques et concises.
- Environ 150 mots maximum par défaut.
`;

function validateMessage(message, res) {
  if (!message || typeof message !== "string" || !message.trim()) {
    res.status(400).json({
      success: false,
      message: "Veuillez saisir une question.",
    });
    return false;
  }

  if (message.length > 4000) {
    res.status(400).json({
      success: false,
      message: "Votre question est trop longue.",
    });
    return false;
  }

  return true;
}

function buildPrompt(question, history, context) {
  return `
${SYSTEM_INSTRUCTION}

DOCUMENTS AGRICOLES RÉCUPÉRÉS:
${context}

HISTORIQUE DE CONVERSATION:
${history.map((item) => `${item.role}: ${item.text}`).join("\n")}

QUESTION ACTUELLE:
${question}

Réponds dans la langue de l'utilisateur.
Utilise les documents comme source principale.
Si les informations sont insuffisantes, précise cette limite.
`;
}

function getEmbeddingFailure(error) {
  if (!(error instanceof GeminiEmbeddingError)) return null;

  return {
    statusCode: error.httpStatusCode,
    message: error.message,
    code: error.code,
  };
}

// NON-STREAMING CHAT
async function chat(req, res) {
  try {
    const { message, history = [] } = req.body;

    if (!validateMessage(message, res)) return;

    const safeHistory = sanitizeHistory(history);

    console.log("🌿 RAG CONTROLLER ACTIVATED");
    console.log("User question:", message);

    const result = await askTunizit(message.trim(), safeHistory);
    console.log("RAG ANSWER:", result.answer);
    console.log("RAG SOURCES:", result.sources.length);

    // askTunizit returns the answer and source references.
    // Keep its answer as the RAG result.
    return res.json({
      success: true,
      answer: result.answer,
      sources: result.sources,
      provider: "Gemini RAG",
    });
  } catch (error) {
    const embeddingFailure = getEmbeddingFailure(error);
    if (embeddingFailure) {
      console.warn("RAG embedding unavailable:", embeddingFailure.code);
      return res.status(embeddingFailure.statusCode).json({
        success: false,
        message: embeddingFailure.message,
      });
    }

    console.error(
      "RAG chat failed:",
      error?.code || error?.name || "UnknownError",
    );

    return res.status(502).json({
      success: false,
      message: "Impossible de contacter Tunizit. Réessayez.",
    });
  }
}

// STREAMING CHAT
async function chatStream(req, res) {
  const { message, history = [] } = req.body;

  if (!validateMessage(message, res)) return;

  const safeHistory = sanitizeHistory(history);

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();

  try {
    const result = await retrieveTunizitContext(message.trim());

    const prompt = buildPrompt(
      message.trim(),
      safeHistory,
      result.context,
    );

    const stream = await genAI.models.generateContentStream({
      model: process.env.GEMINI_MODEL,
      contents: prompt,
      config: {
        temperature: 0.2,
        maxOutputTokens: 1200,
      },
    });

    for await (const chunk of stream) {
      if (chunk.text) {
        res.write(`data: ${JSON.stringify({ text: chunk.text })}\n\n`);
      }
    }

    res.write(`data: ${JSON.stringify({ sources: result.sources })}\n\n`);

    res.write("data: [DONE]\n\n");
  } catch (error) {
    const embeddingFailure = getEmbeddingFailure(error);
    console.error(
      "RAG stream failed:",
      embeddingFailure?.code || error?.code || error?.name || "UnknownError",
    );

    res.write(
      `data: ${JSON.stringify({
        error:
          embeddingFailure?.message ||
          "L'assistant est temporairement indisponible.",
      })}\n\n`,
    );
  } finally {
    res.end();
  }
}

module.exports = { chat, chatStream };
