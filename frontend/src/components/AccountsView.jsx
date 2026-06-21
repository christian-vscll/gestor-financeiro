import { useState, useEffect } from 'react'
import { api } from '../api'

function fmt(value) {
  if (value == null) return '—'
  return `R$ ${Number(value).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`
}

function Card({ children, className = '' }) {
  return (
    <div className={`bg-zinc-900 rounded-xl border border-zinc-800/60 ${className}`}>
      {children}
    </div>
  )
}

export default function AccountsView() {
  const [balance, setBalance] = useState(null)
  const [bills, setBills] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    Promise.all([
      api.getSaldo().catch(() => null),
      api.getFaturas().catch(() => null),
    ]).then(([b, bl]) => {
      setBalance(b)
      setBills(bl)
    }).catch(() => setError('Erro ao carregar dados.'))
      .finally(() => setLoading(false))
  }, [])

  if (loading) {
    return <div className="flex items-center justify-center h-full text-zinc-500 text-sm">Carregando...</div>
  }

  if (error) {
    return <div className="flex items-center justify-center h-full text-red-400 text-sm">{error}</div>
  }

  const balData = balance?.data
  const totalBalance = balData?.totalBalance ?? balData?.total_balance ?? balData?.balance
  const accounts = balData?.accounts ?? []

  const today = new Date()
  const cutoff = new Date(today)
  cutoff.setMonth(cutoff.getMonth() - 1)

  const billsArr = (Array.isArray(bills?.data) ? bills.data : []).filter(bill => {
    const status = (bill.status ?? '').toUpperCase()
    if (status === 'FUTURE') return false
    const amount = bill.amount ?? bill.total ?? bill.totalAmount ?? 0
    if (!amount || Number(amount) === 0) return false
    const due = new Date(bill.due_date ?? bill.close_date ?? bill.dueDate ?? '')
    if (!isNaN(due.getTime())) return due >= cutoff
    return true
  })

  return (
    <div className="h-full overflow-y-auto p-4 space-y-4 scrollbar-thin">
      {/* Saldo total */}
      {totalBalance != null && (
        <Card className="p-4">
          <p className="text-xs text-zinc-500 mb-1">Saldo consolidado</p>
          <p className={`text-2xl font-bold tabular-nums
            ${totalBalance >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
            {fmt(totalBalance)}
          </p>
        </Card>
      )}

      {/* Contas */}
      {accounts.length > 0 && (
        <section>
          <p className="text-xs text-zinc-500 uppercase tracking-wider mb-2">Contas</p>
          <div className="space-y-2">
            {accounts.map((acc, i) => {
              const name = acc.marketing_name ?? acc.account_marketing_name ?? acc.name ?? acc.account_name
              const type = acc.subtype ?? acc.account_subtype ?? acc.type ?? acc.account_type
              const bal = acc.balance
              return (
                <Card key={i} className="flex items-center justify-between px-4 py-3">
                  <div>
                    <p className="text-sm font-medium">{name}</p>
                    <p className="text-xs text-zinc-500">{type}</p>
                  </div>
                  <span className={`text-sm font-semibold tabular-nums
                    ${(bal ?? 0) >= 0 ? 'text-zinc-100' : 'text-red-400'}`}>
                    {fmt(bal)}
                  </span>
                </Card>
              )
            })}
          </div>
        </section>
      )}

      {/* Faturas */}
      {billsArr.length > 0 && (
        <section>
          <p className="text-xs text-zinc-500 uppercase tracking-wider mb-2">Faturas</p>
          <div className="space-y-2">
            {billsArr.map((bill, i) => {
              const name = bill.account_name ?? bill.name
              const due = bill.due_date ?? bill.close_date ?? bill.dueDate
              const amount = bill.amount ?? bill.total ?? bill.totalAmount
              return (
                <Card key={i} className="flex items-center justify-between px-4 py-3">
                  <div>
                    <p className="text-sm font-medium">{name}</p>
                    {due && <p className="text-xs text-zinc-500">vence {due}</p>}
                  </div>
                  <span className="text-sm font-semibold tabular-nums text-red-400">
                    {fmt(amount)}
                  </span>
                </Card>
              )
            })}
          </div>
        </section>
      )}

      {/* Fallback */}
      {!balData && billsArr.length === 0 && (
        <div className="text-center text-zinc-500 text-sm py-8">
          <p>Dados não disponíveis.</p>
          <p className="text-xs mt-1 text-zinc-600">Verifique a conexão com o Pierre.</p>
        </div>
      )}
    </div>
  )
}
