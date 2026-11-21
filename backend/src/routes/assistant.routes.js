const express = require("express");
const router = express.Router();

const { chat, chatStream } = require("../controllers/assistant.controller");
router.post("/chat", chat);
router.post("/chat/stream", chatStream);

module.exports = router;
