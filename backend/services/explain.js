// Explication des resultats par un LLM (Gemini).
// Le systeme expert DECIDE ; le LLM ne fait que REFORMULER ce qui est deja calcule.
// Garde-fous : donnees limitees au resultat, controle de la sortie, texte de secours.

const LANGS = ["fr", "ar", "ar_tn"];
const LANG_INSTR = {
  fr: "français simple et clair",
  ar: "arabe standard simple et clair",
  ar_tn: "dialecte tunisien (derja) écrit en lettres arabes, simple et chaleureux",
};

const norm = (s) =>
  String(s).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

// Donnees envoyees au LLM : uniquement ce qui sert a expliquer (aucune donnee personnelle).
function buildContext(input, resultats) {
  return {
    conditions: {
      gouvernorat: input.gouvernorat,
      pluviometrie_mm: input.pluvio,
      sol: input.sol,
      drainage: input.drainage,
      eau: input.eau,
      objectif: input.objectif,
      gel: input.gel ?? null,
      salinite: input.salinite ?? null,
    },
    varietes: (resultats || []).slice(0, 3).map((v) => ({
      nom: v.variete,
      score: v.score,
      raisons: v.raisons,
      contraintes: v.limites,
    })),
  };
}

function buildPrompt(context, langue) {
  const system = [
    "Tu es l'assistant agronomique de l'application Tunizit, destinée aux agriculteurs tunisiens.",
    "Un système expert a déjà calculé une recommandation de variétés d'olivier. Tu dois seulement l'expliquer.",
    "Règles strictes :",
    "1. Utilise UNIQUEMENT les informations du JSON fourni.",
    "2. N'ajoute aucune variété, aucun chiffre, aucune dose, aucun traitement et aucun conseil absents du JSON.",
    "3. Ne présente jamais le résultat comme une certitude : c'est une recommandation indicative.",
    "4. Phrases courtes, vocabulaire simple, ton respectueux.",
    "5. Structure : une phrase de résumé ; pour chaque variété, pourquoi elle convient et son point d'attention ; une phrase finale conseillant de consulter un technicien agricole avant de planter.",
    "6. Garde les noms de variétés exactement comme dans le JSON.",
    "7. Texte brut, sans markdown, sans liens.",
    `8. Réponds en ${LANG_INSTR[langue] || LANG_INSTR.fr}.`,
  ].join("\n");
  const user = "Données du système expert (JSON) :\n" + JSON.stringify(context, null, 2);
  return { system, user };
}

// Texte de secours, sans IA, toujours disponible.
function fallbackExplanation(context, langue) {
  const ar = langue === "ar" || langue === "ar_tn";
  const L = ar
    ? { intro: "ملخص التوصية (محسوب بالنظام الخبير):", why: "لماذا تناسبك", watch: "نقاط الانتباه",
        none: "لا توجد صنف مناسب لهذه الظروف. استشر تقنيا فلاحيا.",
        end: "هذه توصية إرشادية. استشر تقنيا فلاحيا قبل الغراسة." }
    : { intro: "Résumé de la recommandation (calculée par notre système expert) :", why: "Pourquoi elle convient", watch: "Points d'attention",
        none: "Aucune variété ne convient à ces conditions. Consultez un technicien agricole.",
        end: "Cette recommandation est indicative. Consultez un technicien agricole avant de planter." };
  if (!context.varietes.length) return `${L.none}`;
  const lines = [L.intro];
  context.varietes.forEach((v, i) => {
    lines.push(`${i + 1}. ${v.nom} (${v.score}/100)`);
    if (v.raisons.length) lines.push(`   ${L.why} : ${v.raisons.join(" ; ")}`);
    if (v.contraintes.length) lines.push(`   ${L.watch} : ${v.contraintes.join(" ; ")}`);
  });
  lines.push(L.end);
  return lines.join("\n");
}

// Verifie que le LLM n'invente pas de variete et reste raisonnable.
function checkExplanation(text, context, allNames) {
  if (typeof text !== "string") return false;
  const t = text.trim();
  if (t.length < 20 || t.length > 3000) return false;
  if (/https?:\/\//i.test(t) || /<[a-z][\s\S]*>/i.test(t)) return false;
  const allowed = new Set(context.varietes.map((v) => norm(v.nom)));
  const body = norm(t);
  for (const name of allNames || []) {
    const n = norm(name);
    if (n && !allowed.has(n) && body.includes(n)) return false;
  }
  return true;
}

// Codes HTTP transitoires : on retente. Les autres (400, 401, 403, 404...) sont definitifs.
const RETRY_STATUS = new Set([429, 500, 502, 503, 504]);
const defaultSleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Extrait un court message lisible du corps d'une reponse d'erreur (jamais la cle API).
async function errorDetail(res) {
  try {
    const raw = await res.text();
    try { return String(JSON.parse(raw)?.error?.message || raw).slice(0, 200); }
    catch (_) { return String(raw).slice(0, 200); }
  } catch (_) { return ""; }
}

async function callGemini({ system, user }, opts = {}) {
  const {
    apiKey = process.env.GEMINI_API_KEY,
    model = process.env.GEMINI_MODEL || "gemini-3.8-flash",
    timeoutMs = 60000,       // par tentative
    maxRetries = 2,          // nouvelles tentatives apres le 1er essai (erreurs transitoires uniquement)
    baseDelayMs = 2000,      // attente : 2 s, puis 4 s (+ petit aleatoire)
    fetchImpl = fetch,
    sleepImpl = defaultSleep,
  } = opts;
  if (!apiKey) throw new Error("GEMINI_API_KEY manquante");

  const attemptOnce = async () => {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      let res;
      try {
        res = await fetchImpl(
          `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: system }] },
              contents: [{ role: "user", parts: [{ text: user }] }],
              generationConfig: { temperature: 0.3, maxOutputTokens: 1500 },
            }),
            signal: ctrl.signal,
          }
        );
      } catch (e) {
        if (e && e.name === "AbortError") throw new Error(`Gemini timeout apres ${timeoutMs} ms`); // non retente
        const err = new Error(`Gemini reseau : ${e && e.message}`);
        err.retryable = true; // coupure reseau ponctuelle
        throw err;
      }
      if (!res.ok) {
        const detail = await errorDetail(res);
        const err = new Error(`Gemini HTTP ${res.status}${detail ? " - " + detail : ""}`);
        err.retryable = RETRY_STATUS.has(res.status);
        const ra = Number(res.headers && res.headers.get && res.headers.get("retry-after"));
        if (Number.isFinite(ra) && ra > 0) err.retryAfterMs = Math.min(ra * 1000, 30000);
        throw err;
      }
      const json = await res.json();
      const cand = json?.candidates?.[0];
      const parts = cand?.content?.parts || [];
      const text = parts.map((p) => p.text || "").join("").trim();
      if (!text) throw new Error(`Reponse Gemini vide (finishReason=${cand?.finishReason || json?.promptFeedback?.blockReason || "inconnu"})`);
      return text;
    } finally {
      clearTimeout(timer);
    }
  };

  for (let attempt = 0; ; attempt++) {
    try {
      return await attemptOnce();
    } catch (e) {
      if (!e.retryable || attempt >= maxRetries) throw e;
      const wait = e.retryAfterMs ?? Math.min(baseDelayMs * 2 ** attempt, 15000) + Math.floor(Math.random() * 500);
      console.warn(`[explain] ${e.message} - nouvelle tentative ${attempt + 1}/${maxRetries} dans ${wait} ms`);
      await sleepImpl(wait);
    }
  }
}

// Budget d'attente cote application : l'agriculteur ne doit pas attendre longtemps.
// Au-dela (surcharge, lenteur), on renvoie le texte de secours. Le banc d'evaluation garde ses valeurs longues.
const APP_GEMINI_OPTS = { timeoutMs: Number(process.env.EXPLAIN_TIMEOUT_MS) || 8000, maxRetries: 1, baseDelayMs: 1000 };

/**
 * Retourne toujours { texte, source: 'ia' | 'modele', avertissement }.
 * Si le LLM echoue ou sort un texte douteux, on renvoie le texte de secours.
 */
async function explain({ context, langue = "fr", allNames = [], gemini = callGemini }) {
  const lang = LANGS.includes(langue) ? langue : "fr";
  const avertissement = "Recommandation indicative. Consultez un technicien agricole avant plantation.";
  const fallback = () => ({ texte: fallbackExplanation(context, lang), source: "modele", avertissement });

  if (!context.varietes.length) return fallback();
  try {
    const text = await gemini(buildPrompt(context, lang), APP_GEMINI_OPTS);
    if (!checkExplanation(text, context, allNames)) {
      console.warn("[explain] sortie LLM rejetee par le controle");
      return fallback();
    }
    return { texte: text.trim(), source: "ia", avertissement };
  } catch (e) {
    console.warn("[explain] LLM indisponible :", e.message);
    return fallback();
  }
}

module.exports = { LANGS, buildContext, buildPrompt, fallbackExplanation, checkExplanation, callGemini, explain };