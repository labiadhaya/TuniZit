const supabase = require("../services/supabase");

// Verifie le JWT Supabase envoye par Flutter : Authorization: Bearer <token>
module.exports = async function auth(req, res, next) {
  const token = (req.headers.authorization || "").replace("Bearer ", "").trim();
  if (!token) {
    console.log("[auth] aucun token recu");
    return res.status(401).json({ error: "Non autorise" });
  }

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) {
    console.log("[auth] refuse :", error?.message || "utilisateur introuvable");
    return res.status(401).json({ error: "Non autorise" });
  }

  req.user = data.user;
  next();
};