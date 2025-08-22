import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search, Edit, Users } from 'lucide-react'
import { motion } from 'framer-motion'
import { ChatList } from './ChatList'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { LoadingSpinner } from '../Common/LoadingSpinner'
import { EmptyState } from '../Common/EmptyState'

export function ChatScreen() {
  const [chatRooms, setChatRooms] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const { user } = useAuth()
  const navigate = useNavigate()

  useEffect(() => {
    if (user) {
      fetchChatRooms()
    }
  }, [user])

  const fetchChatRooms = async () => {
    if (!user) return

    setLoading(true)
    try {
      // This query fetches rooms where the current user is a member.
      const { data, error } = await supabase
        .from('chat_rooms')
        .select(`
          *,
          members:chat_room_members(
            profiles(id, username, full_name, avatar_url)
          )
        `)
        .in('id', 
          (await supabase
            .from('chat_room_members')
            .select('room_id')
            .eq('user_id', user.id)
          ).data?.map(m => m.room_id) || []
        )
        .order('last_message_at', { ascending: false })

      if (error) throw error
      setChatRooms(data || [])
    } catch (error) {
      console.error('Error fetching chat rooms:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleNewChat = () => {
    navigate('/chat/new')
  }

  const filteredRooms = chatRooms.filter(room =>
    room.name?.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <div className="pb-20">
      {/* Header */}
      <div className="sticky top-0 bg-white border-b border-gray-200 p-4 z-10">
        <div className="flex items-center justify-between mb-4">
          <h1 className="text-xl font-bold text-gray-900">💬 Conversas</h1>
          <div className="flex space-x-2">
            <button
              onClick={handleNewChat}
              className="p-2 rounded-full hover:bg-gray-100"
            >
              <Edit size={20} className="text-gray-600" />
            </button>
          </div>
        </div>

        {/* Search */}
        <div className="relative">
          <Search size={20} className="absolute left-3 top-3 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar conversas..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* Chat List */}
      <div className="p-4">
        {loading ? (
          <div className="flex justify-center py-12">
            <LoadingSpinner text="Carregando conversas..." />
          </div>
        ) : filteredRooms.length === 0 ? (
          <EmptyState
            icon="💬"
            title="Nenhuma conversa ainda"
            description="Clique no botão de editar para iniciar uma nova conversa com outros usuários."
            action={{
              label: "Nova Conversa",
              onClick: handleNewChat
            }}
          />
        ) : (
          <ChatList rooms={filteredRooms} />
        )}
      </div>
    </div>
  )
}
