/*
# [Fix] Idempotent Chat RLS Policy Reset
[This migration script safely resets all chat-related Row Level Security (RLS) policies to fix the 'policy already exists' error and ensure the chat functionality is secure and non-recursive. It drops existing policies before recreating them to guarantee a clean state.]

## Query Description: [This operation will drop and recreate all RLS policies for the chat tables (chat_rooms, chat_room_members, chat_messages). This is a safe operation that does not affect existing data but corrects the security rules to prevent errors and potential infinite loops. It's designed to be re-runnable without causing issues.]

## Metadata:
- Schema-Category: ["Security", "Structural"]
- Impact-Level: ["Medium"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Tables affected: chat_rooms, chat_room_members, chat_messages
- Operations: DROP POLICY IF EXISTS, CREATE POLICY

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: Authenticated users
*/

-- Helper function to check if a user is a member of a room.
-- This is crucial to avoid recursion in policies.
CREATE OR REPLACE FUNCTION is_chat_member(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  );
$$;

-- 1. Policies for `chat_rooms` table
-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Allow members to read rooms they are part of" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow users to create rooms" ON public.chat_rooms;

-- Recreate policies
CREATE POLICY "Allow members to read rooms they are part of"
ON public.chat_rooms
FOR SELECT
USING (is_chat_member(id, auth.uid()));

CREATE POLICY "Allow users to create rooms"
ON public.chat_rooms
FOR INSERT
WITH CHECK (auth.uid() = created_by);

-- 2. Policies for `chat_room_members` table
-- Drop existing policies (including potential old versions)
DROP POLICY IF EXISTS "Allow members to read their own room memberships" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow users to add members to rooms" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow users to add members to rooms they created" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow users to add themselves to rooms" ON public.chat_room_members;

-- Recreate policies
CREATE POLICY "Allow members to read their own room memberships"
ON public.chat_room_members
FOR SELECT
USING (is_chat_member(room_id, auth.uid()));

-- This policy allows a user who created a room to add other members,
-- and also allows any user to add themselves to a room.
CREATE POLICY "Allow users to add members to rooms"
ON public.chat_room_members
FOR INSERT
WITH CHECK (
  (auth.uid() = user_id) OR
  (EXISTS (
    SELECT 1
    FROM chat_rooms
    WHERE id = room_id AND created_by = auth.uid()
  ))
);

-- 3. Policies for `chat_messages` table
-- Drop existing policies
DROP POLICY IF EXISTS "Allow members to read messages in their rooms" ON public.chat_messages;
DROP POLICY IF EXISTS "Allow users to insert their own messages" ON public.chat_messages;

-- Recreate policies
CREATE POLICY "Allow members to read messages in their rooms"
ON public.chat_messages
FOR SELECT
USING (is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow users to insert their own messages"
ON public.chat_messages
FOR INSERT
WITH CHECK (
  user_id = auth.uid() AND is_chat_member(room_id, auth.uid())
);
