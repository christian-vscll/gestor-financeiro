const ORACLE_BASE = 'https://g20d94e76dfb758-tresaconsult.adb.sa-saopaulo-1.oraclecloudapps.com/ords/dev_3aconsult/gestor-financeiro';

export default async function handler(req, res) {
  const [pathname, qs] = req.url.split('?');
  const oraclePath = pathname.replace(/^\/api/, '');
  const url = ORACLE_BASE + oraclePath + (qs ? '?' + qs : '');

  const init = {
    method: req.method,
    headers: { 'content-type': 'application/json' },
  };

  if (req.body && req.method !== 'GET' && req.method !== 'HEAD') {
    init.body = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
  }

  try {
    const upstream = await fetch(url, init);
    const text = await upstream.text();
    res.status(upstream.status)
       .setHeader('content-type', 'application/json')
       .end(text);
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
}
