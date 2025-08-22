import React, { useState } from 'react'
import { BrowserRouter, Routes, Route, Outlet, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import { AuthForm } from './components/Auth/AuthForm'
import { BottomNavigation } from './components/Layout/BottomNavigation'
import { FeedScreen } from './components/Feed/FeedScreen'
import { MarketplaceScreen } from './components/Marketplace/MarketplaceScreen'
import { ChatScreen } from './components/Chat/ChatScreen'
import { NewChatScreen } from './components/Chat/NewChatScreen'
import { ChatRoomScreen } from './components/Chat/ChatRoomScreen'
import { ProfileScreen } from './components/Profile/ProfileScreen'
import { CreateModal } from './components/Create/CreateModal'
import { LoadingSpinner } from './components/Common/LoadingSpinner'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <LoadingSpinner size="lg" text="Carregando..." />
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/auth" replace />
  }

  return <>{children}</>
}

function MainLayout() {
  const [showCreateModal, setShowCreateModal] = useState(false)

  return (
    <div className="min-h-screen bg-gray-50">
      <Outlet />
      
      <BottomNavigation
        onCreatePost={() => setShowCreateModal(true)}
      />

      <CreateModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
      />
    </div>
  )
}

function AppContent() {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <LoadingSpinner size="lg" text="Carregando..." />
      </div>
    )
  }
  
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/auth" element={user ? <Navigate to="/" /> : <AuthForm />} />
        
        <Route 
          path="/" 
          element={
            <ProtectedRoute>
              <MainLayout />
            </ProtectedRoute>
          }
        >
          <Route index element={<FeedScreen />} />
          <Route path="marketplace" element={<MarketplaceScreen />} />
          <Route path="chat" element={<ChatScreen />} />
          <Route path="chat/new" element={<NewChatScreen />} />
          <Route path="chat/:roomId" element={<ChatRoomScreen />} />
          <Route path="profile" element={<ProfileScreen />} />
        </Route>

        <Route path="*" element={<Navigate to={user ? "/" : "/auth"} />} />
      </Routes>
    </BrowserRouter>
  )
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App
