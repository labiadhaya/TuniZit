require("dotenv").config();

const { askTunizit } = require("./chat");

async function main() {
  try {
    const question = "كيفاش نعتني بالزيتون وقت الجني؟";

    console.log("\nUser:", question);

    const result = await askTunizit(question);

    console.log("\n========== TUNIZIT ANSWER ==========\n");

    console.log(result.answer);

    console.log("\n========== SOURCES ==========\n");

    console.log(JSON.stringify(result.sources, null, 2));
  } catch (error) {
    console.error("Chat error:", error.message);
  }
}

main();
