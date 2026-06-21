import { useState, useEffect } from 'react'
import Chat from './components/Chat'
import ReviewQueue from './components/ReviewQueue'
import AccountsView from './components/AccountsView'

export default function App() {
  const [tab, setTab] = useState('chat')
  const [pendingCount, setPendingCount] = useState(0)
  const [syncing, setSyncing] = useState(false)
  const [syncMsg, setSyncMsg] = useState('')

  const fetchPendingCount = async () => {
    try {
      const res = await fetch('/api/transactions/pending')
      const data = await res.json()
      setPendingCount(Array.isArray(data) ? data.length : 0)
    } catch {}
  }

  useEffect(() => { fetchPendingCount() }, [])

  const handleSync = async () => {
    setSyncing(true)
    setSyncMsg('')
    try {
      const res = await fetch('/api/transactions/sync', { method: 'POST' })
      const data = await res.json()
      setSyncMsg(`+${data.new} novos`)
      await fetchPendingCount()
      setTimeout(() => setSyncMsg(''), 3000)
    } catch {
      setSyncMsg('Erro')
    } finally {
      setSyncing(false)
    }
  }

  const tabs = [
    { id: 'chat', label: 'Chat' },
    { id: 'review', label: 'Revisar', badge: pendingCount },
    { id: 'contas', label: 'Contas' },
  ]

  return (
    <div className="flex flex-col h-screen max-w-2xl mx-auto">
      {/* Header */}
      <header className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 shrink-0">
        <div>
          <span className="font-semibold">Finn</span>
          <span className="text-xs text-zinc-500 ml-2">gerente financeiro</span>
        </div>
        <div className="flex items-center gap-2">
          {syncMsg && <span className="text-xs text-emerald-400">{syncMsg}</span>}
          <button
            onClick={handleSync}
            disabled={syncing}
            className="text-xs px-3 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700
                       disabled:opacity-50 transition-colors"
          >
            {syncing ? 'Sincronizando...' : 'Sincronizar'}
          </button>
        </div>
      </header>

      {/* Tabs */}
      <nav className="flex border-b border-zinc-800 shrink-0">
        {tabs.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`flex-1 py-2.5 text-sm font-medium transition-colors relative
              ${tab === t.id ? 'text-white' : 'text-zinc-500 hover:text-zinc-300'}`}
          >
            {t.label}
            {t.badge > 0 && (
              <span className="ml-1.5 text-xs bg-emerald-500 text-black font-bold
                               rounded-full px-1.5 py-0.5">
                {t.badge}
              </span>
            )}
            {tab === t.id && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-emerald-500" />
            )}
          </button>
        ))}
      </nav>

      {/* Content */}
      <main className="flex-1 overflow-hidden">
        {tab === 'chat' && <Chat />}
        {tab === 'review' && <ReviewQueue onReviewed={fetchPendingCount} />}
        {tab === 'contas' && <AccountsView />}
      </main>
    </div>
  )
}
