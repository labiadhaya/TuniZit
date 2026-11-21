const express = require("express");
const router = express.Router();
const { generatePlan } = require("../controllers/planner.controller");

// POST /api/planner/generate
router.post("/generate", generatePlan);

module.exports = router;
