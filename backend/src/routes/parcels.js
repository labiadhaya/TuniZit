// back/routes/parcels.js
// app.use('/api/parcels', authMiddleware, require('./routes/parcels'));
const router = require('express').Router();
const supabase = require('../supabaseClient');

const TABLE = 'parcels';
const FIELDS = ['exploitation_id', 'name', 'location', 'variety', 'trees_count'];
const fail = (res, error, code = 500) =>
  res.status(code).json({ error: (error && error.message) || String(error) });
const pick = (b) =>
  Object.fromEntries(FIELDS.filter((k) => b[k] !== undefined).map((k) => [k, b[k]]));

async function ownsExploitation(userId, id) {
  if (!id) return true;
  const { data } = await supabase.from('exploitations').select('id')
    .eq('id', id).eq('user_id', userId).maybeSingle();
  return !!data;
}

// GET /api/parcels?exploitation_id=...
router.get('/', async (req, res) => {
  let q = supabase.from(TABLE).select('*').eq('user_id', req.user.id);
  if (req.query.exploitation_id) q = q.eq('exploitation_id', req.query.exploitation_id);
  const { data, error } = await q.order('created_at', { ascending: true });
  if (error) return fail(res, error);
  res.json(data);
});

// POST /api/parcels   body: { name, exploitation_id?, location?, variety?, trees_count? }
router.post('/', async (req, res) => {
  const row = pick(req.body || {});
  if (!row.name || !String(row.name).trim()) return fail(res, 'name requis', 400);
  if (!(await ownsExploitation(req.user.id, row.exploitation_id))) {
    return fail(res, 'exploitation invalide', 400);
  }
  const { data, error } = await supabase.from(TABLE)
    .insert({ ...row, user_id: req.user.id }).select().single();
  if (error) return fail(res, error);
  res.status(201).json(data);
});

// PUT /api/parcels/:id
router.put('/:id', async (req, res) => {
  const row = pick(req.body || {});
  if (!(await ownsExploitation(req.user.id, row.exploitation_id))) {
    return fail(res, 'exploitation invalide', 400);
  }
  const { data, error } = await supabase.from(TABLE).update(row)
    .eq('id', req.params.id).eq('user_id', req.user.id).select().maybeSingle();
  if (error) return fail(res, error);
  if (!data) return fail(res, 'introuvable', 404);
  res.json(data);
});

// DELETE /api/parcels/:id
router.delete('/:id', async (req, res) => {
  const { error } = await supabase.from(TABLE).delete()
    .eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return fail(res, error);
  res.status(204).end();
});

module.exports = router;
