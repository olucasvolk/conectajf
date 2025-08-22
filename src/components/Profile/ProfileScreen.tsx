import React, { useState, useEffect } from 'react'
import { Settings, Edit, Heart, MessageSquare, ShoppingBag, LogOut, BarChart3, TrendingUp, MapPin, Phone } from 'lucide-react'
import { motion } from 'framer-motion'
import { useAuth } from '../../contexts/AuthContext'
import { supabase } from '../../lib/supabase'
import { seedDatabase } from '../../utils/sampleData'

export function ProfileScreen() {
  const { user, profile, signOut } = useAuth()
  const [stats, setStats] = useState({
    newsCount: 0,
    productsCount: 0,
    likesReceived: 0
  })
  const [loading, setLoading] = useState(true)
  const [seeding, setSeeding] = useState(false)

  useEffect(() => {
    if (user) {
      fetchUserStats()
    }
  }, [user])

  const fetchUserStats = async () => {
    if (!user) return

    try {
      // Get news count
      const { count: newsCount } = await supabase
        .from('news_posts')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)

      // Get products count
      const { count: productsCount } = await supabase
        .from('marketplace_products')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)

      // Get total likes received on user's posts and products
      const { data: newsLikes } = await supabase
        .from('post_likes')
        .select('id')
        .in('post_id', 
          (await supabase
            .from('news_posts')
            .select('id')
            .eq('user_id', user.id)
          ).data?.map(p => p.id) || []
        )

      const { data: productLikes } = await supabase
        .from('post_likes')
        .select('id')
        .in('product_id',
          (await supabase
            .from('marketplace_products')
            .select('id')
            .eq('user_id', user.id)
          ).data?.map(p => p.id) || []
        )

      setStats({
        newsCount: newsCount || 0,
        productsCount: productsCount || 0,
        likesReceived: (newsLikes?.length || 0) + (productLikes?.length || 0)
      })
    } catch (error) {
      console.error('Error fetching user stats:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleSignOut = async () => {
    try {
      await signOut()
    } catch (error) {
      console.error('Error signing out:', error)
    }
  }

  const handleGenerateSampleData = async () => {
    if (!user) return
    
    setSeeding(true)
    try {
      const success = await seedDatabase(user.id)
      if (success) {
        alert('Dados de exemplo criados com sucesso! Verifique o feed e marketplace.')
        await fetchUserStats()
      } else {
        alert('Erro ao criar dados de exemplo.')
      }
    } catch (error) {
      console.error('Error generating sample data:', error)
      alert('Erro ao criar dados de exemplo.')
    } finally {
      setSeeding(false)
    }
  }

  const menuItems = [
    {
      icon: Edit,
      label: 'Editar perfil',
      action: () => console.log('Edit profile'),
      color: 'text-blue-600'
    },
    {
      icon: MessageSquare,
      label: 'Minhas notícias',
      action: () => console.log('My news'),
      color: 'text-green-600'
    },
    {
      icon: ShoppingBag,
      label: 'Meus produtos',
      action: () => console.log('My products'),
      color: 'text-purple-600'
    },
    {
      icon: Heart,
      label: 'Curtidas',
      action: () => console.log('View likes'),
      color: 'text-red-600'
    },
    {
      icon: BarChart3,
      label: 'Gerar dados de exemplo',
      action: handleGenerateSampleData,
      color: 'text-orange-600'
    },
    {
      icon: Settings,
      label: 'Configurações',
      action: () => console.log('Settings'),
      color: 'text-gray-600'
    },
    {
      icon: LogOut,
      label: 'Sair da conta',
      action: handleSignOut,
      destructive: true,
      color: 'text-red-600'
    }
  ]

  return (
    <div className="pb-20 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="bg-gradient-to-br from-blue-500 via-purple-600 to-indigo-700 text-white p-6 relative overflow-hidden">
        <div className="absolute inset-0 bg-black bg-opacity-10"></div>
        <div className="relative z-10">
          <div className="flex items-center space-x-4 mb-4">
            <div className="w-20 h-20 bg-white bg-opacity-20 rounded-full flex items-center justify-center backdrop-blur-sm border-2 border-white border-opacity-30">
              {profile?.avatar_url ? (
                <img 
                  src={profile.avatar_url} 
                  alt={profile.full_name}
                  className="w-20 h-20 rounded-full object-cover"
                />
              ) : (
                <span className="text-2xl font-bold">
                  {profile?.full_name?.charAt(0) || 'U'}
                </span>
              )}
            </div>
            <div className="flex-1">
              <h1 className="text-xl font-bold">{profile?.full_name || 'Usuário'}</h1>
              <p className="text-blue-100 text-sm">@{profile?.username || 'username'}</p>
              <div className="flex items-center space-x-4 mt-1">
                <span className="text-blue-100 text-sm flex items-center space-x-1">
                  <MapPin size={14} />
                  <span>{profile?.location || 'Juiz de Fora, MG'}</span>
                </span>
                {profile?.phone && (
                  <span className="text-blue-100 text-sm flex items-center space-x-1">
                    <Phone size={14} />
                    <span>{profile.phone}</span>
                  </span>
                )}
              </div>
            </div>
          </div>

          {profile?.bio && (
            <p className="text-blue-100 text-sm leading-relaxed">{profile.bio}</p>
          )}
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 p-6 bg-white border-b border-gray-200 -mt-2 mx-4 rounded-t-2xl shadow-sm">
        <motion.div 
          className="text-center"
          whileHover={{ scale: 1.05 }}
        >
          <div className="flex items-center justify-center space-x-1 mb-1">
            <MessageSquare size={16} className="text-blue-500" />
            <p className="text-2xl font-bold text-gray-900">{loading ? '...' : stats.newsCount}</p>
          </div>
          <p className="text-sm text-gray-500">Notícias</p>
        </motion.div>
        
        <motion.div 
          className="text-center"
          whileHover={{ scale: 1.05 }}
        >
          <div className="flex items-center justify-center space-x-1 mb-1">
            <ShoppingBag size={16} className="text-green-500" />
            <p className="text-2xl font-bold text-gray-900">{loading ? '...' : stats.productsCount}</p>
          </div>
          <p className="text-sm text-gray-500">Produtos</p>
        </motion.div>
        
        <motion.div 
          className="text-center"
          whileHover={{ scale: 1.05 }}
        >
          <div className="flex items-center justify-center space-x-1 mb-1">
            <Heart size={16} className="text-red-500" />
            <p className="text-2xl font-bold text-gray-900">{loading ? '...' : stats.likesReceived}</p>
          </div>
          <p className="text-sm text-gray-500">Curtidas</p>
        </motion.div>
      </div>

      {/* Quick Actions */}
      <div className="p-4">
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
          <div className="p-4 border-b border-gray-100">
            <h2 className="font-semibold text-gray-900">Ações rápidas</h2>
          </div>
          <div className="divide-y divide-gray-100">
            {menuItems.map((item, index) => {
              const Icon = item.icon
              return (
                <motion.button
                  key={index}
                  onClick={item.action}
                  disabled={seeding && item.label === 'Gerar dados de exemplo'}
                  className={`w-full flex items-center space-x-3 p-4 hover:bg-gray-50 text-left transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                    item.destructive ? 'hover:bg-red-50' : ''
                  }`}
                  whilePressed={{ scale: 0.98 }}
                >
                  <div className={`p-2 rounded-lg ${
                    item.destructive 
                      ? 'bg-red-100' 
                      : index % 2 === 0 
                        ? 'bg-blue-100' 
                        : 'bg-gray-100'
                  }`}>
                    <Icon size={18} className={item.color} />
                  </div>
                  <div className="flex-1">
                    <span className={`font-medium ${item.destructive ? 'text-red-600' : 'text-gray-900'}`}>
                      {item.label}
                    </span>
                    {item.label === 'Gerar dados de exemplo' && (
                      <p className="text-xs text-gray-500 mt-0.5">
                        Cria notícias e produtos para o seu usuário.
                      </p>
                    )}
                  </div>
                  {seeding && item.label === 'Gerar dados de exemplo' && (
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-orange-500"></div>
                  )}
                </motion.button>
              )
            })}
          </div>
        </div>
      </div>

      {/* App Info */}
      <div className="p-4 text-center">
        <div className="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div className="flex items-center justify-center space-x-2 mb-2">
            <TrendingUp size={16} className="text-blue-500" />
            <p className="text-sm font-medium text-gray-900">JF Notícias v1.0.0</p>
          </div>
          <p className="text-xs text-gray-500">
            Desenvolvido com ❤️ para conectar Juiz de Fora
          </p>
        </div>
      </div>
    </div>
  )
}
