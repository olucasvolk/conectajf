import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables')
}

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey)

// Definindo o tipo ENUM para o status da mensagem
export type MessageStatus = 'sending' | 'sent' | 'delivered' | 'read'

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          username: string
          full_name: string
          avatar_url: string | null
          bio: string | null
          location: string | null
          phone: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          username: string
          full_name: string
          avatar_url?: string | null
          bio?: string | null
          location?: string | null
          phone?: string | null
        }
        Update: {
          username?: string
          full_name?: string
          avatar_url?: string | null
          bio?: string | null
          location?: string | null
          phone?: string | null
        }
      }
      news_posts: {
        Row: {
          id: string
          user_id: string
          title: string
          content: string
          location: string | null
          category: string | null
          likes_count: number
          comments_count: number
          created_at: string
          updated_at: string
        }
        Insert: {
          user_id: string
          title: string
          content: string
          location?: string | null
          category?: string | null
        }
        Update: {
          title?: string
          content?: string
          location?: string | null
          category?: string | null
        }
      }
      marketplace_products: {
        Row: {
          id: string
          user_id: string
          title: string
          description: string
          price: number
          condition: 'novo' | 'usado' | 'seminovo'
          category: string
          location: string | null
          is_available: boolean
          likes_count: number
          created_at: string
          updated_at: string
        }
        Insert: {
          user_id: string
          title: string
          description: string
          price: number
          condition: 'novo' | 'usado' | 'seminovo'
          category: string
          location?: string | null
        }
        Update: {
          title?: string
          description?: string
          price?: number
          condition?: 'novo' | 'usado' | 'seminovo'
          category?: string
          location?: string | null
          is_available?: boolean
        }
      }
      post_likes: {
        Row: {
          id: string
          user_id: string
          post_id: string | null
          product_id: string | null
          created_at: string
        }
        Insert: {
          user_id: string
          post_id?: string | null
          product_id?: string | null
        }
      }
      post_comments: {
        Row: {
          id: string
          user_id: string
          post_id: string
          content: string
          created_at: string
        }
        Insert: {
          user_id: string
          post_id: string
          content: string
        }
      }
      chat_rooms: {
        Row: {
          id: string
          name: string | null
          is_group: boolean
          created_by: string
          last_message_at: string
          created_at: string
        }
        Insert: {
          name?: string | null
          is_group?: boolean
          created_by: string
        }
      }
      chat_room_members: {
        Row: {
          id: string
          room_id: string
          user_id: string
          joined_at: string
          is_typing: boolean
        }
        Insert: {
          room_id: string
          user_id: string
        }
        Update: {
          is_typing?: boolean
        }
      }
      chat_messages: {
        Row: {
          id: string
          room_id: string
          user_id: string
          content: string
          message_type: 'text' | 'image' | 'video'
          status: MessageStatus
          read_at: string | null
          created_at: string
        }
        Insert: {
          room_id: string
          user_id: string
          content: string
          message_type?: 'text' | 'image' | 'video'
          status?: MessageStatus
        }
        Update: {
          status?: MessageStatus
          read_at?: string
        }
      }
    }
    Enums: {
      message_status: 'sending' | 'sent' | 'delivered' | 'read'
    }
  }
}
