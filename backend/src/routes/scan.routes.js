// backend/src/routes/scan.routes.js
// Analyse d'une photo d'olivier avec Gemini : POST /api/scan
const express = require("express");
const multer = require("multer");
const rateLimit = require("express-rate-limit");
const { Type } = require("@google/genai");

const ai = require("../config/scanGemini");
const supabase = require("../config/supabaseAdmin");

// ───────────────────────── Config ─────────────────────────
const MODEL = process.env.SCAN_GEMINI_MODEL || "gemini-3.5-flash-lite";
// Modèles de secours (séparés par des virgules) si le principal est surchargé (503) ou introuvable (404)
const FALLBACK_MODELS = (process.env.SCAN_GEMINI_FALLBACK_MODELS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const MAX_FILE_MB = 5;
const GEMINI_TIMEOUT_MS = 45 * 1000; // délai max par appel Gemini
const GEMINI_TOTAL_MS = 100 * 1000; // délai max cumulé (l'app attend 120 s)
const GEMINI_RETRIES = 1; // réessais par modèle (500 / 503 / 504)

const router = express.Router();

// 15 analyses / 10 min / IP : protège la clé Gemini (uniquement sur /scan)
const scanLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 15,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Trop de requêtes, réessayez dans quelques minutes." },
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_FILE_MB * 1024 * 1024, files: 1 },
});

// ───────────────────────── Prompt système ─────────────────────────
const SYSTEM_PROMPT = `
# RÔLE
Tu es un ingénieur agronome et phytopathologiste senior, spécialiste de l'oléiculture méditerranéenne,
avec 20 ans d'expérience de terrain en Tunisie (Sfax, Sahel, Cap Bon, Tell, Kairouan, Sidi Bouzid, Zarzis).
Tu connais les cultivars locaux (Chemlali de Sfax, Chétoui, Zalmati, Zarrazi, Gerboui, Oueslati, Meski…)
et leurs sensibilités sanitaires. Tu analyses une photo envoyée par un agriculteur et tu produis un
diagnostic fiable, prudent et directement exploitable au verger.

# MÉTHODE (à suivre dans cet ordre)
1. VALIDITÉ : l'image montre-t-elle un olivier (feuille, fruit, rameau, tronc, fleur) ?
   Sinon : is_olive_plant=false, status="uncertain", et explique brièvement dans "advice".
2. QUALITÉ : évalue la netteté, la lumière, la distance, la partie visible.
   Si l'image est inexploitable (floue, trop sombre, trop lointaine), mets image_quality.usable=false,
   liste les problèmes et donne des conseils précis pour refaire la photo (ex. "photographier
   la face supérieure d'une feuille atteinte, à 15-20 cm, à la lumière du jour").
3. ORGANE : identifie la partie analysée (leaf, fruit, branch, trunk, flower, unknown).
4. OBSERVATION OBJECTIVE : décris d'abord ce que tu vois (forme, taille, couleur et position des taches,
   présence d'un halo, de galles, de dépôts, de pustules, de galeries, de trous, de cochenilles,
   répartition sur l'arbre…). N'écris AUCUN diagnostic dans "symptoms_observed".
5. DIAGNOSTIC DIFFÉRENTIEL : retiens jusqu'à 3 hypothèses classées par probabilité (la somme ≤ 1).
   Compare les signes discriminants avant de conclure.
6. CONFIANCE : calibre honnêtement "confidence" (0 à 1).
   - ≥ 0.85 : signes typiques et non ambigus.
   - 0.60-0.85 : signes compatibles, une alternative plausible subsiste.
   - < 0.60 : mets needs_expert=true et status="uncertain".
7. RECOMMANDATIONS : adaptées à la gravité, au contexte tunisien et à la lutte intégrée.

# CATALOGUE DES PROBLÈMES ET SIGNES DISCRIMINANTS
- Œil de paon (Spilocaea oleagina) : taches circulaires brun-noir de 2-10 mm sur la face supérieure des
  feuilles, avec halo jaune-vert, chute des feuilles de la base vers le haut. Favorisé par l'humidité hivernale/printanière.
- Verticilliose (Verticillium dahliae) : dessèchement brutal d'une ou plusieurs branches, feuilles qui
  restent attachées en séchant, brunissement des vaisseaux sous l'écorce. Aucun traitement curatif direct.
- Tuberculose / Broussin (Pseudomonas savastanoi pv. savastanoi) : excroissances rugueuses (galles, tumeurs)
  sur rameaux, branches, parfois feuilles. Propagation par plaies, grêle, taille, gaulage.
- Anthracnose (Colletotrichum acutatum / gloeosporioides) : fruits avec taches brunes déprimées, pustules
  orangées/rosées par temps humide, momification, chute ; parfois dessèchement de rameaux.
- Lèpre de l'olivier (Phlyctema vagans) : taches brunes à noirâtres sur fruits, souvent précoces avec l'humidité automnale.
- Fumagine (complexe de champignons saprophytes) : dépôt noir « suie » superficiel, essuyable, sur feuilles
  et fruits ; presque toujours liée à du miellat de cochenilles ou de psylles.
- Cochenille noire (Saissetia oleae) : carapaces brun-noir bombées avec un « H » sur le dos, sur rameaux et
  nervures, miellat collant, fumagine associée.
- Psylle de l'olivier (Euphyllura olivina) : amas cotonneux blancs sur inflorescences et jeunes pousses, miellat, coulure des fleurs.
- Mouche de l'olive (Bactrocera oleae) : piqûres de ponte (points sombres), galeries, trous de sortie
  ronds sur olives, chute anticipée, olives véreuses.
- Teigne de l'olivier (Prays oleae) : mines dans les feuilles, fleurs agglutinées/consommées, olives avec
  trou près du pédoncule et chute de juin ou d'automne.
- Carences nutritives : chlorose internervaire (fer, magnésium), nécrose du sommet des feuilles (potassium),
  jaunissement uniforme (azote), rosette/déformation des pousses (bore).
- Stress abiotiques : dessèchement des bords (sécheresse, salinité, vent chaud), brûlures solaires, dégâts de
  grêle ou de gel, phytotoxicité (herbicide, cuivre excessif), blessures mécaniques.
- Vigilance Xylella fastidiosa : un dessèchement foliaire généralisé « brûlé » avec rameaux entiers
  desséchés doit être signalé comme suspicion à faire confirmer par les services officiels,
  sans jamais affirmer le diagnostic à partir d'une photo.
- Saine (healthy) : feuillage vert, ferme, sans tache ni dépôt, fruits sans lésion.
- Si le problème ne correspond à rien de ce catalogue : disease_name_fr="Problème non identifié" et needs_expert=true.

# RÈGLES DE PRUDENCE (obligatoires)
- Ne diagnostique JAMAIS avec certitude ce qui n'est pas visible. Une photo ne remplace pas une analyse de laboratoire.
- Ne choisis pas la maladie « la plus connue » par défaut : appuie-toi uniquement sur les signes visibles.
- Si plusieurs problèmes sont présents (ex. cochenille + fumagine), cite le problème principal dans
  disease_name_fr et mentionne les autres dans differential et symptoms_observed.
- Produits phytosanitaires : cite uniquement des familles ou matières actives courantes (ex. produits à base
  de cuivre, huile blanche/huile de paraffine, spinosad, deltaméthrine, etc.). Ne donne AUCUNE dose chiffrée :
  précise de suivre l'étiquette, la réglementation tunisienne, le délai avant récolte (DAR) et les équipements
  de protection. Propose toujours en premier les mesures culturales et biologiques.
- Suspicion de Verticilliose, de Xylella ou d'un foyer étendu : recommande de contacter le CRDA / les services
  de protection des végétaux et d'isoler/éliminer le matériel atteint selon leurs consignes.
- N'invente jamais de variété, de statistique, de source ni de produit commercial.

# CONTEXTE TUNISIEN À PRENDRE EN COMPTE
- Hivers humides (Nord, Tell, Cap Bon) : risque accru d'œil de paon, anthracnose, lèpre.
- Sud et Centre (Sfax, Zarzis, Gabès) : stress hydrique, salinité, carences, cochenilles, mouche en fin d'été.
- Calendrier : traitements cuivre post-récolte et avant les pluies d'automne ; piégeage de la mouche dès l'été ;
  taille d'aération pour réduire l'humidité de la canopée.
- Sensibilités connues : Chétoui sensible à l'œil de paon ; Chemlali plus rustique mais sensible à l'œil de paon
  en hiver humide ; Zalmati sensible aux attaques de mouche.

# LANGUE ET STYLE
- Écris tous les champs textuels dans la langue demandée par l'utilisateur (indiquée dans le message ; par défaut le français).
- Si la langue est "ar", utilise un arabe simple et clair ; si "darija", un tunisien compréhensible écrit en lettres arabes.
- "disease_name_fr" est toujours en français et "disease_name_ar" toujours en arabe (nom courant tunisien si connu).
- Phrases courtes, concrètes, sans jargon inutile. Chaque action doit être réalisable par un agriculteur.
- Réponds UNIQUEMENT avec le JSON conforme au schéma, sans texte autour ni markdown.

# CHAMPS ATTENDUS
- severity : low (< 10 % des organes atteints), medium (10-30 %), high (> 30 % ou risque pour l'arbre) ; null si sain.
- urgency : none, monitor (surveiller 7-15 jours), treat_soon (sous 1-2 semaines), treat_now (immédiat).
- spread_risk : probabilité de propagation à d'autres arbres (low, medium, high) et conditions favorisantes dans "risk_factors".
- treatment.immediate_actions : gestes à faire dès maintenant (taille sanitaire, ramassage des feuilles/fruits tombés, désinfection des outils…).
- treatment.organic : solutions de lutte biologique ou à faible impact.
- treatment.chemical : familles/matières actives possibles, avec rappel d'étiquette.
- treatment.timing : meilleure période d'intervention.
- prevention : mesures à moyen terme (taille, drainage, fertilisation équilibrée, piégeage, choix variétal).
- follow_up : ce qu'il faut observer et quand reprendre une photo.
- advice : synthèse de 2 à 4 phrases pour l'agriculteur.
`;

// ───────────────────────── Schéma de sortie ─────────────────────────
const str = (extra = {}) => ({ type: Type.STRING, ...extra });
const strNullable = () => ({ type: Type.STRING, nullable: true });
const strArr = () => ({ type: Type.ARRAY, items: { type: Type.STRING } });
const enumStr = (values, nullable = false) => ({
  type: Type.STRING,
  format: "enum",
  enum: values,
  nullable,
});

const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    is_olive_plant: { type: Type.BOOLEAN },
    image_quality: {
      type: Type.OBJECT,
      properties: {
        usable: { type: Type.BOOLEAN },
        issues: strArr(),
        retake_tips: strArr(),
      },
      required: ["usable", "issues", "retake_tips"],
    },
    part_analyzed: enumStr([
      "leaf",
      "fruit",
      "branch",
      "trunk",
      "flower",
      "unknown",
    ]),
    status: enumStr(["healthy", "diseased", "uncertain"]),
    disease_name_fr: strNullable(),
    disease_name_ar: strNullable(),
    pathogen_scientific: strNullable(),
    category: enumStr([
      "fungal",
      "bacterial",
      "pest",
      "nutritional",
      "abiotic",
      "mixed",
      "none",
    ]),
    confidence: { type: Type.NUMBER },
    differential: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          name_fr: str(),
          name_ar: strNullable(),
          probability: { type: Type.NUMBER },
        },
        required: ["name_fr", "probability"],
      },
    },
    symptoms_observed: strArr(),
    severity: enumStr(["low", "medium", "high"], true),
    urgency: enumStr(["none", "monitor", "treat_soon", "treat_now"]),
    spread_risk: enumStr(["low", "medium", "high"]),
    risk_factors: strArr(),
    treatment: {
      type: Type.OBJECT,
      properties: {
        immediate_actions: strArr(),
        organic: strArr(),
        chemical: strArr(),
        timing: strNullable(),
      },
      required: ["immediate_actions", "organic", "chemical"],
    },
    prevention: strArr(),
    follow_up: strArr(),
    needs_expert: { type: Type.BOOLEAN },
    expert_reason: strNullable(),
    advice: str(),
  },
  required: [
    "is_olive_plant",
    "image_quality",
    "part_analyzed",
    "status",
    "category",
    "confidence",
    "differential",
    "symptoms_observed",
    "urgency",
    "treatment",
    "prevention",
    "needs_expert",
    "advice",
  ],
};

// ───────────────────────── Helpers ─────────────────────────
/** Détecte le vrai type d'image via les "magic bytes" (ne fait pas confiance au mimetype). */
function sniffImageType(buf) {
  if (!buf || buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff)
    return "image/jpeg";
  if (
    buf
      .slice(0, 8)
      .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  )
    return "image/png";
  if (
    buf.slice(0, 4).toString() === "RIFF" &&
    buf.slice(8, 12).toString() === "WEBP"
  )
    return "image/webp";
  return null;
}

const LANG_LABEL = {
  fr: "français",
  ar: "arabe (ar)",
  darija: "darija tunisienne écrite en lettres arabes (darija)",
};

const clamp01 = (n) => Math.min(1, Math.max(0, Number(n) || 0));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Rejette la promesse si elle dépasse `ms` millisecondes. */
function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => {
      const err = new Error(
        `${label} : délai dépassé (${Math.round(ms / 1000)} s)`,
      );
      err.status = 504;
      reject(err);
    }, ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

/**
 * Appelle Gemini : modèle principal, puis modèles de secours.
 * - 500 / 503 / 504 : réessai sur le même modèle, puis modèle suivant.
 * - 404 / 429 / autres : on passe directement au modèle suivant.
 * Un délai global évite de dépasser l'attente de l'app (120 s).
 */
async function callGemini(params) {
  const models = [
    params.model,
    ...FALLBACK_MODELS.filter((m) => m !== params.model),
  ];
  const deadline = Date.now() + GEMINI_TOTAL_MS;
  let lastErr;

  for (const model of models) {
    for (let attempt = 0; attempt <= GEMINI_RETRIES; attempt++) {
      const remaining = deadline - Date.now();
      if (remaining < 3000) {
        if (!lastErr) {
          lastErr = new Error("Gemini : délai global dépassé");
          lastErr.status = 504;
        }
        throw lastErr;
      }
      try {
        const res = await withTimeout(
          ai.models.generateContent({ ...params, model }),
          Math.min(GEMINI_TIMEOUT_MS, remaining),
          "Gemini",
        );
        res._modelUsed = model;
        return res;
      } catch (e) {
        lastErr = e;
        console.error(
          `>>> ${model} tentative ${attempt + 1} échouée:`,
          e.status,
          String(e.message).slice(0, 160),
        );
        const retrySame = [500, 503, 504].includes(e.status);
        if (!retrySame || attempt === GEMINI_RETRIES) break;
        await sleep(1500 * (attempt + 1));
      }
    }
  }
  throw lastErr;
}

/** Nettoie et verrouille la cohérence du résultat renvoyé par le modèle. */
function normalizeResult(raw) {
  const r = { ...raw };
  r.confidence = clamp01(r.confidence);
  r.differential = (r.differential || [])
    .map((d) => ({ ...d, probability: clamp01(d.probability) }))
    .sort((a, b) => b.probability - a.probability)
    .slice(0, 3);

  if (!r.is_olive_plant) {
    r.status = "uncertain";
    r.needs_expert = false;
  } else if (r.confidence < 0.6 || r.status === "uncertain") {
    r.status = "uncertain";
    r.needs_expert = true;
  }
  if (r.image_quality && r.image_quality.usable === false) {
    r.status = "uncertain";
  }
  if (r.status === "healthy") {
    r.severity = null;
    r.urgency = "none";
  }
  return r;
}

// ───────────────────────── Route ─────────────────────────
router.post("/scan", scanLimiter, upload.single("image"), async (req, res) => {
  const t0 = Date.now();
  console.log(">>> Scan reçu", new Date().toISOString());

  try {
    if (!req.file)
      return res.status(400).json({ error: "Aucune image reçue." });

    const mediaType = sniffImageType(req.file.buffer);
    if (!mediaType) {
      return res
        .status(415)
        .json({ error: "Format non supporté (JPEG, PNG ou WebP)." });
    }

    const lang = ["fr", "ar", "darija"].includes(req.body.lang)
      ? req.body.lang
      : "fr";
    const userId = req.body.user_id || null;
    const base64 = req.file.buffer.toString("base64");
    console.log(
      ">>> Image",
      mediaType,
      Math.round(req.file.size / 1024),
      "KB | lang:",
      lang,
    );

    // 1. Analyse Gemini
    const response = await callGemini({
      model: MODEL,
      contents: [
        {
          role: "user",
          parts: [
            { inlineData: { mimeType: mediaType, data: base64 } },
            {
              text:
                `Langue de réponse : ${LANG_LABEL[lang]}.\n` +
                `Analyse cette photo d'olivier en suivant ta méthode (validité, qualité, organe, ` +
                `observation objective, diagnostic différentiel, confiance, recommandations) ` +
                `et renvoie uniquement le JSON demandé.`,
            },
          ],
        },
      ],
      config: {
        systemInstruction: SYSTEM_PROMPT,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
        // Gemini 3.x : thinkingLevel (MINIMAL | LOW | MEDIUM | HIGH), température par défaut recommandée.
        // Si le diagnostic manque de précision, essaie 'MEDIUM'.
        thinkingConfig: { thinkingLevel: "MINIMAL" },
      },
    });

    const modelUsed = response._modelUsed || MODEL;

    let parsed;
    try {
      parsed = JSON.parse(
        String(response.text || "")
          .replace(/```json|```/g, "")
          .trim(),
      );
    } catch (_) {
      console.error(
        ">>> JSON invalide reçu de Gemini:",
        String(response.text).slice(0, 300),
      );
      return res.status(502).json({ error: "Réponse IA invalide, réessayez." });
    }
    const result = normalizeResult(parsed);
    console.log(
      ">>> Gemini OK:",
      modelUsed,
      "|",
      result.disease_name_fr,
      result.confidence,
      `(${((Date.now() - t0) / 1000).toFixed(1)} s)`,
    );

    // 2. Upload dans Supabase Storage
    const ext =
      mediaType === "image/png"
        ? "png"
        : mediaType === "image/webp"
          ? "webp"
          : "jpg";
    const fileName = `${userId || "anon"}/${Date.now()}.${ext}`;

    const { error: upErr } = await supabase.storage
      .from("scans")
      .upload(fileName, req.file.buffer, { contentType: mediaType });
    if (upErr) console.error("Storage error:", upErr.message);

    const { data: pub } = supabase.storage.from("scans").getPublicUrl(fileName);
    const imageUrl = upErr ? null : pub.publicUrl;

    // 3. Sauvegarde en base
    const { data: row, error: dbErr } = await supabase
      .from("scans")
      .insert({
        user_id: userId,
        image_url: imageUrl,
        result,
        disease: result.disease_name_fr,
        confidence: result.confidence,
        severity: result.severity,
        part: result.part_analyzed,
      })
      .select("id")
      .single();
    if (dbErr) console.error("DB error:", dbErr.message);

    const scanId = row?.id
      ? `TZ-${String(row.id).replace(/-/g, "").slice(0, 4).toUpperCase()}`
      : null;

    console.log(
      ">>> Réponse envoyée",
      scanId,
      `(${((Date.now() - t0) / 1000).toFixed(1)} s total)`,
    );
    res.json({
      ...result,
      image_url: imageUrl,
      scan_id: scanId,
      model: modelUsed,
    });
  } catch (e) {
    console.error("ERREUR SCAN:", e.status, e.message);
    const busy = [429, 503, 504].includes(e.status);
    res.status(busy ? 503 : 500).json({
      error: busy
        ? "Le service d’analyse est surchargé, réessayez dans un instant."
        : "Analyse impossible pour le moment.",
      detail: e.message,
    });
  }
});

// Gestion propre des erreurs multer (fichier trop gros…)
router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    const msg =
      err.code === "LIMIT_FILE_SIZE"
        ? `Image trop lourde (max ${MAX_FILE_MB} Mo).`
        : "Erreur lors de l’envoi de l’image.";
    return res.status(400).json({ error: msg });
  }
  next(err);
});

module.exports = router;
