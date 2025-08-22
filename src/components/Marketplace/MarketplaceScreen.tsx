import React, { useState, useEffect, useCallback } from 'react'
import { Search, Filter, MapPin, SlidersHorizontal } from 'lucide-react'
import { motion } from 'framer-motion'
import { ProductCard } from './ProductCard'
import { LoadingSpinner } from '../Common/LoadingSpinner'
import { EmptyState } from '../Common/EmptyState'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'

export function MarketplaceScreen() {
  const [products, setProducts] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('todos')
  const [selectedCondition, setSelectedCondition] = useState('todos')
  const [userLikes, setUserLikes] = useState<Set<string>>(new Set())
  const { user } = useAuth()

  const categories = [
    { id: 'todos', label: 'Todos', icon: '🏪' },
    { id: 'eletrônicos', label: 'Eletrônicos', icon: '📱' },
    { id: 'móveis', label: 'Móveis', icon: '🛋️' },
    { id: 'roupas', label: 'Roupas', icon: '👕' },
    { id: 'veículos', label: 'Veículos', icon: '🚗' },
    { id: 'casa', label: 'Casa', icon: '🏠' },
    { id: 'esportes', label: 'Esportes', icon: '⚽' },
    { id: 'livros', label: 'Livros', icon: '📚' },
    { id: 'outros', label: 'Outros', icon: '📦' }
  ]

  const conditions = [
    { id: 'todos', label: 'Todas' },
    { id: 'novo', label: 'Novo' },
    { id: 'seminovo', label: 'Seminovo' },
    { id: 'usado', label: 'Usado' }
  ]

  const fetchProductsAndLikes = useCallback(async () => {
    try {
      let query = supabase
        .from('marketplace_products')
        .select(`
          id,
          title,
          description,
          price,
          condition,
          category,
          location,
          is_available,
          likes_count,
          created_at,
          profiles!marketplace_products_user_id_fkey (
            username,
            full_name,
            avatar_url
          )
        `)
        .eq('is_available', true)
        .order('created_at', { ascending: false })

      if (selectedCategory !== 'todos') {
        query = query.eq('category', selectedCategory)
      }

      if (selectedCondition !== 'todos') {
        query = query.eq('condition', selectedCondition)
      }

      if (searchTerm) {
        query = query.ilike('title', `%${searchTerm}%`)
      }

      const { data, error } = await query.limit(50)

      if (error) throw error
      setProducts(data || [])

      if (user) {
        const { data: likeData, error: likeError } = await supabase
          .from('post_likes')
          .select('product_id')
          .eq('user_id', user.id)
          .not('product_id', 'is', null) // FIX: Correctly check for non-null product_id

        if (likeError) throw likeError
        const likedProductIds = new Set(likeData.map(like => like.product_id).filter(Boolean) as string[])
        setUserLikes(likedProductIds)
      }

    } catch (error) {
      console.error('Error fetching products:', error)
    } finally {
      setLoading(false)
    }
  }, [user, selectedCategory, selectedCondition, searchTerm])

  useEffect(() => {
    fetchProductsAndLikes()
  }, [fetchProductsAndLikes])

  const handleLike = async (productId: string) => {
    if (!user) return

    const isLiked = userLikes.has(productId)

    const newLikes = new Set(userLikes)
    if (isLiked) {
      newLikes.delete(productId)
    } else {
      newLikes.add(productId)
    }
    setUserLikes(newLikes)

    setProducts(prev => prev.map(product => 
      product.id === productId 
        ? { ...product, likes_count: isLiked ? Math.max(0, product.likes_count - 1) : product.likes_count + 1 }
        : product
    ))

    try {
      if (isLiked) {
        await supabase
          .from('post_likes')
          .delete()
          .eq('product_id', productId)
          .eq('user_id', user.id)
      } else {
        await supabase
          .from('post_likes')
          .insert([{ product_id: productId, user_id: user.id }])
      }
    } catch (error) {
      console.error('Error toggling like, reverting UI:', error)
      setUserLikes(userLikes)
      setProducts(products)
    }
  }

  return (
    <div className="pb-20 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="sticky top-0 bg-white border-b border-gray-200 p-4 z-10 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <h1 className="text-xl font-bold text-gray-900">🛍️ Marketplace</h1>
          <button className="p-2 rounded-full hover:bg-gray-100">
            <SlidersHorizontal size={20} className="text-gray-600" />
          </button>
        </div>

        {/* Search */}
        <div className="relative mb-4">
          <Search size={20} className="absolute left-3 top-3 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar produtos em Juiz de Fora..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>

        {/* Categories */}
        <div className="flex space-x-2 overflow-x-auto pb-2 mb-3">
          {categories.map((category) => (
            <motion.button
              key={category.id}
              onClick={() => setSelectedCategory(category.id)}
              className={`flex items-center space-x-1 px-3 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
                selectedCategory === category.id
                  ? 'bg-blue-500 text-white'
                  : 'bg-white text-gray-700 hover:bg-gray-100 border border-gray-200'
              }`}
              whilePressed={{ scale: 0.95 }}
            >
              <span>{category.icon}</span>
              <span>{category.label}</span>
            </motion.button>
          ))}
        </div>

        {/* Conditions */}
        <div className="flex space-x-2 overflow-x-auto pb-2">
          {conditions.map((condition) => (
            <motion.button
              key={condition.id}
              onClick={() => setSelectedCondition(condition.id)}
              className={`px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-colors ${
                selectedCondition === condition.id
                  ? 'bg-green-500 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
              whilePressed={{ scale: 0.95 }}
            >
              {condition.label}
            </motion.button>
          ))}
        </div>
      </div>

      {/* Location Banner */}
      <div className="px-4 py-3 bg-blue-50 border-b border-blue-100">
        <div className="flex items-center justify-center space-x-2">
          <MapPin size={16} className="text-blue-600" />
          <span className="text-sm text-blue-700 font-medium">📍 Juiz de Fora, MG</span>
        </div>
      </div>

      {/* Products Grid */}
      <div className="p-4">
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <LoadingSpinner size="lg" text="Carregando produtos..." />
          </div>
        ) : products.length === 0 ? (
          <EmptyState
            icon="🛍️"
            title="Nenhum produto encontrado"
            description="Tente ajustar sua busca ou categoria, ou seja o primeiro a vender algo!"
            action={{
              label: "Vender primeiro produto",
              onClick: () => console.log('Create first product')
            }}
          />
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {products.map((product, index) => (
              <motion.div
                key={product.id}
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: index * 0.05 }}
              >
                <ProductCard
                  product={product}
                  isLiked={userLikes.has(product.id)}
                  onLike={handleLike}
                />
              </motion.div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
