const rows = require("../data/varieties");
const { recommander, avertissementsGeneraux } = require("../services/scoring");
const { validateInput } = require("../services/validation");
const { zoneFor } = require("../services/zones");

const base = { objectif: "huile", eau: "pluvial", drainage: "moyen", sol: "limoneux" };
const ids = (r) => r.map((x) => x.id);

test("zones : repartition ONH", () => {
  expect(zoneFor("Béja")).toBe("nord");
  expect(zoneFor("Sfax")).toBe("centre");
  expect(zoneFor("Médenine")).toBe("sud");
  expect(zoneFor("Atlantide")).toBeNull();
});

test("Sfax, pluvial, huile : Chemlali en tete, Chetoui exclu", () => {
  const r = recommander({ ...base, gouvernorat: "Sfax", pluvio: 220, sol: "sableux" }, rows);
  expect(r[0].id).toBe("chemlali");
  expect(ids(r)).not.toContain("chetoui");
});

test("Beja, pluvial, huile : Chetoui devant Chemlali", () => {
  const r = recommander({ ...base, gouvernorat: "Béja", pluvio: 600 }, rows);
  expect(ids(r)).toContain("chetoui");
  expect(ids(r).indexOf("chetoui")).toBeLessThan(ids(r).indexOf("chemlali"));
});

test("pluvial : aucune variete importee proposee", () => {
  const r = recommander({ ...base, gouvernorat: "Béja", pluvio: 600 }, rows, { limit: 20 });
  expect(r.every((x) => x.origine !== "importee")).toBe(true);
});

test("super-intensif irrigue dans le nord : Arbosana proposee, Chemlali exclue", () => {
  const input = { ...base, eau: "reguliere", systeme: "super_intensif", gouvernorat: "Béja", pluvio: 600 };
  const r = recommander(input, rows, { limit: 20 });
  expect(ids(r)).toContain("arbosana");
  expect(ids(r)).not.toContain("chemlali");
  expect(ids(r)).not.toContain("chetoui");
});

test("objectif table : Meski proposee, pas Chemlali", () => {
  const r = recommander({ ...base, objectif: "table", gouvernorat: "Nabeul", pluvio: 500 }, rows, { limit: 20 });
  expect(ids(r)).toContain("meski");
  expect(ids(r)).not.toContain("chemlali");
});

test("Verticillium oui : plus aucune variete", () => {
  const r = recommander({ ...base, gouvernorat: "Sfax", pluvio: 220, verticillium: "oui" }, rows, { limit: 20 });
  expect(r).toEqual([]);
});

test("onlyVerified : rien tant qu'un expert n'a pas valide", () => {
  expect(recommander({ ...base, gouvernorat: "Sfax", pluvio: 220 }, rows, { onlyVerified: true })).toEqual([]);
});

test("scores entre 0 et 100, fiabilite et sources presentes", () => {
  const r = recommander({ ...base, eau: "reguliere", gouvernorat: "Sfax", pluvio: 220, salinite: "elevee" }, rows, { limit: 20 });
  r.forEach((x) => {
    expect(x.score).toBeGreaterThanOrEqual(0);
    expect(x.score).toBeLessThanOrEqual(100);
    expect(["bonne", "moyenne", "faible"]).toContain(x.fiabilite);
    expect(x.sources.length).toBeGreaterThan(0);
  });
});

test("toute variete de la base a au moins une source", () => {
  rows.forEach((v) => expect(v.sources.length).toBeGreaterThan(0));
});

test("avertissements : drainage, secheresse extreme, sol", () => {
  const a = avertissementsGeneraux({ drainage: "mauvais", eau: "pluvial", pluvio: 150 });
  expect(a.join(" ")).toContain("Drainage mauvais");
  expect(a.join(" ")).toContain("200 mm");
  expect(a.join(" ")).toContain("type de sol");
});

describe("validation", () => {
  const ok = { gouvernorat: "Sfax", sol: "sableux", drainage: "moyen", eau: "pluvial", objectif: "huile" };
  test("entree valide", () => expect(validateInput(ok)).toEqual([]));
  test("sol invalide", () => expect(validateInput({ ...ok, sol: "x" })).toContain("sol invalide"));
  test("irrigation sans systeme", () =>
    expect(validateInput({ ...ok, eau: "reguliere", irrigation_systeme: "aucun" }).length).toBe(1));
  test("intensif en pluvial refuse", () =>
    expect(validateInput({ ...ok, systeme: "intensif" }).length).toBe(1));
  test("verticillium invalide", () =>
    expect(validateInput({ ...ok, verticillium: "peut-etre" })).toContain("verticillium invalide"));
  test("mode adaptation : gouvernorat et eau suffisent", () =>
    expect(validateInput({ gouvernorat: "Sfax", eau: "reguliere" }, "adaptation")).toEqual([]));
});