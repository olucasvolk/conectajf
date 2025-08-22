-- =================================================================
-- MIGRATION: Fix Chat RLS Recursion Definitively
--
-- DESCRIPTION:
-- This script provides a definitive fix for the "infinite recursion"
-- error that occurs when querying chat rooms. The root cause is a
-- faulty Row Level Security (RLS) policy that references itself.
--
-- This script is IDEMPOTENT, meaning it is safe to run multiple times.
-- It will:
-- 1. Drop all existing chat-related policies to ensure a clean slate.
-- 2. Create a secure helper function (is_chat_member) to break the
--    recursion loop.
-- 3. Re-create all chat-related policies correctly and securely.
-- =================================================================

-- Step 1: Drop all existing policies on chat-related tables.
DROP POLICY IF EXISTS "Allow members to see their rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow authenticated users to create rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow room creator to add members" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow members to see other members" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow user to add themselves" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow room creator or user to add members" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow members to read messages in their rooms" ON public.chat_messages;
DROP POLICY IF EXISTS "Allow members to send messages" ON public.chat_messages;

-- Step 2: Create a secure helper function to check for room membership.
-- The SECURITY DEFINER allows the function to bypass RLS for its internal check,
-- which is the key to breaking the recursion loop.
CREATE OR REPLACE FUNCTION public.is_chat_member(p_room_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = auth.uid()
  );
$$;

-- Step 3: Re-create policies for chat_rooms table.
-- A user can see a room if they are a member.
CREATE POLICY "Allow members to see their rooms"
ON public.chat_rooms FOR SELECT
USING (public.is_chat_member(id));

-- Any authenticated user can create a new room.
CREATE POLICY "Allow authenticated users to create rooms"
ON public.chat_rooms FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Step 4: Re-create policies for chat_room_members table.
-- A user can see the members of a room if they are also a member of that room.
CREATE POLICY "Allow members to see other members"
ON public.chat_room_members FOR SELECT
USING (public.is_chat_member(room_id));

-- A user can be added to a room if the person adding them is the room creator,
-- OR if they are adding themselves to a room.
CREATE POLICY "Allow room creator or user to add members"
ON public.chat_room_members FOR INSERT
WITH CHECK (
  (EXISTS (SELECT 1 FROM public.chat_rooms WHERE id = room_id AND created_by = auth.uid())) -- Room creator can add anyone
  OR
  (user_id = auth.uid()) -- A user can add themselves
);

-- Step 5: Re-create policies for chat_messages table.
-- A user can read messages in a room they are a member of.
CREATE POLICY "Allow members to read messages in their rooms"
ON public.chat_messages FOR SELECT
USING (public.is_chat_member(room_id));

-- A user can send a message if they are a member of the room and the message is from them.
CREATE POLICY "Allow members to send messages"
ON public.chat_messages FOR INSERT
WITH CHECK (public.is_chat_member(room_id) AND user_id = auth.uid());
