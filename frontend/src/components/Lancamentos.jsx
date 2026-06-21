import { useState, useEffect, useCallback } from 'react'
import { api } from '../api'

function fmt(value) {
  if (value == null) return '—'
  return `R$ ${Math.abs(Number(value)).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`
}

function toDateStr(d) {
  return d.toISOString().split('T')[0]
}

function isParcelamento(txn) {
  const desc = (txn.descricao ?? '').toUpperCase()
  const cat  = (txn.categoria_pierre ?? '').toUpperCase()
  return /\b\d{1,2}\/\d{1,2}\b/.test(desc) ||
         desc.includes('PARCELA') ||
         cat.includes('INSTALLMENT') ||
         cat.includes('PARCELA')
}

function FilterBtn({ active, onClick, children, color = 'emerald' }) {
  const activeClass = color === 'emerald'
    ? 'bg-emerald-600 text-white'
    : 'bg-zinc-600 text-white'
  return (
    <button
      onClick={onClick}
      className={`flex-1 py-1.5 text-xs rounded-lg font-medium transition-colors
        ${active ? activeClass : 'bg-zinc-800 text-zinc-400 hover:text-zinc-200'}`}
    >
      {children}
    </button>
  )
}

export default function Lancamentos() {
  const today = new Date()
  const threeMonthsAgo = new Date(today)
  threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3)

  const [items, setItems]             = useState([])
  const [loading, setLoading]         = useState(true)
  const [dataInicio, setDataInicio]   = useState(toDateStr(threeMonthsAgo))
  const [dataFim, setDataFim]         = useState(toDateStr(today))
  const [fluxo, setFluxo]             = useState('todos')
  const [conta, setConta]             = useState('todos')
  const [semParcelas, setSemParcelas] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const data = await api.getExtrato({ data_inicio: dataInicio, data_fim: dataFim })
      setItems(data?.items ?? [])
    } catch {
      setItems([])
    } finally {
      setLoading(false)
    }
  }, [dataInicio, dataFim])

  useEffect(() => { load() }, [load])

  const filtered = items.filter(txn => {
    if (fluxo === 'entrada' && !(txn.valor > 0))                      return false
    if (fluxo === 'saida'   && !(txn.valor < 0))                      return false
    if (conta === 'credito' && !/credit/i.test(txn.conta_tipo ?? '')) return false
    if (conta === 'debito'  &&  /credit/i.test(txn.conta_tipo ?? '')) return false
    if (semParcelas && isParcelamento(txn))                            return false
    return true
  })

  const totalFiltrado = filtered.reduce((s, t) => s + Number(t.valor ?? 0), 0)

  return (
    <div className="flex flex-col h-full">
      {/* Filtros */}
      <div className="px-3 pt-3 pb-2 border-b border-zinc-800 space-y-2 shrink-0">
        <div className="flex gap-2 items-center">
          <input
            type="date" value={dataInicio}
            onChange={e => setDataInicio(e.target.value)}
            className="flex-1 bg-zinc-800 rounded-lg px-2 py-1.5 text-xs text-zinc-200
                       outline-none focus:ring-1 focus:ring-emerald-500"
          />
          <span className="text-zinc-600 text-xs shrink-0">até</span>
          <input
            type="date" value={dataFim}
            onChange={e => setDataFim(e.target.value)}
            className="flex-1 bg-zinc-800 rounded-lg px-2 py-1.5 text-xs text-zinc-200
                       outline-none focus:ring-1 focus:ring-emerald-500"
          />
        </div>

        <div className="flex gap-1.5">
          <FilterBtn active={fluxo === 'todos'}   onClick={() => setFluxo('todos')}>Todos</FilterBtn>
          <FilterBtn active={fluxo === 'entrada'} onClick={() => setFluxo('entrada')}>Entradas</FilterBtn>
          <FilterBtn active={fluxo === 'saida'}   onClick={() => setFluxo('saida')}>Saídas</FilterBtn>
        </div>

        <div className="flex gap-1.5">
          <FilterBtn active={conta === 'todos'}   onClick={() => setConta('todos')}   color="zinc">Todos</FilterBtn>
          <FilterBtn active={conta === 'debito'}  onClick={() => setConta('debito')}  color="zinc">Débito</FilterBtn>
          <FilterBtn active={conta === 'credito'} onClick={() => setConta('credito')} color="zinc">Crédito</FilterBtn>
          <button
            onClick={() => setSemParcelas(v => !v)}
            className={`px-2.5 py-1.5 text-xs rounded-lg font-medium transition-colors shrink-0
              ${semParcelas ? 'bg-zinc-600 text-white' : 'bg-zinc-800 text-zinc-500'}`}
          >
            S/ parcelas
          </button>
        </div>
      </div>

      {/* Resumo */}
      <div className="flex items-center justify-between px-4 py-1.5 shrink-0">
        <p className="text-xs text-zinc-600">
          {loading ? 'Carregando...' : `${filtered.length} lançamentos`}
        </p>
        {!loading && filtered.length > 0 && (
          <p className={`text-xs font-semibold tabular-nums
            ${totalFiltrado >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
            {totalFiltrado >= 0 ? '+' : ''}{fmt(totalFiltrado)}
          </p>
        )}
      </div>

      {/* Lista */}
      <div className="flex-1 overflow-y-auto scrollbar-thin">
        {filtered.map(txn => {
          const positivo  = txn.valor > 0
          const isCredito = /credit/i.test(txn.conta_tipo ?? '')
          const cat = txn.categoria_confirmada ?? txn.categoria_pierre
          return (
            <div
              key={txn.id}
              className="flex items-center justify-between px-4 py-3
                         border-b border-zinc-800/50 hover:bg-zinc-800/30"
            >
              <div className="min-w-0 flex-1 mr-3">
                <p className="text-sm text-zinc-200 truncate">{txn.descricao}</p>
                <p className="text-xs text-zinc-600 truncate">
                  {txn.data_transacao}
                  {' · '}{txn.conta_nome_marketing ?? txn.conta_nome}
                  {cat ? ` · ${cat}` : ''}
                </p>
              </div>
              <div className="text-right shrink-0">
                <p className={`text-sm font-semibold tabular-nums
                  ${positivo ? 'text-emerald-400' : 'text-zinc-300'}`}>
                  {positivo ? '+' : '-'}{fmt(txn.valor)}
                </p>
                <p className="text-xs text-zinc-600">{isCredito ? 'crédito' : 'débito'}</p>
              </div>
            </div>
          )
        })}

        {!loading && filtered.length === 0 && (
          <div className="text-center text-zinc-600 text-sm py-12">
            Nenhum lançamento encontrado.
          </div>
        )}
      </div>
    </div>
  )
}
