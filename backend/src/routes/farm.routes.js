// backend/src/farm.js : parcelles + demandes d'expert
const express = require("express");
const rateLimit = require("express-rate-limit");

const ID_RE = /^[0-9a-f-]{36}$/i;
const PHONE_RE = /^\+?[0-9 ()-]{8,20}$/;
const clean = (v, max) => (typeof v === "string" ? v.trim().slice(0, max) : "");

module.exports = function farmRoutes(supabase) {
  const router = express.Router();

  // Limite large : ces routes sont légères (le scan a sa propre limite stricte)
  const limiter = rateLimit({
    windowMs: 10 * 60 * 1000,
    limit: 120,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: "Trop de requêtes, réessayez dans quelques minutes." },
  });

  const fail = (res, status, error) => res.status(status).json({ error });
  const serverFail = (res, where, err) => {
    console.error(`${where}:`, err?.message || err);
    return fail(res, 500, "Erreur serveur, réessayez.");
  };

  // ── Liste des parcelles d'un utilisateur
  router.get("/parcels", limiter, async (req, res) => {
    try {
      const userId = clean(req.query.user_id, 64);
      if (!ID_RE.test(userId))
        return fail(res, 400, "Identifiant utilisateur invalide.");

      const { data, error } = await supabase
        .from("parcels")
        .select("id,name,location,variety,trees_count,created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) return serverFail(res, "GET /parcels", error);
      res.json({ parcels: data });
    } catch (e) {
      serverFail(res, "GET /parcels", e);
    }
  });

  // ── Création d'une parcelle
  router.post("/parcels", limiter, async (req, res) => {
    try {
      const userId = clean(req.body?.user_id, 64);
      const name = clean(req.body?.name, 80);
      if (!ID_RE.test(userId))
        return fail(res, 400, "Identifiant utilisateur invalide.");
      if (!name)
        return fail(res, 400, "Le nom de la parcelle est obligatoire.");

      let trees = req.body?.trees_count;
      trees =
        Number.isInteger(trees) && trees >= 0 && trees <= 100000 ? trees : null;

      const { data, error } = await supabase
        .from("parcels")
        .insert({
          user_id: userId,
          name,
          location: clean(req.body?.location, 120) || null,
          variety: clean(req.body?.variety, 60) || null,
          trees_count: trees,
        })
        .select("id,name,location,variety,trees_count,created_at")
        .single();
      if (error) return serverFail(res, "POST /parcels", error);
      res.status(201).json({ parcel: data });
    } catch (e) {
      serverFail(res, "POST /parcels", e);
    }
  });

  // ── Associer un scan à une parcelle
  router.patch("/scans/:id/parcel", limiter, async (req, res) => {
    try {
      const scanId = clean(req.params.id, 64);
      const userId = clean(req.body?.user_id, 64);
      const parcelId = clean(req.body?.parcel_id, 64);
      if (![scanId, userId, parcelId].every((v) => ID_RE.test(v))) {
        return fail(res, 400, "Paramètres invalides.");
      }

      // La parcelle doit appartenir à l'utilisateur
      const { data: parcel, error: pErr } = await supabase
        .from("parcels")
        .select("id,name")
        .eq("id", parcelId)
        .eq("user_id", userId)
        .maybeSingle();
      if (pErr) return serverFail(res, "PATCH parcel lookup", pErr);
      if (!parcel) return fail(res, 404, "Parcelle introuvable.");

      // Le scan aussi
      const { data: updated, error: uErr } = await supabase
        .from("scans")
        .update({ parcel_id: parcelId })
        .eq("id", scanId)
        .eq("user_id", userId)
        .select("id");
      if (uErr) return serverFail(res, "PATCH scan", uErr);
      if (!updated || updated.length === 0)
        return fail(res, 404, "Scan introuvable.");

      res.json({ ok: true, parcel });
    } catch (e) {
      serverFail(res, "PATCH /scans/:id/parcel", e);
    }
  });

  // ── Demande de contact d'un expert
  router.post("/expert-requests", limiter, async (req, res) => {
    try {
      const userId = clean(req.body?.user_id, 64);
      const scanId = clean(req.body?.scan_id, 64);
      const phone = clean(req.body?.phone, 20);
      const message = clean(req.body?.message, 500);

      if (!ID_RE.test(userId))
        return fail(res, 400, "Identifiant utilisateur invalide.");
      if (!PHONE_RE.test(phone))
        return fail(res, 400, "Numéro de téléphone invalide.");
      if (scanId && !ID_RE.test(scanId))
        return fail(res, 400, "Scan invalide.");

      const { error } = await supabase.from("expert_requests").insert({
        user_id: userId,
        scan_id: scanId || null,
        phone,
        message: message || null,
      });
      if (error) return serverFail(res, "POST /expert-requests", error);
      res.status(201).json({ ok: true });
    } catch (e) {
      serverFail(res, "POST /expert-requests", e);
    }
  });

  return router;
};
