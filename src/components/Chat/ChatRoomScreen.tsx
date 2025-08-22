import React, { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Send, Paperclip, Loader2 } from 'lucide-react'
import { motion } from 'framer-motion'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { LoadingSpinner } from '../Common/LoadingSpinner'
import { MessageBubble } from './MessageBubble'

export function ChatRoomScreen() {
  const { roomId } = useParams<{ roomId: string }>()
  const navigate = useNavigate()
  const { user, profile } = useAuth()

  const [messages, setMessages] = useState<any[]>([])
  const [newMessage, setNewMessage] = useState('')
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const [roomInfo, setRoomInfo] = useState<any | null>(null)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const fetchRoomData = async () => {
      if (!roomId) return
      setLoading(true)

      // Fetch room info
      const { data: roomData, error: roomError } = await supabase
        .from('chat_rooms')
        .select('*')
        .eq('id', roomId)
        .single()
      
      if (roomError) {
        console.error('Error fetching room info:', roomError)
        navigate('/chat')
        return
      }
      setRoomInfo(roomData)

      // Fetch initial messages
      const { data: messageData, error: messageError } = await supabase
        .from('chat_messages')
        .select(`*, profiles (id, username, full_name, avatar_url)`)
        .eq('room_id', roomId)
        .order('created_at', { ascending: true })

      if (messageError) {
        console.error('Error fetching messages:', messageError)
      } else {
        setMessages(messageData || [])
      }

      setLoading(false)
    }

    fetchRoomData()
  }, [roomId, navigate])

  useEffect(() => {
    if (!roomId) return

    const channel = supabase
      .channel(`chat_room:${roomId}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'chat_messages', filter: `room_id=eq.${roomId}` },
        async (payload) => {
          // Fetch the full message with profile data
          const { data, error } = await supabase
            .from('chat_messages')
            .select(`*, profiles (id, username, full_name, avatar_url)`)
            .eq('id', payload.new.id)
            .single()
          
          if (!error && data) {
            setMessages((prevMessages) => [...prevMessages, data])
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [roomId])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newMessage.trim() || !user || !roomId) return

    setSending(true)
    const content = newMessage.trim()
    setNewMessage('')

    const { error } = await supabase
      .from('chat_messages')
      .insert([{ room_id: roomId, user_id: user.id, content: content }])

    if (error) {
      console.error('Error sending message:', error)
      setNewMessage(content) // Restore message on error
    }
    setSending(false)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <LoadingSpinner size="lg" text="Carregando conversa..." />
      </div>
    )
  }

  return (
    <div className="h-screen flex flex-col bg-gray-100">
      {/* Header */}
      <div className="sticky top-0 bg-white border-b border-gray-200 p-4 flex items-center space-x-4 z-10 shadow-sm">
        <button onClick={() => navigate('/chat')} className="p-2 -ml-2 rounded-full hover:bg-gray-100">
          <ArrowLeft size={20} className="text-gray-600" />
        </button>
        <div className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center">
          <span className="font-bold text-gray-600">
            {roomInfo?.name?.charAt(0) || 'C'}
          </span>
        </div>
        <div className="flex-1">
          <h1 className="font-bold text-gray-900">{roomInfo?.name || 'Conversa'}</h1>
          <p className="text-sm text-green-500">Online</p>
        </div>
      </div>

      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg) => (
          <MessageBubble
            key={msg.id}
            message={msg}
            isMe={msg.user_id === user?.id}
          />
        ))}
        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className="bg-white border-t border-gray-200 p-4">
        <form onSubmit={handleSendMessage} className="flex items-center space-x-2">
          <button type="button" className="p-2 text-gray-500 hover:text-blue-500">
            <Paperclip size={20} />
          </button>
          <input
            type="text"
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Digite uma mensagem..."
            className="flex-1 px-4 py-2 border border-gray-300 rounded-full focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            disabled={sending}
          />
          <motion.button
            type="submit"
            disabled={!newMessage.trim() || sending}
            className="w-10 h-10 bg-blue-500 text-white rounded-full flex items-center justify-center disabled:opacity-50"
            whileTap={{ scale: 0.95 }}
          >
            {sending ? <Loader2 size={20} className="animate-spin" /> : <Send size={20} />}
          </motion.button>
        </form>
      </div>
    </div>
  )
}
