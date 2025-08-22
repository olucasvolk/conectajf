import React, { useState, useEffect } from 'react'
import { Heart, MessageCircle, Share, MoreVertical, MapPin, Clock } from 'lucide-react'
import { motion } from 'framer-motion'
import { formatDistanceToNow } from 'date-fns'
import { ptBR } from 'date-fns/locale'

interface FeedPostProps {
  post: {
    id: string
    title: string
    content: string
    category?: string
    location?: string
    likes_count: number
    comments_count: number
    created_at: string
    profiles: {
      username: string
      full_name: string
      avatar_url?: string
    }
  }
  isLiked: boolean
  onLike: (postId: string) => void
  onComment: (postId: string) => void
}

export function FeedPost({ post, isLiked, onLike, onComment }: FeedPostProps) {
  const [liked, setLiked] = useState(isLiked)

  useEffect(() => {
    setLiked(isLiked)
  }, [isLiked])

  const handleLike = () => {
    onLike(post.id)
  }

  const getCategoryColor = (category?: string) => {
    const colors: Record<string, string> = {
      'política': 'bg-red-100 text-red-800',
      'economia': 'bg-green-100 text-green-800',
      'esportes': 'bg-blue-100 text-blue-800',
      'cultura': 'bg-purple-100 text-purple-800',
      'saúde': 'bg-pink-100 text-pink-800',
      'segurança': 'bg-orange-100 text-orange-800',
      'trânsito': 'bg-yellow-100 text-yellow-800',
      'clima': 'bg-cyan-100 text-cyan-800'
    }
    return colors[category || 'geral'] || 'bg-gray-100 text-gray-800'
  }

  return (
    <motion.article
      layout
      className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-md transition-shadow"
    >
      {/* Header */}
      <div className="flex items-center justify-between p-4 pb-3">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center text-white font-medium text-sm">
            {post.profiles?.avatar_url ? (
              <img 
                src={post.profiles.avatar_url} 
                alt={post.profiles.full_name}
                className="w-10 h-10 rounded-full object-cover"
              />
            ) : (
              post.profiles?.full_name?.charAt(0) || 'U'
            )}
          </div>
          <div className="flex-1">
            <div className="flex items-center space-x-2">
              <p className="font-medium text-gray-900">{post.profiles?.full_name}</p>
              {post.category && (
                <span className={`px-2 py-0.5 text-xs font-medium rounded-full ${getCategoryColor(post.category)}`}>
                  {post.category}
                </span>
              )}
            </div>
            <div className="flex items-center space-x-2 text-sm text-gray-500">
              <span>@{post.profiles?.username}</span>
              <span>•</span>
              <div className="flex items-center space-x-1">
                <Clock size={12} />
                <span>{formatDistanceToNow(new Date(post.created_at), { locale: ptBR, addSuffix: true })}</span>
              </div>
            </div>
          </div>
        </div>
        <button className="text-gray-400 hover:text-gray-600 p-2 rounded-full hover:bg-gray-100">
          <MoreVertical size={18} />
        </button>
      </div>

      {/* Content */}
      <div className="px-4 pb-3">
        <h2 className="font-semibold text-gray-900 mb-2 text-lg leading-tight">{post.title}</h2>
        <p className="text-gray-700 leading-relaxed">{post.content}</p>
        
        {post.location && (
          <div className="flex items-center space-x-1 mt-3 text-sm text-gray-500">
            <MapPin size={14} />
            <span>{post.location}</span>
          </div>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center justify-between px-4 py-3 border-t border-gray-50 bg-gray-50">
        <div className="flex items-center space-x-6">
          <motion.button
            onClick={handleLike}
            className={`flex items-center space-x-2 px-3 py-1.5 rounded-full transition-colors ${
              liked 
                ? 'text-red-500 bg-red-50' 
                : 'text-gray-500 hover:text-red-500 hover:bg-red-50'
            }`}
            whilePressed={{ scale: 0.95 }}
          >
            <motion.div
              animate={liked ? { scale: [1, 1.2, 1] } : {}}
              transition={{ duration: 0.3 }}
            >
              <Heart size={18} fill={liked ? 'currentColor' : 'none'} />
            </motion.div>
            <span className="text-sm font-medium">{post.likes_count}</span>
          </motion.button>

          <motion.button
            onClick={() => onComment(post.id)}
            className="flex items-center space-x-2 px-3 py-1.5 rounded-full text-gray-500 hover:text-blue-500 hover:bg-blue-50 transition-colors"
            whilePressed={{ scale: 0.95 }}
          >
            <MessageCircle size={18} />
            <span className="text-sm font-medium">{post.comments_count}</span>
          </motion.button>

          <motion.button
            className="flex items-center space-x-2 px-3 py-1.5 rounded-full text-gray-500 hover:text-green-500 hover:bg-green-50 transition-colors"
            whilePressed={{ scale: 0.95 }}
          >
            <Share size={18} />
          </motion.button>
        </div>
      </div>
    </motion.article>
  )
}
