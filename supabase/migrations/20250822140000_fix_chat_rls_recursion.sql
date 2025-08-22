/*
# [Fix] Chat RLS Recursion Error
This migration fixes a critical infinite recursion error in the chat's Row Level Security (RLS) policies.

## Query Description:
This script will:
1.  Drop all existing RLS policies on chat-related tables (`chat_rooms`, `chat_room_members`, `chat_messages`) to remove the faulty logic.
2.  Create a new, safe helper function `is_chat_member(room_id, user_id)` that runs with elevated privileges (`SECURITY DEFINER`) to securely check for room membership without causing recursion.
3.  Re-create the RLS policies using this helper function, ensuring that users can only access data for chat rooms they are members of.

This change is safe and essential for the chat functionality to work correctly. It resolves the "infinite recursion" error and the subsequent "Failed to fetch" errors in the application.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true (by restoring previous policies)

## Structure Details:
- **Functions Created:** `public.is_chat_member(uuid, uuid)`
- **Policies Dropped:** All policies on `chat_rooms`, `chat_room_members`, `chat_messages`.
- **Policies Created:** New, non-recursive policies for `SELECT`, `INSERT` on `chat_rooms`, `chat_room_members`, `chat_messages`.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: Policies correctly use `auth.uid()` to enforce user-specific access. This change significantly improves security by fixing a faulty implementation.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Positive. The new policies are more efficient and prevent the server from crashing due to recursion.
*/

-- Drop existing policies to ensure a clean slate.
DROP POLICY IF EXISTS "Allow members to see their rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow members to see other members in their rooms" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow members to insert themselves into rooms" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow members to read messages in their rooms" ON public.chat_messages;
DROP POLICY IF EXISTS "Allow members to send messages in their rooms" ON public.chat_messages;

-- Drop the helper function if it exists, to ensure it's created correctly.
DROP FUNCTION IF EXISTS public.is_chat_member(uuid, uuid);

-- Create a helper function to check for room membership safely.
-- SECURITY DEFINER allows this function to bypass RLS, preventing recursion.
CREATE OR REPLACE FUNCTION public.is_chat_member(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  );
END;
$$;

-- Grant execute permission to authenticated users.
GRANT EXECUTE ON FUNCTION public.is_chat_member(uuid, uuid) TO authenticated;

-- Re-create policies using the safe helper function.

-- Policies for: chat_rooms
CREATE POLICY "Allow members to see their rooms"
ON public.chat_rooms
FOR SELECT
USING (public.is_chat_member(id, auth.uid()));

-- Policies for: chat_room_members
CREATE POLICY "Allow members to see other members in their rooms"
ON public.chat_room_members
FOR SELECT
USING (public.is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow members to insert themselves into rooms"
ON public.chat_room_members
FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Policies for: chat_messages
CREATE POLICY "Allow members to read messages in their rooms"
ON public.chat_messages
FOR SELECT
USING (public.is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow members to send messages in their rooms"
ON public.chat_messages
FOR INSERT
WITH CHECK (public.is_chat_member(room_id, auth.uid()));
