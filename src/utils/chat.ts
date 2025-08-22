import { supabase } from '../lib/supabase'

/**
 * Finds an existing 1-on-1 chat room between two users or creates a new one
 * by calling a dedicated, atomic database function.
 * @param currentUserId The ID of the currently logged-in user.
 * @param otherUserId The ID of the user to chat with.
 * @returns The ID of the chat room.
 */
export async function getOrCreateChatRoom(currentUserId: string, otherUserId: string): Promise<string | null> {
  try {
    // Call the single RPC function that handles all logic atomically.
    const { data, error } = await supabase.rpc('get_or_create_chat_room', {
      user1_id: currentUserId,
      user2_id: otherUserId
    })

    if (error) {
      console.error('Error in get_or_create_chat_room RPC:', error)
      throw error
    }

    if (!data) {
      throw new Error('RPC function did not return a room ID.')
    }

    return data
    
  } catch (error) {
    console.error('Failed to execute getOrCreateChatRoom:', error)
    return null
  }
}
