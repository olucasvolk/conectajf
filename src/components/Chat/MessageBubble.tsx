import React from 'react'
import { motion } from 'framer-motion'
import { format } from 'date-fns'
import { ptBR } from 'date-fns/locale'

interface MessageBubbleProps {
  message: {
    content: string
    created_at: string
    profiles: {
      full_name: string
    }
  }
  isMe: boolean
}

export function MessageBubble({ message, isMe }: MessageBubbleProps) {
  const alignment = isMe ? 'justify-end' : 'justify-start'
  const bubbleColor = isMe
    ? 'bg-blue-500 text-white'
    : 'bg-white text-gray-800'
  const borderRadius = isMe
    ? 'rounded-t-2xl rounded-bl-2xl'
    : 'rounded-t-2xl rounded-br-2xl'

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className={`flex ${alignment}`}
    >
      <div className="flex flex-col max-w-xs md:max-w-md">
        <div className={`px-4 py-3 ${bubbleColor} ${borderRadius} shadow-sm`}>
          <p className="leading-relaxed">{message.content}</p>
        </div>
        <div className={`text-xs text-gray-400 mt-1 px-1 ${isMe ? 'text-right' : 'text-left'}`}>
          {format(new Date(message.created_at), 'HH:mm', { locale: ptBR })}
        </div>
      </div>
    </motion.div>
  )
}
