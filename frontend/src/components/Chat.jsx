import { useState, useEffect, useRef } from 'react'
import { api } from '../api'

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
    doCheckin()
  }, [])

  const doCheckin = async () => {
    setLoading(true)
    try {
      const data = await api.checkin()
      setMessages([{ role: 'assistant', content: data.response, id: Date.now() }])
    } catch {
      setMessages([{
        role: 'assistant',
        content: 'Não consegui conectar ao servidor. Verifique a configuração do VITE_API_BASE.',
        id: Date.now()
      }])
    } finally {
      setLoading(false)
    }
  }

  const sendMessage = async () => {
    const text = input.trim()
    if (!text || loading) return

    setMessages(prev => [...prev, { role: 'user', content: text, id: Date.now() }])
    setInput('')
    setLoading(true)

    try {
      const data = await api.chat(text)
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: data.response,
        id: Date.now()
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
          <div key={msg.id} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            {msg.role === 'assistant' && (
              <div className="w-6 h-6 rounded-full bg-emerald-600 flex items-center justify-center
                              text-xs font-bold shrink-0 mt-1 mr-2">
                F
              </div>
            )}
            <div className={`max-w-[82%] rounded-2xl px-4 py-3 text-sm leading-relaxed whitespace-pre-wrap
              ${msg.role === 'user'
                ? 'bg-zinc-700 text-white rounded-br-sm'
                : 'bg-zinc-800 text-zinc-100 rounded-bl-sm'
              }`}
            >
              {msg.content}
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
