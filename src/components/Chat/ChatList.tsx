import React from 'react'
import { useNavigate } from 'react-router-dom'
import { Users, User } from 'lucide-react'
import { motion } from 'framer-motion'
import { formatDistanceToNow } from 'date-fns'
import { ptBR } from 'date-fns/locale'

interface ChatListProps {
  rooms: Array<{
    id: string
    name?: string
    is_group: boolean
    last_message_at: string
    created_by: string
  }>
}

export function ChatList({ rooms }: ChatListProps) {
  const navigate = useNavigate()

  const handleChatClick = (roomId: string) => {
    navigate(`/chat/${roomId}`)
  }

  return (
    <div className="space-y-2">
      {rooms.map((room) => (
        <motion.div
          key={room.id}
          onClick={() => handleChatClick(room.id)}
          className="flex items-center space-x-3 p-3 rounded-lg hover:bg-gray-50 cursor-pointer"
          whileTap={{ scale: 0.98 }}
        >
          {/* Avatar */}
          <div className="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center">
            {room.is_group ? (
              <Users size={20} className="text-gray-600" />
            ) : (
              <User size={20} className="text-gray-600" />
            )}
          </div>

          {/* Content */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between">
              <h3 className="font-medium text-gray-900 truncate">
                {room.name || (room.is_group ? 'Grupo' : 'Conversa')}
              </h3>
              <span className="text-xs text-gray-500">
                {formatDistanceToNow(new Date(room.last_message_at), { 
                  locale: ptBR, 
                  addSuffix: true 
                })}
              </span>
            </div>
            <p className="text-sm text-gray-500 truncate">
              Última mensagem...
            </p>
          </div>

          {/* Unread indicator */}
          <div className="w-2 h-2 bg-blue-500 rounded-full opacity-0"></div>
        </motion.div>
      ))}
    </div>
  )
}
