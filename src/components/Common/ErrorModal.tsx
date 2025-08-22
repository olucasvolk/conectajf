import React from 'react'
import { X, AlertTriangle } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface ErrorModalProps {
  isOpen: boolean
  onClose: () => void
  error: string | null
}

export function ErrorModal({ isOpen, onClose, error }: ErrorModalProps) {
  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="absolute inset-0 bg-black bg-opacity-60"
          />

          {/* Modal */}
          <motion.div
            initial={{ opacity: 0, y: 50, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 50, scale: 0.9 }}
            className="relative bg-white rounded-2xl w-full max-w-sm mx-auto overflow-hidden shadow-2xl"
          >
            <div className="p-6 text-center">
              <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100 mb-4">
                <AlertTriangle className="h-6 w-6 text-red-600" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 mb-2">Ocorreu um Erro</h3>
              <p className="text-sm text-gray-600 mb-4 break-words">
                {error || 'Algo deu errado. Por favor, tente novamente.'}
              </p>
              <motion.button
                onClick={onClose}
                className="w-full bg-red-500 text-white py-2.5 rounded-lg font-medium hover:bg-red-600"
                whileTap={{ scale: 0.95 }}
              >
                Fechar
              </motion.button>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  )
}
