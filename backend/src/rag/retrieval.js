require("dotenv").config();

const { createClient } = require("@supabase/supabase-js");
const { generateQuestionEmbedding } = require("./embedding");

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_PUBLISHABLE_KEY,
);

async function searchDocuments(question, limit = 5) {
  console.log("Generating question embedding...");

  const queryEmbedding = await generateQuestionEmbedding(question);

  console.log("Searching Supabase...");

  const { data, error } = await supabase.rpc("match_documents", {
    query_embedding: queryEmbedding,
    match_count: limit,
  });

  if (error) {
    throw new Error(`Retrieval error: ${error.message}`);
  }

  return data;
}

module.exports = { searchDocuments };
