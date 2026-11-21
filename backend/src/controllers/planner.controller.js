const { generatePlantingPlan } = require("../../services/planner.service");

async function generatePlan(req, res) {
  try {
    const result = await generatePlantingPlan(req.body);

    return res.status(200).json({
      success: true,
      message: "Plan généré avec succès.",
      data: result,
    });
  } catch (error) {
    console.error("Planner error:", error);

    return res.status(error.statusCode || 400).json({
      success: false,
      message: error.message || "Erreur lors de la génération du plan.",
    });
  }
}

module.exports = { generatePlan };
