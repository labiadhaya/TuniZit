const assert = require("node:assert/strict");
const Module = require("node:module");
const path = require("node:path");
const test = require("node:test");

const controllerModulePath = path.resolve(__dirname, "assistant.controller.js");
const originalLoad = Module._load;

let askCalls = 0;
let retrievalCalls = 0;
let streamCalls = 0;
let generateContentCalls = 0;
let mockSources = [];
let mockContext = "";
let askArguments = [];
let askError = null;

const mockGenAI = {
  models: {
    generateContent: async () => {
      generateContentCalls++;
      return { text: "non-stream response" };
    },
    generateContentStream: async (request) => {
      streamCalls++;
      mockGenAI.lastStreamRequest = request;
      return (async function* () {
        yield { text: "stream response" };
      })();
    },
  },
};

class MockGeminiEmbeddingError extends Error {}

const mockChat = {
  askTunizit: async (question, history) => {
    askCalls++;
    askArguments.push([question, history]);
    if (askError) throw askError;
    return { answer: "chat response", sources: mockSources };
  },
  retrieveTunizitContext: async () => {
    retrievalCalls++;
    return { context: mockContext, sources: mockSources };
  },
  sanitizeHistory: (history) =>
    Array.isArray(history)
      ? history
          .filter(
            (item) =>
              item &&
              ["user", "model"].includes(item.role) &&
              typeof item.text === "string" &&
              item.text.length <= 4000,
          )
          .slice(-10)
      : [],
};

Module._load = function (request, parent, isMain) {
  if (parent && path.resolve(parent.filename) === controllerModulePath) {
    if (request === "../config/gemini") return mockGenAI;
    if (request === "../rag/chat") return mockChat;
    if (request === "../rag/embedding") {
      return { GeminiEmbeddingError: MockGeminiEmbeddingError };
    }
  }

  return originalLoad.call(this, request, parent, isMain);
};

let controller;
try {
  controller = require("./assistant.controller");
} finally {
  Module._load = originalLoad;
}

function makeResponse() {
  return {
    statusCode: 200,
    body: null,
    headers: {},
    events: [],
    ended: false,
    setHeader(name, value) {
      this.headers[name] = value;
    },
    flushHeaders() {},
    write(event) {
      this.events.push(event);
    },
    end() {
      this.ended = true;
    },
    status(statusCode) {
      this.statusCode = statusCode;
      return this;
    },
    json(body) {
      this.body = body;
      return body;
    },
  };
}

test("streaming retrieves once, generates once, and preserves SSE and sources", async () => {
  askCalls = 0;
  retrievalCalls = 0;
  streamCalls = 0;
  generateContentCalls = 0;
  mockSources = [
    {
      document: "olive.pdf",
      page: 3,
      similarity: 0.91,
      content: "document excerpt",
    },
  ];
  mockContext = "retrieved RAG context";
  process.env.GEMINI_MODEL = "mock-model";

  const response = makeResponse();
  await controller.chatStream(
    {
      body: {
        message: "question",
        history: [{ role: "user", text: "previous question" }],
      },
    },
    response,
  );

  assert.equal(askCalls, 0);
  assert.equal(retrievalCalls, 1);
  assert.equal(streamCalls, 1);
  assert.equal(generateContentCalls, 0);
  assert.match(mockGenAI.lastStreamRequest.contents, /retrieved RAG context/);
  assert.match(mockGenAI.lastStreamRequest.contents, /previous question/);
  assert.equal(response.headers["Content-Type"], "text/event-stream");
  assert.deepEqual(
    response.events.map((event) => event.replace(/^data: /, "").trim()),
    [
      JSON.stringify({ text: "stream response" }),
      JSON.stringify({ sources: mockSources }),
      "[DONE]",
    ],
  );
  assert.equal(response.ended, true);
});

test("non-streaming /chat retains its JSON response contract", async () => {
  askCalls = 0;
  askArguments = [];
  askError = null;
  retrievalCalls = 0;
  streamCalls = 0;
  generateContentCalls = 0;
  mockSources = [{ document: "olive.pdf", page: 3, content: "excerpt" }];

  const response = makeResponse();
  const history = [
    { role: "user", text: "previous question" },
    { role: "model", text: "previous answer" },
  ];
  await controller.chat({ body: { message: "question", history } }, response);

  assert.equal(askCalls, 1);
  assert.deepEqual(askArguments, [["question", history]]);
  assert.equal(retrievalCalls, 0);
  assert.equal(streamCalls, 0);
  assert.equal(generateContentCalls, 0);
  assert.deepEqual(response.body, {
    success: true,
    answer: "chat response",
    sources: mockSources,
    provider: "Gemini RAG",
  });
});

test("/chat uses no more than the last ten valid history messages", async () => {
  askCalls = 0;
  askArguments = [];
  askError = null;
  mockSources = [];

  const history = Array.from({ length: 12 }, (_, index) => ({
    role: index % 2 === 0 ? "user" : "model",
    text: `message ${index}`,
  }));
  history.push({ role: "assistant", text: "invalid role" });
  history.push({ role: "user", text: 42 });

  const response = makeResponse();
  await controller.chat({ body: { message: "question", history } }, response);

  assert.equal(askArguments[0][1].length, 10);
  assert.equal(askArguments[0][1][0].text, "message 2");
  assert.equal(askArguments[0][1][9].text, "message 11");
});

test("/chat accepts absent and empty history", async (t) => {
  for (const history of [undefined, []]) {
    await t.test(history === undefined ? "absent" : "empty", async () => {
      askCalls = 0;
      askArguments = [];
      askError = null;
      mockSources = [];

      const body = { message: "question" };
      if (history !== undefined) body.history = history;

      const response = makeResponse();
      await controller.chat({ body }, response);

      assert.equal(askCalls, 1);
      assert.deepEqual(askArguments[0], ["question", []]);
      assert.equal(response.body.success, true);
    });
  }
});

test("/chat maps embedding errors and hides other Gemini error details", async () => {
  askCalls = 0;
  askArguments = [];
  const quotaError = new MockGeminiEmbeddingError(
    "daily quota reached with private provider details",
  );
  quotaError.httpStatusCode = 429;
  quotaError.code = "GEMINI_DAILY_EMBEDDING_QUOTA";
  askError = quotaError;

  const quotaResponse = makeResponse();
  await controller.chat(
    { body: { message: "question", history: [] } },
    quotaResponse,
  );

  assert.equal(quotaResponse.statusCode, 429);
  assert.deepEqual(quotaResponse.body, {
    success: false,
    message: "daily quota reached with private provider details",
  });

  askError = new Error("sensitive Gemini response payload");
  const genericResponse = makeResponse();
  await controller.chat({ body: { message: "question" } }, genericResponse);

  assert.equal(genericResponse.statusCode, 502);
  assert.deepEqual(genericResponse.body, {
    success: false,
    message: "Impossible de contacter Tunizit. Réessayez.",
  });
  assert.doesNotMatch(
    JSON.stringify(genericResponse.body),
    /sensitive Gemini response payload/,
  );
  askError = null;
});
