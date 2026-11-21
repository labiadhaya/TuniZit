require("dotenv").config();

const fs = require("fs");
const path = require("path");

const { storeChunks } = require("./store");

async function main() {
  try {
    const filePath = path.join(__dirname, "chunks-preview.json");

    const chunks = JSON.parse(fs.readFileSync(filePath, "utf8"));

    console.log(`Found ${chunks.length} chunks`);

    const result = await storeChunks(chunks);

    console.log("\nStorage successful!");
    console.log("Inserted records:", result.inserted);
    console.log(result);
  } catch (error) {
    console.error("Storage error:", error.message);
  }
}

main();
