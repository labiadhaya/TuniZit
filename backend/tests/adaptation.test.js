const rows = require("../data/varieties");
const { evaluerAdaptation } = require("../services/adaptation");

const get = (id) => rows.find((v) => v.id === id);
const irrigue = { eau: "reguliere", systeme: "super_intensif" };

test("Arbosana irriguee dans le nord : adaptee sous conditions", () => {
  const r = evaluerAdaptation(get("arbosana"), { ...irrigue, gouvernorat: "Béja" });
  expect(r.verdict).toBe("adaptee_sous_conditions");
  expect(r.conditions.join(" ")).toContain("irrigation");
  expect(r.essais_tunisie.length).toBe(1);
});

test("Arbosana a Sfax : donnees insuffisantes (aucun essai documente)", () => {
  const r = evaluerAdaptation(get("arbosana"), { ...irrigue, gouvernorat: "Sfax" });
  expect(r.verdict).toBe("donnees_insuffisantes");
  expect(r.conditions.join(" ")).toContain("Aucun essai documenté");
});

test("Koroneiki a Sfax avec sel : risques signales", () => {
  const r = evaluerAdaptation(get("koroneiki"), { ...irrigue, gouvernorat: "Sfax", salinite: "elevee" });
  expect(r.verdict).toBe("donnees_insuffisantes");
  expect(r.attentions.join(" ")).toContain("sel");
  expect(r.attentions.join(" ")).toContain("températures");
});

test("Chemlali en super-intensif : deconseillee", () => {
  const r = evaluerAdaptation(get("chemlali"), { ...irrigue, gouvernorat: "Sfax" });
  expect(r.verdict).toBe("deconseillee");
  expect(r.bloquants.length).toBeGreaterThan(0);
});

test("Chetoui a Sfax : deconseillee", () => {
  const r = evaluerAdaptation(get("chetoui"), { eau: "pluvial", gouvernorat: "Sfax" });
  expect(r.verdict).toBe("deconseillee");
});

test("Chemlali a Sfax en pluvial : adaptee", () => {
  const r = evaluerAdaptation(get("chemlali"), { eau: "pluvial", gouvernorat: "Sfax" });
  expect(r.verdict).toBe("adaptee");
});

test("variete importee en pluvial : condition explicite", () => {
  const r = evaluerAdaptation(get("arbequina"), { eau: "pluvial", gouvernorat: "Béja" });
  expect(r.conditions.join(" ")).toContain("pluviale");
});

test("parcelle a Verticillium : Chemlali deconseillee", () => {
  const r = evaluerAdaptation(get("chemlali"), { eau: "pluvial", gouvernorat: "Sfax", verticillium: "oui" });
  expect(r.verdict).toBe("deconseillee");
  expect(r.bloquants.join(" ")).toContain("Verticillium");
});

test("reponse complete : sources, avertissement, libelle", () => {
  const r = evaluerAdaptation(get("arbequina"), { ...irrigue, gouvernorat: "Béja" });
  expect(r.sources.length).toBeGreaterThan(0);
  expect(r.avertissement).toBeTruthy();
  expect(r.verdict_libelle).toBeTruthy();
});