// back/routes/activities.js
// Monter dans app.js :
//   app.use('/api/activities', authMiddleware, require('./routes/activities'));
//
// Hypothèses (à adapter à ton projet) :
//   - ../supabaseClient exporte un client supabase-js v2
//   - authMiddleware remplit req.user.id avec l'id de l'utilisateur connecté
const router = require('express').Router();
const supabase = require('../supabaseClient');

const TABLE = 'calendar_activities';
const SELECT = '*, parcels(name, variety, trees_count)';
const PRIORITIES = ['basse', 'moyenne', 'haute'];
const STATUSES = ['a_faire', 'en_cours', 'terminee'];

// Champs que le client a le droit d'envoyer (jamais user_id, id, completed_at…)
const FIELDS = [
  'exploitation_id', 'parcel_id', 'title', 'category', 'description',
  'location_label', 'priority', 'status', 'progress', 'due_date', 'reminder_at',
];

// --- Phase phénologique ------------------------------------------------------
// Seule la phase vue dans la maquette est renseignée.
// TODO: compléter les autres phases avec une source agronomique fiable
//       (le PDF insiste : pas de dates/chiffres inventés).
const PHENOLOGY = [
  {
    months: [9, 10, 11],
    saison: 'Automne',
    phase: 'Pré-récolte & Véraison',
    conseil:
      "Optimisez l'accumulation lipidique. Nettoyez les inter-rangs pour préparer le déploiement fluide des filets de récolte.",
  },
];

// --- Helpers -----------------------------------------------------------------
const fail = (res, error, code = 500) =>
  res.status(code).json({ error: (error && error.message) || String(error) });

const pick = (body) =>
  Object.fromEntries(FIELDS.filter((k) => body[k] !== undefined).map((k) => [k, body[k]]));

function validate(row, { creating }) {
  if (creating && (!row.title || !String(row.title).trim())) return 'title requis';
  if (creating && !row.category) return 'category requis';
  if (row.priority !== undefined && !PRIORITIES.includes(row.priority)) return 'priority invalide';
  if (row.status !== undefined && !STATUSES.includes(row.status)) return 'status invalide';
  if (row.progress !== undefined) {
    const p = Number(row.progress);
    if (!Number.isInteger(p) || p < 0 || p > 100) return 'progress doit être un entier 0..100';
  }
  return null;
}

// Cohérence statut / progression / dates de fin
function applyStatusRules(row) {
  if (row.status === 'terminee') {
    row.progress = 100;
    row.completed_at = new Date().toISOString();
    row.validated = true;
  } else if (row.status !== undefined) {
    row.completed_at = null;
    row.validated = false;
    if (row.status === 'a_faire' && row.progress === undefined) row.progress = 0;
  }
  return row;
}

// La parcelle / l'exploitation référencée doit appartenir à l'utilisateur
async function ownsRefs(userId, { parcel_id, exploitation_id }) {
  if (parcel_id) {
    const { data } = await supabase
      .from('parcels').select('id').eq('id', parcel_id).eq('user_id', userId).maybeSingle();
    if (!data) return 'parcelle invalide';
  }
  if (exploitation_id) {
    const { data } = await supabase
      .from('exploitations').select('id').eq('id', exploitation_id).eq('user_id', userId).maybeSingle();
    if (!data) return 'exploitation invalide';
  }
  return null;
}

// --- Routes fixes AVANT /:id --------------------------------------------------

// GET /api/activities/calendar?month=2026-10
router.get('/calendar', async (req, res) => {
  const { month } = req.query;
  if (!/^\d{4}-\d{2}$/.test(month || '')) return fail(res, 'month attendu: YYYY-MM', 400);
  const [y, m] = month.split('-').map(Number);
  const start = `${month}-01`;
  const end = new Date(Date.UTC(y, m, 1)).toISOString().slice(0, 10); // 1er du mois suivant

  const { data, error } = await supabase.from(TABLE).select(SELECT)
    .eq('user_id', req.user.id).gte('due_date', start).lt('due_date', end).order('due_date');
  if (error) return fail(res, error);
  res.json(data);
});

// GET /api/activities/stats -> { toutes, a_faire, en_cours, terminee }
router.get('/stats', async (req, res) => {
  const { data, error } = await supabase.from(TABLE).select('status').eq('user_id', req.user.id);
  if (error) return fail(res, error);
  const counts = { toutes: data.length, a_faire: 0, en_cours: 0, terminee: 0 };
  data.forEach((a) => { counts[a.status] += 1; });
  res.json(counts);
});

// GET /api/activities/phenology -> {saison, phase, conseil} ou null
router.get('/phenology', (req, res) => {
  const month = new Date().getMonth() + 1;
  const found = PHENOLOGY.find((p) => p.months.includes(month));
  res.json(found ? { saison: found.saison, phase: found.phase, conseil: found.conseil } : null);
});

// --- CRUD -----------------------------------------------------------------------

// GET /api/activities?parcel_id=...&status=...
// Avec parcel_id : tâches de cette parcelle + tâches sans parcelle (ex: Hangar central)
router.get('/', async (req, res) => {
  const { parcel_id, status } = req.query;
  let q = supabase.from(TABLE).select(SELECT).eq('user_id', req.user.id);
  if (parcel_id) q = q.or(`parcel_id.eq.${parcel_id},parcel_id.is.null`);
  if (status) {
    if (!STATUSES.includes(status)) return fail(res, 'status invalide', 400);
    q = q.eq('status', status);
  }
  const { data, error } = await q.order('due_date', { ascending: true, nullsFirst: false });
  if (error) return fail(res, error);
  res.json(data);
});

// POST /api/activities
router.post('/', async (req, res) => {
  const row = pick(req.body || {});
  const invalid = validate(row, { creating: true });
  if (invalid) return fail(res, invalid, 400);
  const bad = await ownsRefs(req.user.id, row);
  if (bad) return fail(res, bad, 400);

  const { data, error } = await supabase.from(TABLE)
    .insert({ ...applyStatusRules(row), user_id: req.user.id }).select(SELECT).single();
  if (error) return fail(res, error);
  res.status(201).json(data);
});

// GET /api/activities/:id
router.get('/:id', async (req, res) => {
  const { data, error } = await supabase.from(TABLE).select(SELECT)
    .eq('id', req.params.id).eq('user_id', req.user.id).maybeSingle();
  if (error) return fail(res, error);
  if (!data) return fail(res, 'introuvable', 404);
  res.json(data);
});

// PUT /api/activities/:id
router.put('/:id', async (req, res) => {
  const row = pick(req.body || {});
  const invalid = validate(row, { creating: false });
  if (invalid) return fail(res, invalid, 400);
  const bad = await ownsRefs(req.user.id, row);
  if (bad) return fail(res, bad, 400);

  const { data, error } = await supabase.from(TABLE).update(applyStatusRules(row))
    .eq('id', req.params.id).eq('user_id', req.user.id).select(SELECT).maybeSingle();
  if (error) return fail(res, error);
  if (!data) return fail(res, 'introuvable', 404);
  res.json(data);
});

// PATCH /api/activities/:id/status   body: { status, progress? }
router.patch('/:id/status', async (req, res) => {
  const { status, progress } = req.body || {};
  const row = { status };
  if (progress !== undefined) row.progress = progress;
  if (!STATUSES.includes(status)) return fail(res, 'status invalide', 400);
  const invalid = validate(row, { creating: false });
  if (invalid) return fail(res, invalid, 400);

  const { data, error } = await supabase.from(TABLE).update(applyStatusRules(row))
    .eq('id', req.params.id).eq('user_id', req.user.id).select(SELECT).maybeSingle();
  if (error) return fail(res, error);
  if (!data) return fail(res, 'introuvable', 404);
  res.json(data);
});

// DELETE /api/activities/:id
router.delete('/:id', async (req, res) => {
  const { error } = await supabase.from(TABLE).delete()
    .eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return fail(res, error);
  res.status(204).end();
});

module.exports = router;
