// "Cette variete (importee ou non) convient-elle a ma situation ?"
const { evaluate, ND_MESSAGES } = require("./scoring");

const VERDICTS = {
  adaptee: "Adaptée à votre situation",
  adaptee_sous_conditions: "Adaptée sous conditions",
  donnees_insuffisantes: "Données insuffisantes : à confirmer avant de planter",
  deconseillee: "Déconseillée dans votre situation",
};

function evaluerAdaptation(v, input) {
  const e = evaluate(v, input);
  const conditions = [...e.conditions];
  if (e.exclusionsReco.includes("pluvial_import")) {
    conditions.unshift("Aucune donnée tunisienne en culture pluviale pour cette variété importée");
  }
  const zoneDocumentee = !!e.zone && (v.zones_adaptees || []).includes(e.zone);

  let verdict;
  if (e.bloquants.length) verdict = "deconseillee";
  else if (zoneDocumentee) verdict = conditions.length || e.attentions.length ? "adaptee_sous_conditions" : "adaptee";
  else verdict = "donnees_insuffisantes";

  return {
    id: v.id,
    variete: v.nom,
    origine: v.origine,
    pays_origine: v.pays_origine || null,
    verdict,
    verdict_libelle: VERDICTS[verdict],
    bloquants: e.bloquants,
    conditions,
    attentions: e.attentions,
    points_favorables: [...e.raisons, ...(v.points_forts || []).slice(0, 3)],
    limites: [...e.limites, ...(v.limites || [])],
    donnees_manquantes: e.nd.map((c) => ND_MESSAGES[c]).filter(Boolean),
    essais_tunisie: v.essais_tunisie || [],
    fiabilite: e.fiabilite,
    sources: v.sources || [],
    verified: !!v.verified,
    avertissement: "Évaluation indicative fondée sur des sources publiées. Consultez l'Institut de l'Olivier ou le CRDA avant de planter.",
  };
}

module.exports = { evaluerAdaptation, VERDICTS };