require("dotenv").config();

const { generateEmbedding } = require("./embedding");

async function main() {
  try {
    const text = "كيفية العناية بأشجار الزيتون";

    console.log("Generating embedding...");

    const embedding = await generateEmbedding(text);

    console.log("Success!");
    console.log("Dimensions:", embedding.length);
    console.log("First 5 values:", embedding.slice(0, 5));
  } catch (error) {
    console.error("Embedding error:", error.message);
  }
}

main();
