import { useState, useEffect } from 'react'

const CATEGORIES = [
  'Alimentação', 'Transporte', 'Moradia', 'Saúde', 'Lazer',
  'Assinaturas', 'Receita PJ', 'Transferência', 'Reembolso',
  'Compras', 'Educação', 'Viagem', 'Dívidas/Parcelas',
  'Seguros', 'Outros',
]

function fmt(amount) {
  const abs = Math.abs(amount)
  const sign = amount < 0 ? '-' : '+'
  return `${sign}R$ ${abs.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`
}

function TransactionCard({ txn, onConfirm, onIgnore }) {
  const [editing, setEditing] = useState(false)
  const [category, setCategory] = useState(txn.pierre_category || '')
  const [note, setNote] = useState('')
  const [loading, setLoading] = useState(false)

  const isDebit = (txn.amount || 0) < 0

  const handleConfirm = async () => {
    setLoading(true)
    await onConfirm(txn.id, category || txn.pierre_category, note)
  }

  const handleIgnore = async () => {
    setLoading(true)
    await onIgnore(txn.id)
  }

  return (
    <div className="bg-zinc-900 rounded-xl p-4 space-y-3 border border-zinc-800/60">
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium leading-snug">{txn.description}</p>
          <p className="text-xs text-zinc-500 mt-0.5">
            {txn.date} · {txn.account_marketing_name || txn.account_name}
          </p>
        </div>
        <span className={`text-sm font-semibold whitespace-nowrap tabular-nums
          ${isDebit ? 'text-red-400' : 'text-emerald-400'}`}>
          {fmt(txn.amount || 0)}
        </span>
      </div>

      {editing ? (
        <div className="space-y-2">
          <select
            value={category}
            onChange={e => setCategory(e.target.value)}
            className="w-full bg-zinc-800 rounded-lg px-3 py-2 text-sm outline-none
                       focus:ring-1 focus:ring-emerald-500"
          >
            <option value="">Selecionar categoria</option>
            {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
          <input
            value={note}
            onChange={e => setNote(e.target.value)}
            placeholder="Nota (opcional, ex: parcela 3/6 Búzios)"
            className="w-full bg-zinc-800 rounded-lg px-3 py-2 text-sm outline-none
                       focus:ring-1 focus:ring-emerald-500 placeholder:text-zinc-600"
          />
        </div>
      ) : (
        <div className="flex items-center gap-2">
          <span className="text-xs bg-zinc-800 px-2.5 py-1 rounded-md text-zinc-400">
            {txn.pierre_category || 'Sem categoria'}
          </span>
          <button
            onClick={() => setEditing(true)}
            className="text-xs text-zinc-600 hover:text-zinc-400 transition-colors"
          >
            alterar
          </button>
        </div>
      )}

      <div className="flex gap-2">
        <button
          onClick={handleConfirm}
          disabled={loading}
          className="flex-1 py-2 text-sm font-medium bg-emerald-600 hover:bg-emerald-500
                     disabled:opacity-40 rounded-lg transition-colors"
        >
          {editing ? 'Salvar' : 'Confirmar'}
        </button>
        <button
          onClick={handleIgnore}
          disabled={loading}
          className="px-4 py-2 text-sm text-zinc-400 hover:text-zinc-200
                     bg-zinc-800 hover:bg-zinc-700 disabled:opacity-40 rounded-lg transition-colors"
        >
          Ignorar
        </button>
      </div>
    </div>
  )
}

export default function ReviewQueue({ onReviewed }) {
  const [transactions, setTransactions] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch('/api/transactions/pending')
      .then(r => r.json())
      .then(data => setTransactions(Array.isArray(data) ? data : []))
      .finally(() => setLoading(false))
  }, [])

  const handleConfirm = async (id, category, note) => {
    await fetch(`/api/transactions/${encodeURIComponent(id)}/review`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ confirmed_category: category, notes: note }),
    })
    setTransactions(prev => prev.filter(t => t.id !== id))
    onReviewed?.()
  }

  const handleIgnore = async (id) => {
    await fetch(`/api/transactions/${encodeURIComponent(id)}/ignore`, { method: 'PATCH' })
    setTransactions(prev => prev.filter(t => t.id !== id))
    onReviewed?.()
  }

  if (loading) {
    return <div className="flex items-center justify-center h-full text-zinc-500 text-sm">Carregando...</div>
  }

  if (transactions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full gap-3 text-center px-8">
        <span className="text-3xl">✓</span>
        <p className="text-zinc-400 text-sm">Tudo revisado por aqui.</p>
        <p className="text-zinc-600 text-xs">Sincronize para verificar novos lançamentos.</p>
      </div>
    )
  }

  return (
    <div className="h-full overflow-y-auto p-4 scrollbar-thin">
      <p className="text-xs text-zinc-500 mb-3">
        {transactions.length} lançamento{transactions.length !== 1 ? 's' : ''} aguardando revisão
      </p>
      <div className="space-y-3">
        {transactions.map(t => (
          <TransactionCard
            key={t.id}
            txn={t}
            onConfirm={handleConfirm}
            onIgnore={handleIgnore}
          />
        ))}
      </div>
    </div>
  )
}
