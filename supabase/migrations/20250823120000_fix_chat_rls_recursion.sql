/*
# Fix Chat RLS Recursion

This migration fixes an infinite recursion error in the Row Level Security (RLS) policies for the chat feature. The error occurs when a policy on a table (e.g., `chat_room_members`) tries to query itself, creating a loop.

## Query Description:
This script introduces a `SECURITY DEFINER` helper function (`is_member_of_room`) to safely check for room membership without triggering RLS policies on itself. It then drops all existing chat-related policies and recreates them using this safe helper function. This resolves the recursion error and ensures the chat functionality works correctly and securely. No data is modified or deleted.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true (by dropping the new policies/function and restoring the old ones)

## Structure Details:
- **Functions Created:** `public.is_member_of_room(uuid)`
- **Policies Dropped/Created:** Policies on `chat_rooms`, `chat_room_members`, `chat_messages`.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes. Replaces faulty policies with secure, non-recursive versions.
- Auth Requirements: Policies rely on `auth.uid()`.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Minimal. The helper function is efficient.
*/

-- Step 1: Create a helper function to check room membership safely.
-- This function uses `SECURITY DEFINER` to bypass RLS for its internal query,
-- thus preventing the recursion loop.
CREATE OR REPLACE FUNCTION public.is_member_of_room(p_room_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if the currently authenticated user is a member of the given room.
  RETURN EXISTS (
    SELECT 1
    FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = auth.uid()
  );
END;
$$;

-- Step 2: Drop all existing policies on chat tables to ensure a clean slate.
DROP POLICY IF EXISTS "Allow members to see their rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow authenticated users to create rooms" ON public.chat_rooms;

DROP POLICY IF EXISTS "Allow members to see other members" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow creator to add members" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow user to add themselves" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow user to be added to rooms" ON public.chat_room_members;

DROP POLICY IF EXISTS "Allow members to read messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Allow members to send messages" ON public.chat_messages;

-- Step 3: Recreate policies using the safe helper function.

-- Policies for: chat_rooms
CREATE POLICY "Allow members to see their rooms"
ON public.chat_rooms FOR SELECT
USING (public.is_member_of_room(id));

CREATE POLICY "Allow authenticated users to create rooms"
ON public.chat_rooms FOR INSERT
WITH CHECK (created_by = auth.uid());

-- Policies for: chat_room_members
CREATE POLICY "Allow members to see other members"
ON public.chat_room_members FOR SELECT
USING (public.is_member_of_room(room_id));

-- Allow the creator of a room to add members, or a user to add themselves.
-- This supports the logic in the `getOrCreateChatRoom` utility function.
CREATE POLICY "Allow user to be added to rooms"
ON public.chat_room_members FOR INSERT
WITH CHECK (
  (user_id = auth.uid()) OR -- User can add themselves
  (EXISTS ( -- or the room creator can add them
    SELECT 1 FROM public.chat_rooms
    WHERE chat_rooms.id = chat_room_members.room_id
    AND chat_rooms.created_by = auth.uid()
  ))
);

-- Policies for: chat_messages
CREATE POLICY "Allow members to read messages"
ON public.chat_messages FOR SELECT
USING (public.is_member_of_room(room_id));

CREATE POLICY "Allow members to send messages"
ON public.chat_messages FOR INSERT
WITH CHECK (
  public.is_member_of_room(room_id) AND user_id = auth.uid()
);
