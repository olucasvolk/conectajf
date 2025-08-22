import React, { useState } from 'react'
import { Camera, Loader2, X } from 'lucide-react'
import { motion } from 'framer-motion'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'

interface CreateProductFormProps {
  onSuccess: () => void
}

export function CreateProductForm({ onSuccess }: CreateProductFormProps) {
  const { user, profile } = useAuth()
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    price: '',
    condition: 'usado',
    category: 'outros'
  })
  const [phone, setPhone] = useState(profile?.phone || '')
  const [loading, setLoading] = useState(false)
  const [mediaFiles, setMediaFiles] = useState<File[]>([])

  const conditions = [
    { id: 'novo', label: 'Novo' },
    { id: 'seminovo', label: 'Seminovo' },
    { id: 'usado', label: 'Usado' }
  ]

  const categories = [
    { id: 'eletrônicos', label: 'Eletrônicos' },
    { id: 'móveis', label: 'Móveis' },
    { id: 'roupas', label: 'Roupas' },
    { id: 'veículos', label: 'Veículos' },
    { id: 'casa', label: 'Casa & Jardim' },
    { id: 'esportes', label: 'Esportes' },
    { id: 'livros', label: 'Livros' },
    { id: 'instrumentos', label: 'Instrumentos' },
    { id: 'outros', label: 'Outros' }
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
      alert('Não foi possível criar o produto. Seu perfil de usuário não foi encontrado ou está incompleto. Por favor, tente fazer login novamente.')
      return
    }

    setLoading(true)
    try {
      // Step 1: Update user's phone number if it's new or changed
      if (phone && phone !== profile.phone) {
        const { error: phoneError } = await supabase
          .from('profiles')
          .update({ phone: phone })
          .eq('id', user.id)
        
        if (phoneError) {
          // Don't block product creation, just log the error
          console.error('Could not update phone number:', phoneError)
        }
      }

      // Step 2: Insert the product
      const { data, error } = await supabase
        .from('marketplace_products')
        .insert([{
          user_id: user.id,
          title: formData.title,
          description: formData.description,
          price: parseFloat(formData.price),
          condition: formData.condition as 'novo' | 'usado' | 'seminovo',
          category: formData.category
        }])
        .select()
        .single()

      if (error) throw error

      // TODO: Upload media files to Supabase Storage
      // For now, we'll skip media upload

      onSuccess()
    } catch (error) {
      console.error('Error creating product:', error)
      alert('Erro ao criar produto. Tente novamente.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="p-6 space-y-6">
      {/* Title */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Título do produto
        </label>
        <input
          type="text"
          value={formData.title}
          onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
          placeholder="Ex: iPhone 13 128GB..."
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          required
        />
      </div>

      {/* Price */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Preço (R$)
        </label>
        <input
          type="number"
          step="0.01"
          min="0"
          value={formData.price}
          onChange={(e) => setFormData(prev => ({ ...prev, price: e.target.value }))}
          placeholder="0,00"
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          required
        />
      </div>

      {/* Condition and Category */}
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Condição
          </label>
          <select
            value={formData.condition}
            onChange={(e) => setFormData(prev => ({ ...prev, condition: e.target.value }))}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            {conditions.map((condition) => (
              <option key={condition.id} value={condition.id}>
                {condition.label}
              </option>
            ))}
          </select>
        </div>

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
      </div>

      {/* Description */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Descrição
        </label>
        <textarea
          value={formData.description}
          onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
          placeholder="Descreva o produto, estado de conservação, motivo da venda..."
          rows={4}
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
          required
        />
      </div>

      {/* Phone Number */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Telefone para contato (WhatsApp)
        </label>
        <input
          type="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="(XX) 9XXXX-XXXX"
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          required
        />
        <p className="text-xs text-gray-500 mt-1">
          Seu número será compartilhado apenas com compradores interessados.
        </p>
      </div>

      {/* Media Upload */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Fotos do produto (até 7 arquivos)
        </label>
        
        <input
          type="file"
          multiple
          accept="image/*,video/*"
          onChange={handleMediaUpload}
          className="hidden"
          id="product-media-upload"
        />
        
        <label
          htmlFor="product-media-upload"
          className="flex items-center justify-center w-full h-32 border-2 border-dashed border-gray-300 rounded-lg hover:border-gray-400 cursor-pointer"
        >
          <div className="text-center">
            <Camera size={32} className="mx-auto text-gray-400 mb-2" />
            <p className="text-sm text-gray-500">Toque para adicionar fotos</p>
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
        className="w-full bg-green-500 text-white py-3 rounded-lg font-medium hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
        whilePressed={{ scale: 0.98 }}
      >
        {loading ? (
          <Loader2 className="animate-spin" size={20} />
        ) : (
          'Publicar Produto'
        )}
      </motion.button>
    </form>
  )
}
