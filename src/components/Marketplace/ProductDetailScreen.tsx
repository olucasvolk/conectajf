import React, { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, MessageCircle, Loader2, AlertTriangle } from 'lucide-react'
import { motion } from 'framer-motion'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { LoadingSpinner } from '../Common/LoadingSpinner'
import { getOrCreateChatRoom } from '../../utils/chat'
import { formatDistanceToNow } from 'date-fns'
import { ptBR } from 'date-fns/locale'

// A simple SVG for WhatsApp icon
const WhatsAppIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
    <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.894 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01s-.521.074-.792.372c-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.626.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z"/>
  </svg>
)

type Product = {
  id: string;
  title: string;
  description: string;
  price: number;
  condition: string;
  category: string;
  location?: string;
  created_at: string;
  profiles: {
    id: string;
    username: string;
    full_name: string;
    avatar_url?: string;
    phone?: string;
  } | null;
}

export function ProductDetailScreen() {
  const { productId } = useParams<{ productId: string }>()
  const navigate = useNavigate()
  const { user } = useAuth()

  const [product, setProduct] = useState<Product | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actionLoading, setActionLoading] = useState(false)

  useEffect(() => {
    const fetchProduct = async () => {
      if (!productId) return
      setLoading(true)
      setError(null)

      try {
        const { data, error: fetchError } = await supabase
          .from('marketplace_products')
          .select(`
            *,
            profiles!marketplace_products_user_id_fkey (
              id,
              username,
              full_name,
              avatar_url,
              phone
            )
          `)
          .eq('id', productId)
          .single()

        if (fetchError) throw fetchError
        setProduct(data)
      } catch (err: any) {
        console.error('Error fetching product details:', err)
        setError('Não foi possível carregar o produto. Tente novamente mais tarde.')
      } finally {
        setLoading(false)
      }
    }

    fetchProduct()
  }, [productId])

  const handleChatClick = async () => {
    if (!user || !product?.profiles?.id) return
    if (user.id === product.profiles.id) {
      alert("Você não pode iniciar uma conversa com você mesmo.")
      return
    }

    setActionLoading(true)
    try {
      const roomId = await getOrCreateChatRoom(user.id, product.profiles.id)
      if (roomId) {
        navigate(`/chat/${roomId}`)
      } else {
        throw new Error('Não foi possível criar ou encontrar a sala de chat.')
      }
    } catch (err) {
      console.error('Error starting chat:', err)
      alert('Não foi possível iniciar a conversa.')
    } finally {
      setActionLoading(false)
    }
  }

  const handleWhatsAppClick = () => {
    if (!product?.profiles?.phone) {
      alert('O vendedor não forneceu um número de WhatsApp.')
      return
    }
    const phoneNumber = product.profiles.phone.replace(/\D/g, '')
    const message = encodeURIComponent(`Olá, ${product.profiles.full_name}! Vi seu produto "${product.title}" no JF Notícias e tenho interesse.`)
    const whatsappUrl = `https://wa.me/55${phoneNumber}?text=${message}`
    window.open(whatsappUrl, '_blank')
  }

  const getConditionColor = (condition?: string) => {
    switch (condition) {
      case 'novo': return 'bg-green-100 text-green-800'
      case 'seminovo': return 'bg-yellow-100 text-yellow-800'
      case 'usado': return 'bg-gray-100 text-gray-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <LoadingSpinner size="lg" text="Carregando produto..." />
      </div>
    )
  }

  if (error || !product) {
    return (
      <div className="flex flex-col items-center justify-center h-screen p-4 text-center">
        <AlertTriangle size={48} className="text-red-500 mb-4" />
        <h2 className="text-xl font-bold mb-2">Erro ao carregar</h2>
        <p className="text-gray-600">{error || 'Produto não encontrado.'}</p>
        <button onClick={() => navigate('/marketplace')} className="mt-6 bg-blue-500 text-white px-6 py-2 rounded-lg">
          Voltar ao Marketplace
        </button>
      </div>
    )
  }

  return (
    <div className="bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="sticky top-0 bg-white border-b border-gray-200 p-4 flex items-center space-x-4 z-10 shadow-sm">
        <button onClick={() => navigate(-1)} className="p-2 -ml-2 rounded-full hover:bg-gray-100">
          <ArrowLeft size={20} className="text-gray-600" />
        </button>
        <h1 className="font-bold text-gray-900 truncate flex-1">{product.title}</h1>
      </div>

      <div className="p-4 pb-24">
        {/* Image Carousel Placeholder */}
        <div className="aspect-square bg-gray-200 rounded-xl mb-4 flex items-center justify-center">
          <span className="text-6xl text-gray-400">📷</span>
        </div>

        {/* Product Info */}
        <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
          <div className="flex justify-between items-start mb-2">
            <span className={`px-3 py-1 text-sm font-medium rounded-full ${getConditionColor(product.condition)}`}>
              {product.condition}
            </span>
            <span className="text-2xl font-bold text-green-600">
              R$ {product.price.toFixed(2).replace('.', ',')}
            </span>
          </div>

          <h2 className="text-2xl font-bold text-gray-900 mb-4">{product.title}</h2>
          <p className="text-gray-700 leading-relaxed mb-4">{product.description}</p>

          <div className="text-sm text-gray-500 space-y-2 border-t border-gray-100 pt-4">
            <p><strong>Categoria:</strong> {product.category}</p>
            <p><strong>Localização:</strong> {product.location || 'Juiz de Fora, MG'}</p>
            <p><strong>Publicado:</strong> {formatDistanceToNow(new Date(product.created_at), { locale: ptBR, addSuffix: true })}</p>
          </div>
        </div>

        {/* Seller Info */}
        <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100 mt-4">
          <h3 className="font-bold text-gray-800 mb-3">Informações do Vendedor</h3>
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 bg-gray-200 rounded-full">
              {product.profiles?.avatar_url ? (
                <img src={product.profiles.avatar_url} alt={product.profiles.full_name} className="w-12 h-12 rounded-full object-cover" />
              ) : (
                <div className="w-12 h-12 rounded-full bg-blue-500 flex items-center justify-center text-white font-bold text-lg">
                  {product.profiles?.full_name?.charAt(0)}
                </div>
              )}
            </div>
            <div>
              <p className="font-semibold text-gray-900">{product.profiles?.full_name}</p>
              <p className="text-sm text-gray-500">@{product.profiles?.username}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 p-4 flex items-center space-x-3 z-10">
        <motion.button
          onClick={handleWhatsAppClick}
          disabled={!product.profiles?.phone || actionLoading}
          className="flex-1 flex items-center justify-center bg-green-500 text-white py-3 rounded-lg font-medium hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed space-x-2"
          whileTap={{ scale: 0.98 }}
        >
          <WhatsAppIcon />
          <span>WhatsApp</span>
        </motion.button>
        <motion.button
          onClick={handleChatClick}
          disabled={actionLoading || user?.id === product.profiles?.id}
          className="flex-1 flex items-center justify-center bg-blue-500 text-white py-3 rounded-lg font-medium hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed space-x-2"
          whileTap={{ scale: 0.98 }}
        >
          {actionLoading ? <Loader2 className="animate-spin" /> : <MessageCircle size={20} />}
          <span>Chat</span>
        </motion.button>
      </div>
    </div>
  )
}
