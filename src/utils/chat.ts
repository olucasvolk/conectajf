import { supabase } from '../lib/supabase'

/**
 * Finds an existing 1-on-1 chat room between two users or creates a new one.
 * @param currentUserId The ID of the currently logged-in user.
 * @param otherUserId The ID of the user to chat with.
 * @returns The ID of the chat room.
 */
export async function getOrCreateChatRoom(currentUserId: string, otherUserId: string): Promise<string | null> {
  try {
    // Step 1: Find mutual chat rooms.
    // This is a complex query to do client-side, so we'll use an RPC call
    // to a database function for efficiency and correctness.
    const { data: existingRoom, error: rpcError } = await supabase.rpc('get_existing_private_chat', {
      user1_id: currentUserId,
      user2_id: otherUserId
    })

    if (rpcError) {
      // If the function doesn't exist, fall back to a client-side approach.
      // This is less efficient but provides a good fallback.
      if (rpcError.code === '42883') {
        console.warn('RPC function get_existing_private_chat not found. Falling back to client-side query. Consider adding the RPC function for better performance.')
        
        const { data: rooms, error: roomsError } = await supabase
          .from('chat_room_members')
          .select('room_id')
          .in('user_id', [currentUserId, otherUserId])

        if (roomsError) throw roomsError

        // Count occurrences of each room_id
        const roomCounts = rooms.reduce((acc, { room_id }) => {
          acc[room_id] = (acc[room_id] || 0) + 1
          return acc
        }, {} as Record<string, number>)
        
        // Find a room_id that appears twice (meaning both users are in it)
        const mutualRoomId = Object.keys(roomCounts).find(id => roomCounts[id] === 2)

        if (mutualRoomId) {
          // Check if it's a private chat
          const { data: roomInfo, error: roomInfoError } = await supabase
            .from('chat_rooms')
            .select('is_group')
            .eq('id', mutualRoomId)
            .single()

          if (roomInfoError) throw roomInfoError
          if (!roomInfo.is_group) return mutualRoomId
        }
      } else {
        throw rpcError
      }
    }
    
    if (existingRoom) {
      return existingRoom
    }

    // Step 2: If no room exists, create a new one.
    const { data: newRoom, error: createRoomError } = await supabase
      .from('chat_rooms')
      .insert({ created_by: currentUserId, is_group: false })
      .select()
      .single()

    if (createRoomError) throw createRoomError
    if (!newRoom) throw new Error('Failed to create chat room.')

    // Step 3: Add both users as members.
    const { error: addMembersError } = await supabase
      .from('chat_room_members')
      .insert([
        { room_id: newRoom.id, user_id: currentUserId },
        { room_id: newRoom.id, user_id: otherUserId }
      ])

    if (addMembersError) throw addMembersError

    return newRoom.id

  } catch (error) {
    console.error('Error in getOrCreateChatRoom:', error)
    return null
  }
}
