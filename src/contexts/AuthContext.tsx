import React, { createContext, useContext, useEffect, useState } from 'react'
import { User } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

interface AuthContextType {
  user: User | null
  profile: any | null
  loading: boolean
  signUp: (email: string, password: string, userData: any) => Promise<any>
  signIn: (email: string, password: string) => Promise<any>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [profile, setProfile] = useState<any | null>(null)
  const [sessionLoading, setSessionLoading] = useState(true)
  const [profileLoading, setProfileLoading] = useState(false)

  // Effect 1: Handle user session changes from Supabase Auth
  useEffect(() => {
    setSessionLoading(true)
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null)
      setSessionLoading(false)
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [])

  // Effect 2: Fetch profile data when a user is logged in
  useEffect(() => {
    const fetchProfile = async () => {
      if (user) {
        setProfileLoading(true)
        try {
          const { data, error } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)

          if (error) throw error
          
          setProfile(data?.[0] || null)
        } catch (error) {
          console.error('Error fetching profile:', error)
          setProfile(null)
        } finally {
          setProfileLoading(false)
        }
      } else {
        setProfile(null)
      }
    }

    fetchProfile()
  }, [user])

  async function signUp(email: string, password: string, userData: any) {
    // FIX: The profile creation is now handled by a database trigger.
    // We pass the user data in the `options.data` field, which the trigger
    // can access via `new.raw_user_meta_data`.
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: userData.full_name,
          username: userData.username,
        },
        emailRedirectTo: `${window.location.origin}/`
      }
    })

    if (error) throw error

    // The manual profile insertion is no longer needed here.
    return data
  }

  async function signIn(email: string, password:string) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })
    return { data, error }
  }

  async function signOut() {
    await supabase.auth.signOut()
    setProfile(null)
  }

  const value = {
    user,
    profile,
    loading: sessionLoading || profileLoading,
    signUp,
    signIn,
    signOut
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}
