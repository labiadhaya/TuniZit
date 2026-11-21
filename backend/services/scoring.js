// Systeme expert v2 : s'appuie uniquement sur des donnees SOURCEES (data/varieties.js).
// Ce qui n'est pas documente donne un score neutre ET est signale ("non_documente").
// Poids : region 35 | eau 25 | salinite 15 | objectif 15 | systeme 10  (+ malus d'attention)
// Le sol n'influence pas encore le score : aucune donnee sourcee par variete.

const { zoneFor, ZONE_LABEL } = require("./zones");

const SAL_RANK = { faible: 1, moyenne: 2, elevee: 3 };

const ND_MESSAGES = {
  zone: "Aucune donnée sourcée sur l'adaptation de cette variété à votre région",
  secheresse: "Tolérance à la sécheresse non documentée",
  salinite: "Tolérance à la salinité non documentée",
  systeme: "Compatibilité avec ce système de culture non documentée",
  sol: "Adaptation de cette variété à votre type de sol non documentée",
};

function worstSalinity(input) {
  const vals = [input.salinite, input.salinite_eau].filter(Boolean);
  if (!vals.length) return null;
  return vals.sort((a, b) => SAL_RANK[b] - SAL_RANK[a])[0];
}

function riskApplies(quand, ctx) {
  return Object.entries(quand || {}).every(([k, allowed]) => allowed.includes(ctx[k]));
}

function evaluate(v, input) {
  const zone = zoneFor(input.gouvernorat);
  const sal = worstSalinity(input);
  const ctx = {
    zones: zone, gel: input.gel, eau: input.eau, salinite: sal,
    systeme: input.systeme, verticillium: input.verticillium,
  };
  const raisons = [], limites = [], conditions = [], attentions = [];
  const bloquants = [], exclusionsReco = [], nd = [];
  let score = 0;

  // --- Region (35) ---
  const zonesOk = v.zones_adaptees || [];
  if (!zone || !zonesOk.length) {
    score += 17; nd.push("zone");
  } else if (zonesOk.includes(zone)) {
    score += 35; raisons.push(`Cultivée et adaptée dans ${ZONE_LABEL[zone]}`);
  } else {
    score += 10;
    limites.push(`Documentée surtout pour ${zonesOk.map((z) => ZONE_LABEL[z]).join(" et ")}, pas pour ${ZONE_LABEL[zone]}`);
  }

  // --- Eau (25) ---
  const tolS = v.tolerance_secheresse;
  if (input.eau === "reguliere") {
    score += 25; raisons.push("Compatible avec l'irrigation régulière");
  } else if (input.eau === "appoint") {
    score += tolS === "elevee" ? 25 : tolS === "moyenne" ? 22 : tolS === "faible" ? 18 : 20;
    if (!tolS) nd.push("secheresse");
    raisons.push("Compatible avec l'irrigation d'appoint");
  } else {
    score += tolS === "elevee" ? 25 : tolS === "moyenne" ? 15 : tolS === "faible" ? 6 : 12;
    if (!tolS) nd.push("secheresse");
    if (tolS === "elevee") raisons.push("Tolérante à la sécheresse");
    if (tolS === "moyenne") limites.push("Tolérance moyenne à la sécheresse");
    if (tolS === "faible") limites.push("Sensible à la sécheresse");
  }
  if (input.eau === "pluvial" && v.besoin_irrigation === "recommandee") {
    score -= 8; conditions.push("Irrigation fortement conseillée pour cette variété");
  }
  if (input.eau === "pluvial" && v.origine === "importee") {
    exclusionsReco.push("pluvial_import");
  }
  if (v.besoin_irrigation === "obligatoire" && input.eau === "pluvial") {
    bloquants.push("Cette variété exige l'irrigation");
  }

  // --- Salinite (15) ---
  const tolSal = v.tolerance_salinite;
  if (!sal || sal === "faible") {
    score += 15;
  } else if (!tolSal) {
    score += 7; nd.push("salinite");
  } else if (tolSal === "elevee") {
    score += 15; raisons.push("Tolère la salinité");
  } else if (tolSal === "moyenne") {
    score += sal === "moyenne" ? 13 : 8;
    if (sal === "elevee") limites.push("Tolérance moyenne face à une salinité élevée");
  } else {
    score += sal === "moyenne" ? 6 : 0;
    limites.push("Peu tolérante au sel (sol ou eau)");
  }

  // --- Objectif (15) ---
  const usage = v.usage || [];
  if (input.objectif === "les_deux") {
    if (usage.includes("huile") && usage.includes("table")) {
      score += 15; raisons.push("Double usage : huile et olives de table");
    } else score += 8;
  } else if (input.objectif && usage.includes(input.objectif)) {
    score += 15;
    raisons.push(input.objectif === "huile" ? "Adaptée à la production d'huile" : "Adaptée aux olives de table");
  } else if (input.objectif) {
    score += 0;
  } else score += 8;

  // --- Systeme de culture (10) ---
  if (!input.systeme) score += 6;
  else if ((v.systemes_deconseilles || []).includes(input.systeme)) {
    bloquants.push("Variété trop vigoureuse pour ce système de culture : peu productive en essai à haute densité");
  } else if ((v.systemes || []).includes(input.systeme)) {
    score += 10; raisons.push("Documentée pour ce système de culture");
  } else { score += 5; nd.push("systeme"); }

  // --- Sol : non documente pour l'instant ---
  if ((v.sols_ok || []).length) {
    if (v.sols_ok.includes(input.sol)) raisons.push(`Adaptée au sol ${input.sol}`);
    else limites.push(`Sol ${input.sol} peu favorable`);
  } else nd.push("sol");

  // --- Risques documentes ---
  let malus = 0;
  for (const r of v.risques || []) {
    if (!riskApplies(r.quand, ctx)) continue;
    if (r.severite === "bloquant") bloquants.push(r.texte);
    else if (r.severite === "attention") { attentions.push(r.texte); malus += 5; }
    else conditions.push(r.texte);
  }
  score -= Math.min(malus, 15);

  // --- Verticillium (parcelle touchee) ---
  if (input.verticillium === "oui" && v.verticillium !== "tolerante") {
    bloquants.push(
      v.verticillium === "extreme" ? "Extrêmement sensible au Verticillium : à ne pas planter sur une parcelle touchée"
      : v.verticillium === "sensible" ? "Sensible au Verticillium : à ne pas planter sur une parcelle touchée"
      : "Résistance au Verticillium non documentée : à ne pas planter sur une parcelle touchée sans avis d'un technicien");
  }

  const fiabilite = nd.length <= 1 ? "bonne" : nd.length <= 3 ? "moyenne" : "faible";
  return {
    zone, score: Math.max(0, Math.min(100, score)),
    raisons, limites, conditions, attentions, bloquants, exclusionsReco, nd, fiabilite,
  };
}

const FIAB_RANK = { bonne: 0, moyenne: 1, faible: 2 };

function recommander(input, rows, { onlyVerified = false, limit = 5 } = {}) {
  return rows
    .filter((v) => v.statut_donnees && v.statut_donnees !== "a_documenter")
    .filter((v) => !onlyVerified || v.verified)
    .filter((v) => input.objectif === "les_deux" || (v.usage || []).includes(input.objectif))
    .map((v) => ({ v, e: evaluate(v, input) }))
    .filter(({ e }) => !e.bloquants.length && !e.exclusionsReco.length)
    .map(({ v, e }) => ({
      id: v.id,
      variete: v.nom,
      origine: v.origine,
      photo_url: v.photo_url || null,
      score: e.score,
      fiabilite: e.fiabilite,
      raisons: [...e.raisons, ...(v.points_forts || []).slice(0, 3)],
      limites: [...e.limites, ...e.attentions, ...(v.limites || [])],
      conditions: e.conditions,
      non_documente: e.nd.map((c) => ND_MESSAGES[c]).filter(Boolean),
      sources: v.sources || [],
      verified: !!v.verified,
    }))
    .sort((a, b) => b.score - a.score || FIAB_RANK[a.fiabilite] - FIAB_RANK[b.fiabilite] || a.variete.localeCompare(b.variete))
    .slice(0, limit);
}

// Avertissements valables pour toutes les varietes.
function avertissementsGeneraux(input) {
  const out = [];
  if (input.drainage === "mauvais") {
    out.push("Drainage mauvais : l'olivier supporte mal l'eau stagnante. Améliorez le drainage avant de planter (principe agronomique général, à valider par un technicien).");
  }
  if (input.eau === "pluvial" && typeof input.pluvio === "number" && input.pluvio < 200) {
    out.push("Moins de 200 mm de pluie par an : l'ONH ne donne aucune densité de référence sous ce seuil (17 à 20 arbres/ha pour 200-250 mm). La culture sans irrigation est très risquée.");
  }
  if (input.verticillium === "oui") {
    out.push("Parcelle touchée par le Verticillium : aucune variété de notre base n'est documentée comme tolérante. Consultez l'Institut de l'Olivier ou le CRDA avant de replanter.");
  }
  out.push("Les fiches sourcées ne précisent pas l'adaptation de chaque variété au type de sol : le sol n'influence pas encore le score.");
  return out;
}

module.exports = { evaluate, recommander, avertissementsGeneraux, ND_MESSAGES };