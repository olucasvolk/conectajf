import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search, ArrowLeft, Loader2 } from 'lucide-react'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'
import { getOrCreateChatRoom } from '../../utils/chat'
import { LoadingSpinner } from '../Common/LoadingSpinner'

export function NewChatScreen() {
  const [users, setUsers] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [creatingChat, setCreatingChat] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const { user } = useAuth()
  const navigate = useNavigate()

  useEffect(() => {
    const fetchUsers = async () => {
      if (!user) return
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select('*')
          .not('id', 'eq', user.id) // Exclude current user

        if (error) throw error
        setUsers(data || [])
      } catch (error) {
        console.error('Error fetching users:', error)
      } finally {
        setLoading(false)
      }
    }
    fetchUsers()
  }, [user])

  const handleUserClick = async (otherUserId: string) => {
    if (!user) return
    setCreatingChat(true)
    try {
      const roomId = await getOrCreateChatRoom(user.id, otherUserId)
      if (roomId) {
        navigate(`/chat/${roomId}`)
      } else {
        throw new Error('Could not create or find chat room.')
      }
    } catch (error) {
      console.error('Error handling user click:', error)
      alert('Não foi possível iniciar a conversa. Tente novamente.')
    } finally {
      setCreatingChat(false)
    }
  }

  const filteredUsers = users.filter(u =>
    u.full_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    u.username?.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      {/* Header */}
      <div className="sticky top-0 bg-white border-b border-gray-200 p-4 z-10">
        <div className="flex items-center space-x-2 mb-4">
          <button onClick={() => navigate(-1)} className="p-2 -ml-2 rounded-full hover:bg-gray-100">
            <ArrowLeft size={20} className="text-gray-600" />
          </button>
          <h1 className="text-xl font-bold text-gray-900">Nova Conversa</h1>
        </div>
        <div className="relative">
          <Search size={20} className="absolute left-3 top-3 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar usuários..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* User List */}
      <div className="flex-1 overflow-y-auto">
        {loading ? (
          <div className="flex justify-center py-12">
            <LoadingSpinner text="Carregando usuários..." />
          </div>
        ) : (
          <div className="divide-y divide-gray-100">
            {filteredUsers.map(u => (
              <button
                key={u.id}
                onClick={() => handleUserClick(u.id)}
                disabled={creatingChat}
                className="w-full flex items-center space-x-3 p-4 hover:bg-gray-100 text-left disabled:opacity-50"
              >
                <div className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center text-gray-600 font-medium">
                  {u.avatar_url ? (
                    <img src={u.avatar_url} alt={u.full_name} className="w-10 h-10 rounded-full object-cover" />
                  ) : (
                    u.full_name?.charAt(0) || 'U'
                  )}
                </div>
                <div className="flex-1">
                  <p className="font-medium text-gray-900">{u.full_name}</p>
                  <p className="text-sm text-gray-500">@{u.username}</p>
                </div>
                {creatingChat && <Loader2 className="animate-spin text-gray-500" />}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
