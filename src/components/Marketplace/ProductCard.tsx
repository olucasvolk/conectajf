import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Heart, MapPin } from 'lucide-react'
import { motion } from 'framer-motion'
import { formatDistanceToNow } from 'date-fns'
import { ptBR } from 'date-fns/locale'

interface ProductCardProps {
  product: {
    id: string
    title: string
    price: number
    condition: string
    location?: string
    likes_count: number
    created_at: string
    profiles: {
      username: string
      full_name: string
    }
  }
  isLiked: boolean
  onLike: (productId: string) => void
}

export function ProductCard({ product, isLiked, onLike }: ProductCardProps) {
  const [liked, setLiked] = useState(isLiked)
  const navigate = useNavigate()

  useEffect(() => {
    setLiked(isLiked)
  }, [isLiked])

  const handleLike = (e: React.MouseEvent) => {
    e.stopPropagation() // Prevent navigation when liking
    onLike(product.id)
  }

  const handleCardClick = () => {
    navigate(`/marketplace/${product.id}`)
  }

  const getConditionColor = (condition: string) => {
    switch (condition) {
      case 'novo':
        return 'bg-green-100 text-green-800'
      case 'seminovo':
        return 'bg-yellow-100 text-yellow-800'
      case 'usado':
        return 'bg-gray-100 text-gray-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  return (
    <motion.div
      onClick={handleCardClick}
      className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden cursor-pointer hover:shadow-lg transition-shadow"
    >
      {/* Image placeholder */}
      <div className="aspect-square bg-gray-100 flex items-center justify-center">
        <span className="text-4xl">📷</span>
      </div>

      <div className="p-3">
        {/* Price and condition */}
        <div className="flex items-center justify-between mb-2">
          <span className="text-lg font-bold text-green-600">
            R$ {product.price.toFixed(2).replace('.', ',')}
          </span>
          <span className={`px-2 py-1 text-xs font-medium rounded-full ${getConditionColor(product.condition)}`}>
            {product.condition}
          </span>
        </div>

        {/* Title */}
        <h3 className="font-medium text-gray-900 mb-2 line-clamp-2 text-sm">
          {product.title}
        </h3>

        {/* Location */}
        <div className="flex items-center space-x-1 mb-2">
          <MapPin size={12} className="text-gray-400" />
          <span className="text-xs text-gray-500">{product.location || 'Juiz de Fora, MG'}</span>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between">
          <span className="text-xs text-gray-500">
            {formatDistanceToNow(new Date(product.created_at), { locale: ptBR, addSuffix: true })}
          </span>
          
          <motion.button
            onClick={handleLike}
            className={`flex items-center space-x-1 ${
              liked ? 'text-red-500' : 'text-gray-400 hover:text-red-500'
            }`}
            whilePressed={{ scale: 0.95 }}
          >
            <Heart size={14} fill={liked ? 'currentColor' : 'none'} />
            <span className="text-xs">{product.likes_count}</span>
          </motion.button>
        </div>
      </div>
    </motion.div>
  )
}
