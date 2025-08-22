import React from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import { Home, ShoppingBag, Plus, MessageCircle, User } from 'lucide-react'
import { motion } from 'framer-motion'

interface BottomNavigationProps {
  onCreatePost: () => void
}

export function BottomNavigation({ onCreatePost }: BottomNavigationProps) {
  const location = useLocation();
  const tabs = [
    { id: 'feed', icon: Home, label: 'Feed', path: '/' },
    { id: 'marketplace', icon: ShoppingBag, label: 'Marketplace', path: '/marketplace' },
    { id: 'create', icon: Plus, label: 'Criar', isCreate: true },
    { id: 'chat', icon: MessageCircle, label: 'Chat', path: '/chat' },
    { id: 'profile', icon: User, label: 'Perfil', path: '/profile' }
  ]

  // Hide navigation on specific sub-routes like a chat room or product detail
  const isDetailPage = location.pathname.startsWith('/chat/') || (location.pathname.startsWith('/marketplace/') && location.pathname !== '/marketplace');

  if (isDetailPage) {
    return null;
  }

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 px-4 py-2 safe-area-pb z-20">
      <div className="flex items-center justify-around">
        {tabs.map((tab) => {
          const Icon = tab.icon
          const isCreate = tab.isCreate

          if (isCreate) {
            return (
              <motion.button
                key={tab.id}
                onClick={onCreatePost}
                className="flex items-center justify-center w-12 h-12 bg-blue-500 text-white rounded-full shadow-lg transform -translate-y-4"
                whileTap={{ scale: 0.9 }}
              >
                <Icon size={24} />
              </motion.button>
            )
          }

          return (
            <NavLink
              key={tab.id}
              to={tab.path!}
              end // Make sure NavLink for "/" is only active on the exact path
              className={({ isActive }) =>
                `flex flex-col items-center justify-center p-2 min-w-0 ${
                  isActive ? 'text-blue-500' : 'text-gray-500'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <Icon size={20} />
                  <span className="text-xs mt-1 truncate">{tab.label}</span>
                  {isActive && (
                    <motion.div 
                      layoutId="active-nav-indicator"
                      className="h-0.5 w-4 bg-blue-500 rounded-full mt-1"
                    />
                  )}
                </>
              )}
            </NavLink>
          )
        })}
      </div>
    </div>
  )
}
