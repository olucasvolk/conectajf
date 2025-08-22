import React, { createContext, useContext, useEffect, useState, useCallback } from 'react'
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

  const signOut = useCallback(async () => {
    await supabase.auth.signOut()
    setUser(null)
    setProfile(null)
  }, [])

  // Effect 1: Handle user session changes and detect malformed JWTs
  useEffect(() => {
    setSessionLoading(true)
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, session) => {
      // This logic helps detect and handle a malformed JWT stored in localStorage.
      if (session?.access_token) {
        try {
          // Attempt to decode the token payload. If it fails, the token is malformed.
          JSON.parse(atob(session.access_token.split('.')[1]));
        } catch (e) {
          console.error('Malformed JWT detected, forcing sign out.', e);
          await signOut();
          setSessionLoading(false);
          return;
        }
      }
      
      setUser(session?.user ?? null)
      setSessionLoading(false)
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [signOut])

  // Effect 2: Fetch profile data and handle authentication errors during fetch
  useEffect(() => {
    const fetchProfile = async () => {
      if (user) {
        setProfileLoading(true)
        try {
          const { data, error } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single()

          if (error) {
            // If the token is invalid, Supabase might return an auth error.
            // This will force a sign-out to clear the invalid session.
            if (error.code === 'PGRST301' || error.message.includes('JWT') || error.message.includes('invalid token')) {
              console.error('Authentication error while fetching profile. Signing out.', error)
              await signOut()
              return
            }
            throw error
          }
          
          setProfile(data || null)
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
  }, [user, signOut])

  async function signUp(email: string, password: string, userData: any) {
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
    return data
  }

  async function signIn(email: string, password:string) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })
    return { data, error }
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
