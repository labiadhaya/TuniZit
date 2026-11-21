// Base de varietes SOURCEE. Chaque affirmation vient d'une source listee ; ce qui n'est pas
// documente reste null / vide et le moteur le signale ("non documente").
// verified:false tant qu'un expert (Institut de l'Olivier, ONH, CRDA) n'a pas relu la fiche.

const S = {
  COI_CHEMLALI: { titre: "Chemlali Sfax - Catalogue mondial des variétés d'olivier", organisme: "Conseil oléicole international", url: "https://worldolivecatalogue.internationaloliveoil.org/en/variety/tunisia/chemlali-sfax" },
  COI_CHETOUI: { titre: "Chetoui - Catalogue mondial des variétés d'olivier", organisme: "Conseil oléicole international", url: "https://worldolivecatalogue.internationaloliveoil.org/en/variety/tunisia/chetoui" },
  COI_OUESLATI: { titre: "Oueslati - Catalogue mondial des variétés d'olivier", organisme: "Conseil oléicole international", url: "https://worldolivecatalogue.internationaloliveoil.org/en/variety/tunisia/oueslati" },
  COI_RECHERCHE: { titre: "Catalogue mondial des variétés d'olivier (fiche Meski)", organisme: "Conseil oléicole international", url: "https://worldolivecatalogue.internationaloliveoil.org/en/search" },
  ONH_COI: { titre: "Policies - Tunisia 2012 (classification ONH des variétés)", organisme: "COI / ONH", url: "https://www.internationaloliveoil.org/wp-content/uploads/2019/11/ENGLISH_POLICY_TUNISIA-2012_OK.pdf" },
  LARBI: { titre: "Olive cultivars suitability for high-density orchards (essai de Takelsa, Tunisie)", organisme: "Institut de l'Olivier / Spanish J. Agric. Res., 2011", url: "https://sjar.revistas.csic.es/index.php/sjar/article/view/1490" },
  SHD: { titre: "Cultivar and tree density in super high-density olive orchards", organisme: "Frontiers in Plant Science, 2016", url: "https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2016.01226/full" },
  MHASSEN: { titre: "Chemlali Mhassen : nouvelle variété issue du programme tunisien d'amélioration", organisme: "Institut de l'Olivier (Sfax)", url: "https://core.ac.uk/download/478788967.pdf" },
  ENNOUR: { titre: "Early evaluation of salt-stress tolerance of new released olive cultivars (Zeitoun Ennour, Ennwader)", organisme: "J. Agriculture and Food Research, 2024", url: "https://doaj.org/article/5d4eeb50b3234eb3807c8855b30ad463" },
  SEL_KORONEIKI: { titre: "Physiological responses of two olive cultivars to salt stress (Chemlali, Koroneiki)", organisme: "Plants, 2023", url: "https://doi.org/10.3390/plants12101926" },
  FROID_USA: { titre: "Adaptation of olive trees in the humid subtropical climate of the southeastern USA", organisme: "HortScience, 2025", url: "https://journals.ashs.org/downloadpdf/view/journals/hortsci/60/8/article-p1379.pdf" },
  HIVER_DOUX: { titre: "Flowering phenology of olive cultivars under high winter temperatures", organisme: "Preprints, 2023", url: "https://www.preprints.org/manuscript/202306.0156" },
  CHALEUR: { titre: "Olive adaptation to warm, arid regions : chilling requirements and high temperatures", organisme: "Frontiers in Plant Science, 2017", url: "https://www.frontiersin.org/articles/10.3389/fpls.2017.01830" },
};

const base = {
  irrigation: [], sols_ok: [], regions_connues: [], tolerance_froid: null,
  pluvio_min_mm: null, pluvio_optimale_min: null, pluvio_optimale_max: null,
  drainage_min: null, photo_url: null, verified: false,
  zones_adaptees: [], systemes_deconseilles: [], risques: [], essais_tunisie: [],
  points_forts: [], limites: [], besoin_irrigation: null, vigueur: null, alternance: null,
  auto_compatible: null, verticillium: "non_documente",
  tolerance_secheresse: null, tolerance_salinite: null, systemes: [],
};

const V = (o) => ({ ...base, ...o });

const ZONE_NON_TESTEE = {
  code: "zone_non_testee", severite: "info", quand: { zones: ["centre", "sud"] },
  texte: "Aucun essai documenté dans notre base en dehors du nord : consultez l'Institut de l'Olivier avant de planter à grande échelle.",
  source: S.LARBI.url,
};
const EAU_SOIN = {
  code: "eau_engrais", severite: "info", quand: {},
  texte: "La réussite d'un verger à haute densité dépend d'une gestion soignée de l'eau et des engrais : prévoir l'irrigation.",
  source: S.SHD.url,
};
const INVEST = {
  code: "investissement", severite: "info", quand: {},
  texte: "Investissement élevé : environ 6000 €/ha en Tunisie selon une estimation de 2011.",
  source: S.LARBI.url,
};

module.exports = [
  V({
    id: "chemlali", nom: "Chemlali (Sfax)", origine: "locale", pays_origine: "Tunisie",
    statut_donnees: "documente", usage: ["huile"],
    zones_adaptees: ["centre", "sud"],
    tolerance_secheresse: "elevee", tolerance_salinite: "moyenne",
    systemes: ["traditionnel", "intensif"], systemes_deconseilles: ["super_intensif"],
    besoin_irrigation: "non_requise", vigueur: "forte", auto_compatible: true, verticillium: "extreme",
    points_forts: [
      "Variété principale du centre et du sud de la Tunisie",
      "Bien adaptée aux conditions arides et salines",
      "Tolérante à la sécheresse",
      "Adaptée à plusieurs modes de culture, en pluvial comme en irrigué",
    ],
    limites: [
      "Très sensible au Verticillium (maladie du sol qui fait dépérir l'arbre)",
      "Sensible à la mouche de l'olive et très sensible au psylle",
      "Huile pauvre en acide oléique (environ 55 %) et riche en acide palmitique",
      "Qualité de l'huile dégradée en climat saharien (chaleur, forte lumière, peu de pluie)",
    ],
    sources: [S.COI_CHEMLALI, S.LARBI, S.ONH_COI],
  }),
  V({
    id: "chetoui", nom: "Chétoui", origine: "locale", pays_origine: "Tunisie",
    statut_donnees: "documente", usage: ["huile"],
    zones_adaptees: ["nord"],
    tolerance_secheresse: "moyenne", tolerance_salinite: "moyenne",
    systemes: ["traditionnel", "intensif"], systemes_deconseilles: ["super_intensif"],
    vigueur: "faible", alternance: "forte", auto_compatible: true, verticillium: "extreme",
    risques: [{
      code: "centre_sud", severite: "bloquant", quand: { zones: ["centre", "sud"] },
      texte: "Faible productivité documentée dans le centre et le sud : variété adaptée aux régions à hiver froid.",
      source: S.COI_CHETOUI.url,
    }],
    points_forts: [
      "Deuxième variété à huile de Tunisie, cultivée surtout dans le nord",
      "Adaptée aux régions à hiver froid",
      "Huile riche en acide oléique (63 à 70 %)",
      "Résistante à l'acarien de l'olivier",
    ],
    limites: [
      "Qualité de l'huile dégradée en climat saharien",
      "Extrêmement sensible au Verticillium",
      "Alternance de production forte et vigueur faible",
      "Sensibilité modérée à la sécheresse et à la salinité",
    ],
    sources: [S.COI_CHETOUI, S.LARBI],
  }),
  V({
    id: "oueslati", nom: "Oueslati", origine: "locale", pays_origine: "Tunisie",
    statut_donnees: "documente", usage: ["huile"],
    zones_adaptees: ["centre", "nord"],
    tolerance_secheresse: "moyenne", tolerance_salinite: "moyenne",
    systemes: ["traditionnel"], vigueur: "faible", alternance: "forte",
    auto_compatible: true, verticillium: "sensible",
    points_forts: [
      "Originaire de Kairouan, cultivée surtout à Kairouan et à Siliana",
      "Très demandée aujourd'hui pour la qualité de son huile",
      "Comportement modéré face à la sécheresse et à la salinité",
    ],
    limites: [
      "Sensible au Verticillium",
      "Alternance de production forte, productivité moyenne",
      "Multiplication difficile par boutures",
    ],
    sources: [S.COI_OUESLATI, S.ONH_COI],
  }),
  V({
    id: "zarrazi", nom: "Zarrazi", origine: "locale", pays_origine: "Tunisie",
    statut_donnees: "partiel", usage: ["huile", "table"],
    zones_adaptees: ["sud"], alternance: "forte",
    points_forts: [
      "Cultivée dans le sud, surtout dans les oasis",
      "Très bonnes olives de table et teneur élevée en huile",
    ],
    limites: [
      "Production irrégulière (alternance)",
      "Fiche incomplète : tolérances et maladies non documentées dans notre base",
    ],
    sources: [S.ONH_COI],
  }),
  V({
    id: "meski", nom: "Meski", origine: "locale", pays_origine: "Tunisie",
    statut_donnees: "partiel", usage: ["table"],
    zones_adaptees: ["nord"], besoin_irrigation: "recommandee",
    risques: [{
      code: "hors_nord", severite: "info", quand: { zones: ["centre", "sud"] },
      texte: "En dehors du nord, la variété est cultivée dans des zones irriguées : prévoir l'irrigation.",
      source: S.COI_RECHERCHE.url,
    }],
    points_forts: [
      "Variété d'olive de table originaire de la Manouba",
      "Cultivée surtout dans le nord et dans les zones irriguées d'olives de table",
    ],
    limites: ["Fiche incomplète : tolérances et maladies non documentées dans notre base"],
    sources: [S.COI_RECHERCHE, S.ONH_COI],
  }),
  V({
    id: "chemlali_mhassen", nom: "Chemlali Mhassen", origine: "creation_tunisienne", pays_origine: "Tunisie",
    statut_donnees: "partiel", usage: ["huile"],
    alternance: "moyenne",
    points_forts: [
      "Issue du programme tunisien d'amélioration de Chemlali Sfax",
      "Huile de meilleure qualité et bonne productivité selon ses obtenteurs",
      "Entrée en production vers 4 ans, maturité précoce",
    ],
    limites: [
      "Variété récente : peu de recul en conditions réelles",
      "Adaptation par région non documentée dans notre base",
    ],
    sources: [S.MHASSEN],
  }),
  V({
    id: "zeitoun_ennour", nom: "Zeitoun Ennour", origine: "creation_tunisienne", pays_origine: "Tunisie",
    statut_donnees: "partiel", usage: ["huile"], tolerance_salinite: "elevee",
    points_forts: [
      "Nouvelle variété issue du programme tunisien d'amélioration",
      "Parmi les génotypes testés, la plus tolérante au sel (essai précoce)",
    ],
    limites: ["Évaluation précoce en pot : à confirmer au champ", "Adaptation par région non documentée"],
    sources: [S.ENNOUR],
  }),
  V({
    id: "zeitoun_ennwader", nom: "Zeitoun Ennwader", origine: "creation_tunisienne", pays_origine: "Tunisie",
    statut_donnees: "partiel", usage: ["huile"], tolerance_salinite: "moyenne",
    points_forts: [
      "Nouvelle variété issue du programme tunisien d'amélioration",
      "Tolérance au sel comparable à celle de Chemlali Sfax (essai précoce)",
    ],
    limites: ["Évaluation précoce en pot : à confirmer au champ", "Adaptation par région non documentée"],
    sources: [S.ENNOUR],
  }),
  V({
    id: "arbequina", nom: "Arbequina", origine: "importee", pays_origine: "Espagne",
    statut_donnees: "partiel", usage: ["huile"], zones_adaptees: ["nord"],
    systemes: ["super_intensif"], besoin_irrigation: "recommandee", vigueur: "faible",
    essais_tunisie: [{
      lieu: "Takelsa (nord)", annee_plantation: 2003, densite: "1250 arbres/ha",
      resultat: "Rendement en fruits élevé et faible alternance (indice 0,44) pour Arbequina i-18",
      source: S.LARBI.url,
    }],
    risques: [EAU_SOIN, INVEST, ZONE_NON_TESTEE, {
      code: "hiver_doux", severite: "attention", quand: { gel: ["aucun"] },
      texte: "Floraison désynchronisée observée quand le froid hivernal est insuffisant (essai en climat subtropical) : à surveiller si les hivers sont très doux.",
      source: S.HIVER_DOUX.url,
    }],
    points_forts: [
      "Variété la plus utilisée dans le monde pour les vergers super-intensifs",
      "Faible vigueur, production élevée et régulière, huile fruitée",
      "Introduite en Tunisie dès 2000 pour les plantations à haute densité",
    ],
    limites: ["Verger à haute densité : conduite et récolte spécialisées"],
    sources: [S.LARBI, S.SHD, S.HIVER_DOUX],
  }),
  V({
    id: "arbosana", nom: "Arbosana", origine: "importee", pays_origine: "Espagne",
    statut_donnees: "partiel", usage: ["huile"], zones_adaptees: ["nord"],
    systemes: ["super_intensif"], besoin_irrigation: "recommandee", vigueur: "faible",
    essais_tunisie: [{
      lieu: "Takelsa (nord)", annee_plantation: 2003, densite: "1250 arbres/ha",
      resultat: "Variété la plus adaptée à la haute densité face à Arbequina i-18, Chemlali et Chétoui ; rendement cumulé le plus élevé sur 5 récoltes ; alternance la plus faible (indice 0,38)",
      source: S.LARBI.url,
    }],
    risques: [EAU_SOIN, INVEST, ZONE_NON_TESTEE, {
      code: "froid_usa", severite: "attention", quand: { gel: ["frequent"] },
      texte: "Dégâts de froid et forte mortalité observés dans un essai aux États-Unis (climat très différent) : prudence si le gel est fréquent.",
      source: S.FROID_USA.url,
    }],
    points_forts: [
      "La plus adaptée à la haute densité dans l'essai tunisien de Takelsa (nord)",
      "Rendement élevé et alternance la plus faible de l'essai",
      "Huile riche en acide oléique (environ 69 %), port compact",
    ],
    limites: ["Verger à haute densité : conduite et récolte spécialisées"],
    sources: [S.LARBI, S.SHD, S.FROID_USA],
  }),
  V({
    id: "koroneiki", nom: "Koroneiki", origine: "importee", pays_origine: "Grèce",
    statut_donnees: "partiel", usage: ["huile"], zones_adaptees: [],
    systemes: ["super_intensif"], besoin_irrigation: "recommandee", vigueur: "moyenne",
    risques: [EAU_SOIN, INVEST, {
      code: "aucun_essai_tn", severite: "info", quand: {},
      texte: "Aucun essai tunisien documenté dans notre base pour cette variété.",
      source: S.LARBI.url,
    }, {
      code: "sel", severite: "attention", quand: { salinite: ["moyenne", "elevee"] },
      texte: "Moins tolérante au sel que Chemlali dans un essai en serre (arrosage à 100 mM de NaCl).",
      source: S.SEL_KORONEIKI.url,
    }, {
      code: "chaleur", severite: "attention", quand: { zones: ["centre", "sud"] },
      texte: "Floraison fortement affectée par les hautes températures observée en Égypte : risque dans les zones chaudes.",
      source: S.FROID_USA.url,
    }, {
      code: "froid_usa", severite: "attention", quand: { gel: ["frequent"] },
      texte: "Dégâts de froid et forte mortalité observés dans un essai aux États-Unis (climat très différent).",
      source: S.FROID_USA.url,
    }],
    points_forts: [
      "Variété très productive donnant des huiles de haute qualité",
      "Une des trois variétés utilisées dans les vergers super-intensifs",
    ],
    limites: ["Plus vigoureuse qu'Arbequina et Arbosana : conduite plus exigeante"],
    sources: [S.SHD, S.SEL_KORONEIKI, S.FROID_USA, S.CHALEUR],
  }),
];