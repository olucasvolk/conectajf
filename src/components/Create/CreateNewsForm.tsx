import React, { useState } from 'react'
import { Camera, Loader2, X } from 'lucide-react'
import { motion } from 'framer-motion'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'

interface CreateNewsFormProps {
  onSuccess: () => void
}

export function CreateNewsForm({ onSuccess }: CreateNewsFormProps) {
  const [formData, setFormData] = useState({
    title: '',
    content: '',
    category: 'geral'
  })
  const [loading, setLoading] = useState(false)
  const [mediaFiles, setMediaFiles] = useState<File[]>([])
  const { user, profile } = useAuth()

  const categories = [
    { id: 'geral', label: 'Geral' },
    { id: 'política', label: 'Política' },
    { id: 'economia', label: 'Economia' },
    { id: 'esportes', label: 'Esportes' },
    { id: 'cultura', label: 'Cultura' },
    { id: 'saúde', label: 'Saúde' },
    { id: 'educação', label: 'Educação' },
    { id: 'segurança', label: 'Segurança' },
    { id: 'trânsito', label: 'Trânsito' },
    { id: 'clima', label: 'Clima' }
  ]

  const handleMediaUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || [])
    if (mediaFiles.length + files.length > 7) {
      alert('Máximo de 7 arquivos permitidos')
      return
    }
    setMediaFiles(prev => [...prev, ...files])
  }

  const removeMedia = (index: number) => {
    setMediaFiles(prev => prev.filter((_, i) => i !== index))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user || !profile) {
      alert('Não foi possível criar a notícia. Seu perfil de usuário não foi encontrado ou está incompleto. Por favor, tente fazer login novamente.')
      return
    }

    setLoading(true)
    try {
      const { data, error } = await supabase
        .from('news_posts')
        .insert([{
          user_id: user.id,
          title: formData.title,
          content: formData.content,
          category: formData.category
        }])
        .select()
        .single()

      if (error) throw error

      // TODO: Upload media files to Supabase Storage
      // For now, we'll skip media upload

      onSuccess()
    } catch (error) {
      console.error('Error creating post:', error)
      alert('Erro ao criar notícia. Tente novamente.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="p-6 space-y-6">
      {/* Category */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Categoria
        </label>
        <select
          value={formData.category}
          onChange={(e) => setFormData(prev => ({ ...prev, category: e.target.value }))}
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        >
          {categories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.label}
            </option>
          ))}
        </select>
      </div>

      {/* Title */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Título da notícia
        </label>
        <input
          type="text"
          value={formData.title}
          onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
          placeholder="Digite o título da notícia..."
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          required
        />
      </div>

      {/* Content */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Conteúdo
        </label>
        <textarea
          value={formData.content}
          onChange={(e) => setFormData(prev => ({ ...prev, content: e.target.value }))}
          placeholder="Escreva o conteúdo da notícia..."
          rows={6}
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
          required
        />
      </div>

      {/* Media Upload */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Fotos e vídeos (até 7 arquivos)
        </label>
        
        <input
          type="file"
          multiple
          accept="image/*,video/*"
          onChange={handleMediaUpload}
          className="hidden"
          id="media-upload"
        />
        
        <label
          htmlFor="media-upload"
          className="flex items-center justify-center w-full h-32 border-2 border-dashed border-gray-300 rounded-lg hover:border-gray-400 cursor-pointer"
        >
          <div className="text-center">
            <Camera size={32} className="mx-auto text-gray-400 mb-2" />
            <p className="text-sm text-gray-500">Toque para adicionar fotos/vídeos</p>
          </div>
        </label>

        {/* Media Preview */}
        {mediaFiles.length > 0 && (
          <div className="grid grid-cols-3 gap-2 mt-4">
            {mediaFiles.map((file, index) => (
              <div key={index} className="relative">
                <div className="aspect-square bg-gray-100 rounded-lg flex items-center justify-center">
                  {file.type.startsWith('image/') ? (
                    <img
                      src={URL.createObjectURL(file)}
                      alt={`Upload ${index + 1}`}
                      className="w-full h-full object-cover rounded-lg"
                    />
                  ) : (
                    <span className="text-2xl">🎥</span>
                  )}
                </div>
                <button
                  type="button"
                  onClick={() => removeMedia(index)}
                  className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1"
                >
                  <X size={12} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Submit */}
      <motion.button
        type="submit"
        disabled={loading}
        className="w-full bg-blue-500 text-white py-3 rounded-lg font-medium hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
        whilePressed={{ scale: 0.98 }}
      >
        {loading ? (
          <Loader2 className="animate-spin" size={20} />
        ) : (
          'Publicar Notícia'
        )}
      </motion.button>
    </form>
  )
}
