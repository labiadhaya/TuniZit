// backend/src/config/supabase.js hathi genral ana 5demet bel public w najres b serice w entoum chouf selon 5edmtkom ach test79ou
const { createClient } = require("@supabase/supabase-js");

require("dotenv").config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_PUBLISHABLE_KEY,
);

module.exports = supabase;
