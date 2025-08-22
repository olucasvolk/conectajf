/*
          # [Operation Name]
          Stabilize Chat Creation with a Robust RPC Function

          [Description of what this operation does]
          This migration replaces the previous, less reliable chat creation logic with a single, atomic database function named `get_or_create_chat_room`. This function handles finding an existing private chat or creating a new one, including adding members, in a single, safe transaction. It also removes the old, now-redundant `get_existing_private_chat` function.

          ## Query Description: [This operation improves the reliability and performance of the chat system. It drops an old function and creates a new, more comprehensive one. There is no risk to existing data, as it only affects the logic for initiating new conversations.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Drops function: `public.get_existing_private_chat(uuid, uuid)`
          - Creates function: `public.get_or_create_chat_room(uuid, uuid)`
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [No]
          - Auth Requirements: [The new function uses `SECURITY DEFINER` to ensure it can execute correctly, bypassing RLS within the function's context for safe transaction handling.]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [None]
          - Estimated Impact: [Positive. Reduces the number of client-server round trips for creating a new chat from multiple queries to a single RPC call, significantly improving performance and reliability.]
          */

-- Drop the old, less efficient function to avoid conflicts.
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid);

-- Create a new, robust function to get or create a private chat room in a single, atomic operation.
CREATE OR REPLACE FUNCTION public.get_or_create_chat_room(
    user1_id uuid,
    user2_id uuid
)
RETURNS uuid AS $$
DECLARE
    existing_room_id uuid;
    new_room_id uuid;
BEGIN
    -- First, try to find an existing private (non-group) chat room between the two users.
    SELECT cr.id INTO existing_room_id
    FROM public.chat_rooms cr
    WHERE cr.is_group = false
    AND EXISTS (SELECT 1 FROM public.chat_room_members WHERE room_id = cr.id AND user_id = user1_id)
    AND EXISTS (SELECT 1 FROM public.chat_room_members WHERE room_id = cr.id AND user_id = user2_id);

    -- If a room is found, return its ID immediately.
    IF existing_room_id IS NOT NULL THEN
        RETURN existing_room_id;
    END IF;

    -- If no room exists, create a new one.
    -- The user initiating the action (user1_id) is set as the creator.
    INSERT INTO public.chat_rooms (created_by, is_group)
    VALUES (user1_id, false)
    RETURNING id INTO new_room_id;

    -- Add both users as members to the newly created room.
    INSERT INTO public.chat_room_members (room_id, user_id)
    VALUES
        (new_room_id, user1_id),
        (new_room_id, user2_id);

    -- Return the ID of the newly created room.
    RETURN new_room_id;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;
