const BASE = (import.meta.env.VITE_API_BASE || '').replace(/\/$/, '')

const postJSON = (url, body) =>
  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body ?? {}),
  }).then(r => r.json())

export const api = {
  // Transações
  getPending: () =>
    fetch(`${BASE}/transacoes/pendentes/`).then(r => r.json()),
  sync: () =>
    postJSON(`${BASE}/transacoes/sync/`),
  revisar: (id, categoria_confirmada, notas) =>
    postJSON(`${BASE}/transacoes/${encodeURIComponent(id)}/revisar/`, { categoria_confirmada, notas }),
  ignorar: (id) =>
    postJSON(`${BASE}/transacoes/${encodeURIComponent(id)}/ignorar/`),

  // Chat
  checkin: () =>
    fetch(`${BASE}/chat/checkin/`).then(r => r.json()),
  chat: (message) =>
    postJSON(`${BASE}/chat/`, { message }),
  clearHistory: () =>
    fetch(`${BASE}/chat/historico/`, { method: 'DELETE' }).then(r => r.json()),

  // Contas
  getSaldo: () =>
    fetch(`${BASE}/contas/saldo/`).then(r => r.json()),
  getFaturas: () =>
    fetch(`${BASE}/contas/faturas/`).then(r => r.json()),
}
