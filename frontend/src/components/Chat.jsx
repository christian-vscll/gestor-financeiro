import { useState, useEffect, useRef } from 'react'
import { api } from '../api'

function fmtTime(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  if (isNaN(d)) return ''
  return d.toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
}

export default function Chat() {
  const [messages, setMessages] = useState([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const bottomRef = useRef(null)
  const inputRef = useRef(null)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  useEffect(() => {
    loadHistory()
  }, [])

  const loadHistory = async () => {
    setLoading(true)
    try {
      const histData = await api.getHistory()
      const items = histData?.items ?? []

      if (items.length > 0) {
        setMessages(items.map((m, i) => ({ role: m.role, content: m.conteudo, id: i, timestamp: m.criado_em })))

        // Só faz checkin se última mensagem tem mais de 4h
        const lastTime = new Date(items[items.length - 1].criado_em)
        const hoursAgo = (Date.now() - lastTime.getTime()) / 36e5
        if (hoursAgo >= 4) await doCheckin()
      } else {
        await doCheckin()
      }
    } catch (err) {
      setMessages([{ role: 'assistant', content: `Erro de conexão: ${err.message}`, id: Date.now() }])
    } finally {
      setLoading(false)
    }
  }

  const doCheckin = async () => {
    try {
      const data = await api.checkin()
      setMessages(prev => [...prev, { role: 'assistant', content: data.response, id: Date.now(), timestamp: new Date().toISOString() }])
    } catch (err) {
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: `Erro de conexão: ${err.message}`,
        id: Date.now()
      }])
    }
  }

  const sendMessage = async () => {
    const text = input.trim()
    if (!text || loading) return

    const now = new Date().toISOString()
    setMessages(prev => [...prev, { role: 'user', content: text, id: Date.now(), timestamp: now }])
    setInput('')
    setLoading(true)

    try {
      const data = await api.chat(text)
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: data.response,
        id: Date.now(),
        timestamp: new Date().toISOString()
      }])
    } catch {
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: 'Erro ao enviar mensagem.',
        id: Date.now()
      }])
    } finally {
      setLoading(false)
      inputRef.current?.focus()
    }
  }

  const handleKey = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage()
    }
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto p-4 space-y-4 scrollbar-thin">
        {messages.map(msg => (
          <div key={msg.id} className={`flex items-end gap-2 ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            {msg.role === 'assistant' && (
              <div className="w-6 h-6 rounded-full bg-emerald-600 flex items-center justify-center
                              text-xs font-bold shrink-0 mb-4">
                F
              </div>
            )}
            <div className="max-w-[82%]">
              <div className={`rounded-2xl px-4 py-3 text-sm leading-relaxed whitespace-pre-wrap
                ${msg.role === 'user'
                  ? 'bg-zinc-700 text-white rounded-br-sm'
                  : 'bg-zinc-800 text-zinc-100 rounded-bl-sm'
                }`}
              >
                {msg.content}
              </div>
              {msg.timestamp && (
                <p className={`text-xs text-zinc-600 mt-0.5 ${msg.role === 'user' ? 'text-right' : 'text-left'}`}>
                  {fmtTime(msg.timestamp)}
                </p>
              )}
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex justify-start">
            <div className="w-6 h-6 rounded-full bg-emerald-600 flex items-center justify-center
                            text-xs font-bold shrink-0 mt-1 mr-2">
              F
            </div>
            <div className="bg-zinc-800 rounded-2xl rounded-bl-sm px-4 py-3.5">
              <div className="flex gap-1.5 items-center">
                {[0, 150, 300].map(delay => (
                  <span
                    key={delay}
                    className="w-1.5 h-1.5 bg-zinc-500 rounded-full animate-bounce"
                    style={{ animationDelay: `${delay}ms` }}
                  />
                ))}
              </div>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      <div className="p-3 border-t border-zinc-800 shrink-0">
        <div className="flex gap-2">
          <textarea
            ref={inputRef}
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={handleKey}
            placeholder="Mensagem para o Finn..."
            rows={1}
            className="flex-1 bg-zinc-800 rounded-xl px-4 py-2.5 text-sm resize-none outline-none
                       placeholder:text-zinc-600 focus:ring-1 focus:ring-emerald-500 max-h-32"
          />
          <button
            onClick={sendMessage}
            disabled={loading || !input.trim()}
            className="px-4 py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40
                       rounded-xl text-sm font-medium transition-colors shrink-0"
          >
            Enviar
          </button>
        </div>
        <p className="text-xs text-zinc-700 mt-1.5 pl-1">Enter para enviar · Shift+Enter para nova linha</p>
      </div>
    </div>
  )
}
