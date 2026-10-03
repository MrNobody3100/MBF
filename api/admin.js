// Connexion admin : identifiant + mot de passe vérifiés côté serveur (variables d'environnement Vercel).
// La session est un cookie HttpOnly signé avec SESSION_SECRET (12 h). Aucun identifiant n'est présent dans le code du site.
const c = require('crypto');
const { ADMIN_USER, ADMIN_PASSWORD, SESSION_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_EMAIL } = process.env;
const dig = s => c.createHash('sha256').update(String(s)).digest();
const eq = (a, b) => (c.timingSafeEqual(dig(a), dig(b)) ? 1 : 0);
const sign = v => c.createHmac('sha256', SESSION_SECRET).update(String(v)).digest('hex');
const cookie = (v, age) => `mb_admin=${v}; HttpOnly; Secure; SameSite=Strict; Path=/api; Max-Age=${age}`;
const valid = req => {
  const m = /(?:^|; )mb_admin=(\d+)\.([a-f0-9]{64})/.exec(req.headers.cookie || '');
  return !!m && +m[1] > Date.now() && c.timingSafeEqual(Buffer.from(m[2]), Buffer.from(sign(m[1])));
};
// Jeton à usage unique qui ouvre la session Supabase du compte admin (les règles RLS restent actives)
async function supaToken() {
  const r = await fetch(SUPABASE_URL + '/auth/v1/admin/generate_link', {
    method: 'POST',
    headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SUPABASE_SERVICE_ROLE_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ type: 'magiclink', email: ADMIN_EMAIL })
  });
  const j = await r.json().catch(() => ({}));
  return j.hashed_token || (j.properties && j.properties.hashed_token) || null;
}
module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  const miss = ['ADMIN_USER', 'ADMIN_PASSWORD', 'SESSION_SECRET', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'ADMIN_EMAIL'].filter(k => !(process.env[k] || '').trim());
  if (!miss.length && SESSION_SECRET.length < 24) miss.push('SESSION_SECRET (24 caractères minimum)');
  if (miss.length) return res.status(500).json({ error: 'Serveur non configuré', manquant: miss });
  if (req.method === 'DELETE') { res.setHeader('Set-Cookie', cookie('', 0)); return res.status(204).end(); }
  if (req.method === 'POST') {
    const { username = '', password = '' } = req.body || {};
    await new Promise(r => setTimeout(r, 700)); // freine les essais répétés
    if (!(eq(username, ADMIN_USER) & eq(password, ADMIN_PASSWORD))) return res.status(401).json({ error: 'Identifiants incorrects' });
    const t = await supaToken();
    if (!t) return res.status(502).json({ error: 'Compte admin Supabase introuvable (ADMIN_EMAIL)' });
    const exp = Date.now() + 12 * 3600 * 1000;
    res.setHeader('Set-Cookie', cookie(exp + '.' + sign(exp), 12 * 3600));
    return res.status(200).json({ token_hash: t });
  }
  if (req.method === 'GET') {
    if (!valid(req)) return res.status(401).json({ error: 'Session expirée' });
    const t = await supaToken();
    return t ? res.status(200).json({ token_hash: t }) : res.status(502).json({ error: 'Erreur Supabase' });
  }
  res.status(405).end();
};
