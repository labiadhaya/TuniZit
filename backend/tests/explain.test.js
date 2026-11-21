const { buildContext, buildPrompt, checkExplanation, callGemini, explain } = require("../services/explain");

const resultats = [
  { variete: "Chemlali", score: 98, raisons: ["Adaptee au sol sableux"], limites: ["Sensible au gel"] },
];
const input = { gouvernorat: "Sfax", pluvio: 220, sol: "sableux", drainage: "moyen", eau: "pluvial", objectif: "huile", email: "secret@x.com" };
const ctx = buildContext(input, resultats);
const allNames = ["Chemlali", "Chétoui", "Oueslati"];
const good = "Chemlali convient bien à votre terrain sableux. Consultez un technicien agricole avant de planter.";

test("le contexte n'envoie aucune donnee personnelle", () => {
  expect(JSON.stringify(ctx)).not.toContain("secret@x.com");
  expect(ctx.varietes).toHaveLength(1);
});

test("le prompt contient les regles et la langue demandee", () => {
  const p = buildPrompt(ctx, "ar_tn");
  expect(p.system).toContain("UNIQUEMENT");
  expect(p.system).toContain("dialecte tunisien");
  expect(p.user).toContain("Chemlali");
});

test("checkExplanation accepte un texte correct", () => {
  expect(checkExplanation(good, ctx, allNames)).toBe(true);
});

test("checkExplanation rejette une variete inventee (accents ignores)", () => {
  expect(checkExplanation(good + " Chetoui est aussi possible.", ctx, allNames)).toBe(false);
});

test("checkExplanation rejette liens et texte vide", () => {
  expect(checkExplanation("Voir https://exemple.com pour Chemlali ok ok ok", ctx, allNames)).toBe(false);
  expect(checkExplanation("", ctx, allNames)).toBe(false);
});

test("explain : succes -> source ia", async () => {
  const r = await explain({ context: ctx, langue: "fr", allNames, gemini: async () => good });
  expect(r.source).toBe("ia");
  expect(r.texte).toBe(good);
});

test("explain : panne LLM -> texte de secours", async () => {
  const r = await explain({ context: ctx, langue: "fr", allNames, gemini: async () => { throw new Error("timeout"); } });
  expect(r.source).toBe("modele");
  expect(r.texte).toContain("Chemlali (98/100)");
});

test("explain : variete inventee -> texte de secours", async () => {
  const r = await explain({ context: ctx, allNames, gemini: async () => good + " Essayez Oueslati." });
  expect(r.source).toBe("modele");
});

test("explain : aucun resultat -> pas d'appel LLM", async () => {
  let called = false;
  const empty = buildContext(input, []);
  const r = await explain({ context: empty, allNames, gemini: async () => { called = true; return good; } });
  expect(called).toBe(false);
  expect(r.source).toBe("modele");
});

test("explain : langue inconnue -> francais, secours en arabe pour ar", async () => {
  const r = await explain({ context: ctx, langue: "ar", allNames, gemini: async () => { throw new Error("x"); } });
  expect(r.texte).toContain("ملخص");
});

describe("callGemini", () => {
  const ok = (text) => async () => ({ ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text }] } }] }) });
  test("lit le texte de la reponse et envoie la cle en en-tete", async () => {
    let seen;
    const fetchImpl = async (url, opt) => { seen = { url, opt }; return ok("Bonjour")(); };
    const t = await callGemini({ system: "s", user: "u" }, { apiKey: "K", model: "m1", fetchImpl });
    expect(t).toBe("Bonjour");
    expect(seen.url).toContain("models/m1:generateContent");
    expect(seen.opt.headers["x-goog-api-key"]).toBe("K");
    expect(seen.url).not.toContain("K");
  });
  test("erreur HTTP -> exception", async () => {
    await expect(callGemini({ system: "s", user: "u" }, { apiKey: "K", fetchImpl: async () => ({ ok: false, status: 429 }) })).rejects.toThrow("429");
  });
  test("cle absente -> exception", async () => {
    await expect(callGemini({ system: "s", user: "u" }, { apiKey: "" })).rejects.toThrow("GEMINI_API_KEY");
  });
  test("reponse vide -> exception", async () => {
    await expect(callGemini({ system: "s", user: "u" }, { apiKey: "K", fetchImpl: ok("") })).rejects.toThrow();
  });
});