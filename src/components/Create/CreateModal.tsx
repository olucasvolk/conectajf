import React, { useState } from 'react'
import { X, Camera, Type, ShoppingBag } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { CreateNewsForm } from './CreateNewsForm'
import { CreateProductForm } from './CreateProductForm'

interface CreateModalProps {
  isOpen: boolean
  onClose: () => void
}

export function CreateModal({ isOpen, onClose }: CreateModalProps) {
  const [createType, setCreateType] = useState<'news' | 'product' | null>(null)

  const handleClose = () => {
    setCreateType(null)
    onClose()
  }

  const createOptions = [
    {
      id: 'news',
      title: 'Notícia',
      subtitle: 'Compartilhe uma notícia local',
      icon: Type,
      color: 'bg-blue-500'
    },
    {
      id: 'product',
      title: 'Produto',
      subtitle: 'Venda um produto no marketplace',
      icon: ShoppingBag,
      color: 'bg-green-500'
    }
  ]

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={handleClose}
            className="absolute inset-0 bg-black bg-opacity-50"
          />

          {/* Modal */}
          <motion.div
            initial={{ opacity: 0, y: 100, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 100, scale: 0.95 }}
            className="relative bg-white rounded-t-3xl sm:rounded-2xl w-full sm:max-w-md mx-4 max-h-[90vh] overflow-hidden"
          >
            {/* Header */}
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h2 className="text-xl font-bold text-gray-900">
                {createType ? (createType === 'news' ? 'Nova Notícia' : 'Novo Produto') : 'Criar'}
              </h2>
              <button
                onClick={handleClose}
                className="p-2 rounded-full hover:bg-gray-100"
              >
                <X size={20} className="text-gray-500" />
              </button>
            </div>

            {/* Content */}
            <div className="max-h-[calc(90vh-80px)] overflow-y-auto">
              {!createType ? (
                <div className="p-6 space-y-4">
                  {createOptions.map((option) => {
                    const Icon = option.icon
                    return (
                      <motion.button
                        key={option.id}
                        onClick={() => setCreateType(option.id as 'news' | 'product')}
                        className="w-full flex items-center space-x-4 p-4 rounded-xl border border-gray-200 hover:border-gray-300 hover:bg-gray-50"
                        whilePressed={{ scale: 0.98 }}
                      >
                        <div className={`p-3 rounded-full ${option.color} text-white`}>
                          <Icon size={24} />
                        </div>
                        <div className="text-left">
                          <h3 className="font-medium text-gray-900">{option.title}</h3>
                          <p className="text-sm text-gray-500">{option.subtitle}</p>
                        </div>
                      </motion.button>
                    )
                  })}
                </div>
              ) : createType === 'news' ? (
                <CreateNewsForm onSuccess={handleClose} />
              ) : (
                <CreateProductForm onSuccess={handleClose} />
              )}
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  )
}
