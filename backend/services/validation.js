const SOLS = ["sableux", "limoneux", "argileux", "calcaire", "caillouteux"];
const DRAINAGES = ["bon", "moyen", "mauvais"];
const EAU = ["pluvial", "appoint", "reguliere"];
const OBJECTIFS = ["huile", "table", "les_deux"];
const SYSTEMES = ["traditionnel", "intensif", "super_intensif"];
const NIVEAUX = ["faible", "moyenne", "elevee"];
const GEL = ["aucun", "rare", "frequent"];
const PENTES = ["plat", "faible", "forte"];
const IRRIGATION_SYSTEMES = ["aucun", "goutte_a_goutte", "autre"];
const VERTICILLIUM = ["oui", "non", "inconnu"];

// Retourne la liste des erreurs (tableau vide = entree valide)
// mode "adaptation" : seuls gouvernorat et eau sont obligatoires.
function validateInput(b = {}, mode = "reco") {
  const full = mode !== "adaptation";
  const e = [];
  const oneOf = (val, list, name, required = false) => {
    if (val == null || val === "") {
      if (required) e.push(`${name} requis`);
      return;
    }
    if (!list.includes(val)) e.push(`${name} invalide`);
  };

  if (!b.gouvernorat || typeof b.gouvernorat !== "string") e.push("gouvernorat requis");
  oneOf(b.sol, SOLS, "sol", full);
  oneOf(b.drainage, DRAINAGES, "drainage", full);
  oneOf(b.eau, EAU, "eau", true);
  oneOf(b.objectif, OBJECTIFS, "objectif", full);
  oneOf(b.systeme, SYSTEMES, "systeme");
  oneOf(b.salinite, NIVEAUX, "salinite");
  oneOf(b.salinite_eau, NIVEAUX, "salinite_eau");
  oneOf(b.gel, GEL, "gel");
  oneOf(b.pente, PENTES, "pente");
  oneOf(b.irrigation_systeme, IRRIGATION_SYSTEMES, "irrigation_systeme");
  oneOf(b.verticillium, VERTICILLIUM, "verticillium");

  if (b.pluvio != null) {
    if (typeof b.pluvio !== "number" || b.pluvio < 0 || b.pluvio > 2000)
      e.push("pluvio doit etre un nombre entre 0 et 2000 (mm)");
  }

  // Coherence
  if (b.eau && b.eau !== "pluvial" && b.irrigation_systeme === "aucun")
    e.push("Irrigation selectionnee mais aucun systeme indique");
  if (b.systeme && b.systeme !== "traditionnel" && b.eau === "pluvial")
    e.push("Un systeme intensif necessite une irrigation");

  return e;
}

module.exports = { validateInput, SOLS, DRAINAGES, EAU, OBJECTIFS, SYSTEMES };