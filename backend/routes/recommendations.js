const express = require("express");
const supabase = require("../services/supabase");
const auth = require("../middleware/auth");
const { validateInput } = require("../services/validation");
const { recommander, avertissementsGeneraux } = require("../services/scoring");
const { evaluerAdaptation } = require("../services/adaptation");
const { LANGS, buildContext, explain } = require("../services/explain");
const rateLimit = require("express-rate-limit");

// 10 explications IA par minute et par utilisateur (protege le quota Gemini)
const explainLimiter = rateLimit({
  windowMs: 60_000,
  max: 10,
  keyGenerator: (req) => req.user.id,
  standardHeaders: true,
  legacyHeaders: false,
});
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const router = express.Router();
const ONLY_VERIFIED = process.env.ONLY_VERIFIED === "true";

// POST /api/recommendations/varieties
router.post("/varieties", auth, async (req, res) => {
  try {
    const input = { ...req.body };
    const errors = validateInput(input);
    if (errors.length) return res.status(400).json({ errors });

    // Valeurs par defaut depuis le gouvernorat
    const defaultsUsed = [];
    if (input.pluvio == null || !input.gel) {
      const { data: clim } = await supabase
        .from("governorate_climate")
        .select("*")
        .eq("gouvernorat", input.gouvernorat)
        .maybeSingle();
      if (input.pluvio == null && clim?.pluvio_moyenne_mm != null) {
        input.pluvio = clim.pluvio_moyenne_mm;
        defaultsUsed.push("pluviometrie");
      }
      if (!input.gel && clim?.risque_gel) {
        input.gel = clim.risque_gel;
        defaultsUsed.push("risque_gel");
      }
    }
    if (input.pluvio == null) {
      return res.status(400).json({ errors: ["pluviometrie requise (gouvernorat sans donnees climatiques)"] });
    }

    const { data: rows, error } = await supabase.from("olive_varieties").select("*");
    if (error) return res.status(500).json({ error: "Erreur base de donnees" });

    const resultats = recommander(input, rows, { onlyVerified: ONLY_VERIFIED });

    const { data: saved } = await supabase
      .from("recommendation_requests")
      .insert({
        user_id: req.user.id,
        parcel_id: input.parcel_id || null,
        input,
        results: resultats,
      })
      .select("id")
      .single();

    res.json({
      request_id: saved?.id ?? null,
      resultats,
      valeurs_par_defaut: defaultsUsed,
      avertissements: avertissementsGeneraux(input),
      message: resultats.length
        ? null
        : input.verticillium === "oui"
          ? "Parcelle touchée par le Verticillium : aucune variété de notre base n'est documentée comme tolérante. Consultez l'Institut de l'Olivier ou le CRDA."
          : "Conditions très contraignantes : consultez un technicien agricole.",
      avertissement: "Recommandation indicative. Consultez un technicien agricole avant plantation.",
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/recommendations/history  (uniquement l'utilisateur connecte)
router.get("/history", auth, async (req, res) => {
  const { data, error } = await supabase
    .from("recommendation_requests")
    .select("id, parcel_id, input, results, created_at")
    .eq("user_id", req.user.id)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) return res.status(500).json({ error: "Erreur base de donnees" });
  res.json({ historique: data });
});

// GET /api/recommendations/compare?ids=chemlali,chetoui
router.get("/compare", auth, async (req, res) => {
  const ids = String(req.query.ids || "").split(",").filter(Boolean).slice(0, 3);
  if (ids.length < 2) return res.status(400).json({ errors: ["Selectionnez 2 a 3 varietes"] });
  const { data, error } = await supabase.from("olive_varieties").select("*").in("id", ids);
  if (error) return res.status(500).json({ error: "Erreur base de donnees" });
  res.json({ varietes: data });
});

// POST /api/recommendations/explain  { request_id, langue: "fr" | "ar" | "ar_tn" }
// Le LLM explique un resultat DEJA enregistre : le client ne peut pas lui envoyer de faux resultats.
router.post("/explain", auth, explainLimiter, async (req, res) => {
  try {
    const { request_id } = req.body || {};
    const langue = LANGS.includes(req.body?.langue) ? req.body.langue : "fr";
    if (typeof request_id !== "string" || !UUID.test(request_id)) {
      return res.status(400).json({ errors: ["request_id invalide"] });
    }

    const { data: row, error } = await supabase
      .from("recommendation_requests")
      .select("id, input, results, explanations")
      .eq("id", request_id)
      .eq("user_id", req.user.id)
      .maybeSingle();
    if (error) return res.status(500).json({ error: "Erreur base de donnees" });
    if (!row) return res.status(404).json({ error: "Recommandation introuvable" });

    const cached = row.explanations?.[langue];
    if (cached) return res.json({ ...cached, en_cache: true });

    const { data: all } = await supabase.from("olive_varieties").select("nom");
    const out = await explain({
      context: buildContext(row.input, row.results),
      langue,
      allNames: (all || []).map((x) => x.nom),
    });

    if (out.source === "ia") {
      await supabase
        .from("recommendation_requests")
        .update({ explanations: { ...(row.explanations || {}), [langue]: out } })
        .eq("id", request_id)
        .eq("user_id", req.user.id);
    }
    res.json(out);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

// GET /api/recommendations/catalogue : liste des varietes (pour choisir une variete a verifier)
router.get("/catalogue", auth, async (req, res) => {
  const { data, error } = await supabase
    .from("olive_varieties")
    .select("id, nom, origine, pays_origine, usage, statut_donnees")
    .neq("statut_donnees", "a_documenter")
    .order("nom");
  if (error) return res.status(500).json({ error: "Erreur base de donnees" });
  res.json({ varietes: data });
});

// POST /api/recommendations/adaptation  { variete_id, gouvernorat, eau, ... }
router.post("/adaptation", auth, async (req, res) => {
  try {
    const input = { ...(req.body || {}) };
    const errors = validateInput(input, "adaptation");
    if (typeof input.variete_id !== "string" || !input.variete_id) errors.push("variete_id requis");
    if (errors.length) return res.status(400).json({ errors });

    const { data: v, error } = await supabase
      .from("olive_varieties").select("*").eq("id", input.variete_id).maybeSingle();
    if (error) return res.status(500).json({ error: "Erreur base de donnees" });
    if (!v) return res.status(404).json({ error: "Variete introuvable" });

    res.json(evaluerAdaptation(v, input));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Erreur serveur" });
  }
});

module.exports = router;