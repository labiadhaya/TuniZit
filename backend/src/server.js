require("dotenv").config();

const express = require("express");
const app = express();

const assistantRoutes = require("./routes/assistant.routes");
const plannerRoutes = require("./routes/planner.routes");
const scanRoutes = require("./routes/scan.routes");
const farmRoutes = require("./routes/farm.routes");
const supabaseAdmin = require("./config/supabaseAdmin");
const activityRoutes = require("./routes/activities");
const authMiddleware = require("./middleware/auth");

app.set("trust proxy", 1);
app.use(express.json({ limit: "1mb" }));

// CORS pour le prototype Flutter Web.
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept,Authorization",
  );
  res.header("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS");

  if (req.method === "OPTIONS") {
    return res.sendStatus(204);
  }

  next();
});

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Tunizit Backend is running 🌿",
  });
});

app.use("/api/assistant", assistantRoutes);
app.use("/api/planner", plannerRoutes);
// 9bal app.use("/api", scanRoutes) w farmRoutes
app.use("/api/activities", authMiddleware, activityRoutes);
app.use("/api", scanRoutes); // POST /api/scan
app.use("/api", farmRoutes(supabaseAdmin)); // /api/parcels, /api/scans/:id/parcel, /api/expert-requests

const PORT = process.env.PORT || 5000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Tunizit Backend running on port ${PORT}`);
});
