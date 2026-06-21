const BASE = (import.meta.env.VITE_API_BASE || '').replace(/\/$/, '')

const postJSON = (url, body) =>
  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body ?? {}),
  }).then(r => r.text()).then(text => {
    try { return JSON.parse(text) } catch { return { _raw: text, _status: 'parse_error' } }
  })

export const api = {
  // Transações
  getPending: () =>
    fetch(`${BASE}/transacoes/pendentes/`).then(r => r.json()),
  getExtrato: (params = {}) => {
    const qs = new URLSearchParams(params).toString()
    return fetch(`${BASE}/transacoes/extrato/${qs ? '?' + qs : ''}`).then(r => r.json())
  },
  sync: () =>
    postJSON(`${BASE}/transacoes/sync/`),
  revisar: (id, categoria_confirmada, notas) =>
    postJSON(`${BASE}/transacoes/${encodeURIComponent(id)}/revisar/`, { categoria_confirmada, notas }),
  ignorar: (id) =>
    postJSON(`${BASE}/transacoes/${encodeURIComponent(id)}/ignorar/`),

  // Chat
  checkin: async () => {
    const r = await fetch(`${BASE}/chat/checkin/?_=${Date.now()}`)
    const text = await r.text()
    try { return JSON.parse(text) } catch { return { response: `[HTTP ${r.status}] ${text.slice(0, 500)}` } }
  },
  chat: (message) =>
    postJSON(`${BASE}/chat/`, { message }),
  getHistory: () =>
    fetch(`${BASE}/chat/historico/`).then(r => r.json()),
  clearHistory: () =>
    fetch(`${BASE}/chat/historico/`, { method: 'DELETE' }).then(r => r.json()),

  // Contas
  getSaldo: () =>
    fetch(`${BASE}/contas/saldo/`).then(r => r.json()),
  getFaturas: () =>
    fetch(`${BASE}/contas/faturas/`).then(r => r.json()),
}
