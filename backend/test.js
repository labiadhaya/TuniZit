require('dotenv').config();
const Anthropic = require('@anthropic-ai/sdk');
const a = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
a.messages.create({
  model: 'claude-sonnet-5-5',
  max_tokens: 20,
  messages: [{ role: 'user', content: 'Dis bonjour' }],
}).then(r => console.log('OK:', r.content[0].text))
  .catch(e => console.log('ERREUR:', e.status, e.message));