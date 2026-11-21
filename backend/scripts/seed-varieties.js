// Usage : npm run seed   (apres avoir execute le SQL de l'etape 1 dans Supabase)
require("dotenv").config();
const supabase = require("../services/supabase");
const varieties = require("../data/varieties");

(async () => {
  const { error } = await supabase.from("olive_varieties").upsert(varieties, { onConflict: "id" });
  if (error) {
    console.error("Echec :", error.message);
    process.exit(1);
  }
  console.log(`${varieties.length} varietes enregistrees.`);
})();