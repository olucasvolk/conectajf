import React from 'react'
import { motion } from 'framer-motion'
import { format } from 'date-fns'
import { ptBR } from 'date-fns/locale'
import { Clock, Check, CheckCheck } from 'lucide-react'
import { MessageStatus } from '../../lib/supabase'

interface MessageBubbleProps {
  message: {
    content: string
    created_at: string
    status: MessageStatus
    read_at: string | null
  }
  isMe: boolean
}

const MessageStatusIndicator = ({ status }: { status: MessageStatus }) => {
  if (status === 'sending') {
    return <Clock size={16} className="text-gray-400" />
  }
  if (status === 'sent') {
    return <Check size={16} className="text-gray-400" />
  }
  if (status === 'read') {
    return <CheckCheck size={16} className="text-blue-500" />
  }
  // 'delivered' status can be handled here if implemented
  return <Check size={16} className="text-gray-400" />
}

export function MessageBubble({ message, isMe }: MessageBubbleProps) {
  const alignment = isMe ? 'items-end' : 'items-start'
  const bubbleColor = isMe ? 'bg-blue-500 text-white' : 'bg-white text-gray-800'
  const borderRadius = isMe ? 'rounded-t-2xl rounded-bl-2xl' : 'rounded-t-2xl rounded-br-2xl'

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className={`flex flex-col ${alignment}`}
    >
      <div className={`px-4 py-3 ${bubbleColor} ${borderRadius} shadow-sm max-w-xs md:max-w-md`}>
        <p className="leading-relaxed whitespace-pre-wrap">{message.content}</p>
      </div>
      <div className={`flex items-center space-x-1 text-xs text-gray-400 mt-1 px-1`}>
        <span>{format(new Date(message.created_at), 'HH:mm', { locale: ptBR })}</span>
        {isMe && <MessageStatusIndicator status={message.status} />}
      </div>
      {isMe && message.status === 'read' && message.read_at && (
        <div className="text-xs text-gray-400 mt-0.5 px-1">
          Visto em {format(new Date(message.read_at), "dd/MM 'às' HH:mm", { locale: ptBR })}
        </div>
      )}
    </motion.div>
  )
}
