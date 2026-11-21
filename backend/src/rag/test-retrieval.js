require("dotenv").config();

const { searchDocuments } = require("./retrieval");

async function main() {
  try {
    const question = "كيفاش نعتني بالزيتون وقت الجني؟";

    console.log("Question:", question);

    const results = await searchDocuments(question, 3);

    console.log("\n========== SEARCH RESULTS ==========");

    if (!results || results.length === 0) {
      console.log("No relevant documents found.");
      return;
    }

    results.forEach((item, index) => {
      console.log(`\nResult ${index + 1}`);
      console.log("Document:", item.document_name);
      console.log("Page:", item.metadata.page);
      console.log("Similarity:", item.similarity);
      console.log("Content:", item.content);
    });
  } catch (error) {
    console.error("Retrieval error:", error.message);
  }
}

main();
