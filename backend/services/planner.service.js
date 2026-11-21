// backend/services/planner.service.js 
const supabase = require("../src/config/supabase");

class PlannerError extends Error {
  constructor(message, statusCode = 400) {
    super(message);
    this.name = "PlannerError";
    this.statusCode = statusCode;
  }
}

const governorateZone = {
  Bizerte: "nord",
  Béja: "nord",
  Jendouba: "nord",
  "Le Kef": "nord",
  Siliana: "nord",
  Zaghouan: "nord",
  Nabeul: "nord",
  Tunis: "nord",
  Ariana: "nord",
  "Ben Arous": "nord",
  Manouba: "nord",

  Sousse: "centre",
  Monastir: "centre",
  Mahdia: "centre",
  Kairouan: "centre",
  Kasserine: "centre",
  "Sidi Bouzid": "centre",

  Sfax: "sud",
  Gafsa: "sud",
  Gabès: "sud",
  Médenine: "sud",
  Tataouine: "sud",
  Tozeur: "sud",
  Kébili: "sud",
};

const allVarieties = [
  "Chemlali",
  "Chétoui",
  "Oueslati",
  "Zarrazi",
  "Gerboui",
  "Arbequina",
  "Arbosana",
  "Koroneiki",
];

const shdVarieties = ["Arbequina", "Arbosana", "Koroneiki"];

// ---------------------------------------------------------------------------
// Règles depuis Supabase (aucun fallback : si une règle manque, on le voit)
// ---------------------------------------------------------------------------
async function getPlantingRules() {
  const { data, error } = await supabase
    .from("planting_rules")
    .select("key, er, et")
    .eq("is_active", true);

  if (error) {
    console.error("Supabase planting_rules error:", error);
    throw new PlannerError(
      "Impossible de récupérer les règles de plantation.",
      500,
    );
  }

  const rules = {};
  for (const row of data || []) {
    const key = String(row.key ?? "").trim();
    const er = Number(row.er);
    const et = Number(row.et);

    if (
      !key ||
      !Number.isFinite(er) ||
      !Number.isFinite(et) ||
      er <= 0 ||
      et <= 0
    ) {
      console.warn("Règle ignorée (invalide):", row);
      continue;
    }
    rules[key] = { er, et };
  }
  return rules;
}

// ---------------------------------------------------------------------------
// Validation / normalisation de l'input
// ---------------------------------------------------------------------------
function toNumberOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : NaN; // NaN = valeur fournie mais invalide
}

function normalizeInput(raw) {
  const input = raw && typeof raw === "object" ? raw : {};

  if (
    typeof input.governorate !== "string" ||
    !governorateZone[input.governorate]
  ) {
    throw new PlannerError("Gouvernorat inconnu.");
  }

  if (input.irrigated !== undefined && typeof input.irrigated !== "boolean") {
    throw new PlannerError("Le champ irrigated doit être un booléen.");
  }
  if (
    input.wantSuperIntensive !== undefined &&
    typeof input.wantSuperIntensive !== "boolean"
  ) {
    throw new PlannerError("Le champ wantSuperIntensive doit être un booléen.");
  }
  if (input.varieties !== undefined && !Array.isArray(input.varieties)) {
    throw new PlannerError("Le champ varieties doit être une liste.");
  }

  const varieties = [...new Set(input.varieties || [])];
  const unknown = varieties.filter((v) => !allVarieties.includes(v));
  if (unknown.length > 0) {
    throw new PlannerError(`Variété inconnue : ${unknown.join(", ")}`);
  }

  const lengthM = toNumberOrNull(input.lengthM);
  const widthM = toNumberOrNull(input.widthM);
  const surfaceHa = toNumberOrNull(input.surfaceHa);
  const marginM = toNumberOrNull(input.marginM) ?? 2;

  if ([lengthM, widthM, surfaceHa, marginM].some((v) => Number.isNaN(v))) {
    throw new PlannerError("Valeur numérique invalide.");
  }

  return {
    governorate: input.governorate,
    irrigated: input.irrigated === true,
    wantSuperIntensive: input.wantSuperIntensive === true,
    varieties,
    lengthM,
    widthM,
    surfaceHa,
    marginM,
  };
}

// ---------------------------------------------------------------------------
// Calcul
// ---------------------------------------------------------------------------
function calculatePlan(input, rules) {
  const zone = governorateZone[input.governorate];

  let length;
  let width;
  let estimated = false;

  if (input.lengthM !== null && input.widthM !== null) {
    length = input.lengthM;
    width = input.widthM;
  } else if (input.surfaceHa !== null) {
    const area = input.surfaceHa * 10000;
    if (area <= 0)
      throw new PlannerError("La surface doit être supérieure à 0.");
    width = Math.sqrt(area / 2);
    length = 2 * width;
    estimated = true;
  } else {
    throw new PlannerError("Renseignez les dimensions ou la surface.");
  }

  if (length <= 0 || width <= 0) {
    throw new PlannerError("Longueur et largeur doivent être supérieures à 0.");
  }
  if (input.marginM < 0) {
    throw new PlannerError("La marge ne peut pas être négative.");
  }

  const { irrigated, varieties, marginM } = input;
  const canShd =
    irrigated &&
    varieties.length > 0 &&
    varieties.every((v) => shdVarieties.includes(v));

  const warnings = [];
  if (input.wantSuperIntensive && !canShd) {
    warnings.push(
      "Le système super-intensif n’est pas proposé : irrigation et variétés compatibles requises. Le système irrigué classique est utilisé.",
    );
  }

  let system;
  let ruleKey;
  if (!irrigated) {
    system = "pluvial";
    ruleKey = `pluvial_${zone}`;
  } else if (input.wantSuperIntensive && canShd) {
    system = "superIntensif";
    ruleKey = "super_intensif";
  } else {
    system = "irrigueClassique";
    ruleKey = "irrigue";
  }

  const spacing = rules[ruleKey];
  if (!spacing) {
    throw new PlannerError(`Règle de plantation introuvable : ${ruleKey}`, 500);
  }

  const usableLength = length - 2 * marginM;
  const usableWidth = width - 2 * marginM;
  if (usableLength <= 0 || usableWidth <= 0) {
    throw new PlannerError("Parcelle trop petite pour cette marge.");
  }

  const surface = length * width;
  const usableArea = usableLength * usableWidth;

  const rows = Math.floor(usableWidth / spacing.er + 1e-9) + 1;
  const treesPerRow = Math.floor(usableLength / spacing.et + 1e-9) + 1;
  const totalTrees = rows * treesPerRow;
  const density = totalTrees / (surface / 10000);

  // Répartition équilibrée en blocs contigus (ex: 10 rangées / 3 variétés => 4,3,3)
  const varietyRows = {};
  if (varieties.length > 0) {
    const base = Math.floor(rows / varieties.length);
    const remainder = rows % varieties.length;
    varieties.forEach((v, i) => {
      varietyRows[v] = base + (i < remainder ? 1 : 0);
    });
  }

  const rowVarieties =
    varieties.length === 0
      ? Array(rows).fill("")
      : varieties.flatMap((v) => Array(varietyRows[v]).fill(v));

  if (varieties.length > rows) {
    warnings.push(
      "Il y a moins de rangées que de variétés sélectionnées : certaines variétés ne peuvent pas recevoir une rangée dans cette estimation.",
    );
  }
  warnings.push(
    "Répartition équilibrée des rangées à titre organisationnel. À confirmer selon les objectifs de production et l’avis d’un technicien agricole.",
  );
  warnings.push(
    "Les espacements affichés sont des valeurs de référence provisoires à valider avec un technicien agricole.",
  );

  return {
    system,
    zone,
    length_m: length,
    width_m: width,
    dimensions_estimated: estimated,
    surface_m2: surface,
    usable_area_m2: usableArea,
    row_spacing_m: spacing.er,
    tree_spacing_m: spacing.et,
    rows,
    trees_per_row: treesPerRow,
    total_trees: totalTrees,
    density_per_ha: density,
    variety_rows: varietyRows,
    row_varieties: rowVarieties,
    warnings,
  };
}

async function generatePlantingPlan(rawInput) {
  const input = normalizeInput(rawInput);
  const rules = await getPlantingRules();
  return calculatePlan(input, rules);
}

module.exports = { generatePlantingPlan, PlannerError };
