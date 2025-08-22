import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Send, Paperclip } from 'lucide-react'
import { motion } from 'framer-motion'
import { supabase, MessageStatus } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { LoadingSpinner } from '../Common/LoadingSpinner'
import { MessageBubble } from './MessageBubble'
import { ErrorModal } from '../Common/ErrorModal'
import { useDebouncedCallback } from 'use-debounce'

type Message = {
  id: string | number;
  room_id: string;
  user_id: string;
  content: string;
  created_at: string;
  status: MessageStatus;
  read_at: string | null;
  profiles: {
    id: string;
    username: string;
    full_name: string;
    avatar_url?: string;
  } | null;
};

export function ChatRoomScreen() {
  const { roomId } = useParams<{ roomId: string }>()
  const navigate = useNavigate()
  const { user, profile } = useAuth()

  const [messages, setMessages] = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(true)
  const [roomInfo, setRoomInfo] = useState<any | null>(null)
  const [typingUser, setTypingUser] = useState<any | null>(null)
  const [errorModal, setErrorModal] = useState<{ isOpen: boolean; message: string | null }>({ isOpen: false, message: null })
  const messagesEndRef = useRef<HTMLDivElement>(null)

  const markMessagesAsRead = useCallback(async () => {
    if (!roomId || !user) return
    await supabase
      .from('chat_messages')
      .update({ status: 'read', read_at: new Date().toISOString() })
      .eq('room_id', roomId)
      .neq('user_id', user.id)
      .in('status', ['sent', 'delivered']) // Apenas atualiza mensagens não lidas
  }, [roomId, user])

  useEffect(() => {
    const fetchRoomData = async () => {
      if (!roomId) return
      setLoading(true)

      const { data: roomData, error: roomError } = await supabase
        .from('chat_rooms').select('*, members:chat_room_members(profiles(*))').eq('id', roomId).single()
      
      if (roomError) {
        console.error('Error fetching room info:', roomError)
        setErrorModal({ isOpen: true, message: `Erro ao carregar dados da sala: ${roomError.message}` })
        navigate('/chat')
        return
      }
      setRoomInfo(roomData)

      const { data: messageData, error: messageError } = await supabase
        .from('chat_messages').select(`*, profiles (*)`).eq('room_id', roomId).order('created_at', { ascending: true })

      if (messageError) {
        console.error('Error fetching messages:', messageError)
        setErrorModal({ isOpen: true, message: `Erro ao carregar mensagens: ${messageError.message}` })
      } else {
        setMessages(messageData || [])
      }

      setLoading(false)
      markMessagesAsRead()
    }
    fetchRoomData()
  }, [roomId, navigate, markMessagesAsRead])

  useEffect(() => {
    if (!roomId || !user) return

    const messageChannel = supabase.channel(`chat_messages:${roomId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'chat_messages', filter: `room_id=eq.${roomId}` },
        async (payload) => {
          if (payload.eventType === 'INSERT') {
            const insertedMessage = payload.new as Message
            // Substitui a mensagem temporária pela real
            setMessages((prev) => prev.map(m => m.id === `temp-${insertedMessage.content}` ? { ...insertedMessage, ...payload.new } : m))
            if (document.hidden && insertedMessage.user_id !== user.id) {
              // Se a aba não está ativa, não marca como lida
            } else if (insertedMessage.user_id !== user.id) {
              markMessagesAsRead()
            }
          }
          if (payload.eventType === 'UPDATE') {
            const updatedMessage = payload.new as Message
            setMessages((prev) => prev.map(m => m.id === updatedMessage.id ? { ...m, ...updatedMessage } : m))
          }
        }
      ).subscribe()

    const typingChannel = supabase.channel(`typing:${roomId}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'chat_room_members', filter: `room_id=eq.${roomId}` },
        (payload) => {
          const updatedMember = payload.new
          if (updatedMember.user_id !== user?.id && updatedMember.is_typing) {
            const typingProfile = roomInfo?.members.find((m: any) => m.profiles.id === updatedMember.user_id)?.profiles
            setTypingUser(typingProfile)
            // Oculta o "digitando" após um tempo para não ficar preso
            setTimeout(() => setTypingUser(null), 3000)
          } else if (updatedMember.user_id !== user?.id && !updatedMember.is_typing) {
            setTypingUser(null)
          }
        }
      ).subscribe()

    // Listener para marcar como lido quando a aba fica visível
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        markMessagesAsRead()
      }
    }
    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      supabase.removeChannel(messageChannel)
      supabase.removeChannel(typingChannel)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [roomId, user, markMessagesAsRead, roomInfo])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const updateTypingStatus = useDebouncedCallback(async (isTyping: boolean) => {
    if (!roomId || !user) return
    await supabase.from('chat_room_members').update({ is_typing: isTyping }).eq('room_id', roomId).eq('user_id', user.id)
  }, 300)

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setNewMessage(e.target.value)
    updateTypingStatus(e.target.value.length > 0)
  }

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || !user || !roomId || !profile) return

    const content = newMessage.trim()
    setNewMessage('')
    updateTypingStatus(false)

    // UI Otimista: Adiciona a mensagem instantaneamente com status 'sending'
    const tempMessage: Message = {
      id: `temp-${Date.now()}`, // ID temporário único
      room_id: roomId,
      user_id: user.id,
      content,
      created_at: new Date().toISOString(),
      status: 'sending',
      read_at: null,
      profiles: profile,
    }
    setMessages(prev => [...prev, tempMessage])

    const { error } = await supabase
      .from('chat_messages')
      .insert([{ room_id: roomId, user_id: user.id, content, status: 'sent' }])

    if (error) {
      console.error('Error sending message:', error)
      // Em caso de erro, remove a mensagem temporária e restaura o texto
      setMessages(prev => prev.filter(m => m.id !== tempMessage.id))
      setNewMessage(content)
      setErrorModal({ isOpen: true, message: `Não foi possível enviar a mensagem: ${error.message}` })
    }
  }

  if (loading) {
    return <div className="flex items-center justify-center h-screen"><LoadingSpinner size="lg" text="Carregando conversa..." /></div>
  }

  const otherUser = roomInfo?.members.find((m: any) => m.profiles.id !== user?.id)?.profiles

  return (
    <div className="h-screen flex flex-col bg-gray-100">
      <ErrorModal
        isOpen={errorModal.isOpen}
        onClose={() => setErrorModal({ isOpen: false, message: null })}
        error={errorModal.message}
      />

      <div className="sticky top-0 bg-white border-b border-gray-200 p-4 flex items-center space-x-4 z-10 shadow-sm">
        <button onClick={() => navigate('/chat')} className="p-2 -ml-2 rounded-full hover:bg-gray-100">
          <ArrowLeft size={20} className="text-gray-600" />
        </button>
        <div className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center">
          <span className="font-bold text-gray-600">{otherUser?.full_name?.charAt(0) || 'C'}</span>
        </div>
        <div className="flex-1 min-w-0">
          <h1 className="font-bold text-gray-900 truncate">{otherUser?.full_name || 'Conversa'}</h1>
          <p className="text-sm text-green-500 h-4 transition-opacity duration-300">
            {typingUser ? `${typingUser.full_name.split(' ')[0]} está digitando...` : ''}
          </p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg) => (
          <MessageBubble key={msg.id} message={msg} isMe={msg.user_id === user?.id} />
        ))}
        <div ref={messagesEndRef} />
      </div>

      <div className="bg-white border-t border-gray-200 p-4">
        <form onSubmit={handleSendMessage} className="flex items-center space-x-2">
          <button type="button" className="p-2 text-gray-500 hover:text-blue-500"><Paperclip size={20} /></button>
          <input
            type="text"
            value={newMessage}
            onChange={handleInputChange}
            onBlur={() => updateTypingStatus(false)}
            placeholder="Digite uma mensagem..."
            className="flex-1 px-4 py-2 border border-gray-300 rounded-full focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
          <motion.button
            type="submit"
            disabled={!newMessage.trim()}
            className="w-10 h-10 bg-blue-500 text-white rounded-full flex items-center justify-center disabled:opacity-50"
            whileTap={{ scale: 0.95 }}
          >
            <Send size={20} />
          </motion.button>
        </form>
      </div>
    </div>
  )
}
