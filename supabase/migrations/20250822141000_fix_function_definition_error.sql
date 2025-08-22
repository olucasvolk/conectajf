/*
  # [Fix] Correct Function Definitions and RLS Policies
  This migration addresses a "cannot change return type" error by correctly dropping and re-creating functions.
  It also re-applies related RLS policies to ensure they are using the correct, non-recursive logic.

  ## Query Description:
  This operation safely drops and re-creates the `get_chat_rooms_for_user` and `get_existing_private_chat` functions to fix a migration error. It then re-applies the RLS policies on `chat_rooms` and `chat_room_members` to ensure they are secure and functional. This should resolve the migration failures and the original RLS recursion issues. No data is at risk.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Medium"
  - Requires-Backup: false
  - Reversible: false (This is a corrective patch)

  ## Structure Details:
  - Drops and re-creates function: `get_chat_rooms_for_user(uuid)`
  - Drops and re-creates function: `get_existing_private_chat(uuid, uuid)`
  - Re-applies RLS policies on `chat_rooms` and `chat_room_members`

  ## Security Implications:
  - RLS Status: Enabled
  - Policy Changes: Yes (Re-applying correct policies)
  - Auth Requirements: All operations are dependent on `auth.uid()`.

  ## Performance Impact:
  - Estimated Impact: Negligible. Function calls in RLS are efficient.
*/

-- Step 1: Drop the problematic functions to allow re-creation.
-- Using `IF EXISTS` makes the script safe to run even if the functions are already gone.
DROP FUNCTION IF EXISTS public.get_chat_rooms_for_user(uuid);
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid);

-- Step 2: Re-create the helper function to get all chat rooms for a user.
-- This function is crucial for non-recursive RLS policies.
CREATE OR REPLACE FUNCTION public.get_chat_rooms_for_user(p_user_id uuid)
RETURNS TABLE(room_id uuid)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT crm.room_id FROM public.chat_room_members AS crm WHERE crm.user_id = p_user_id;
$$;

-- Step 3: Re-create the RPC function to find a private chat between two users.
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT crm1.room_id
    FROM public.chat_room_members crm1
    JOIN public.chat_room_members crm2 ON crm1.room_id = crm2.room_id
    JOIN public.chat_rooms cr ON crm1.room_id = cr.id
    WHERE
      crm1.user_id = user1_id AND
      crm2.user_id = user2_id AND
      cr.is_group = false
    LIMIT 1
  );
END;
$$;

-- Step 4: Re-apply RLS policies to ensure they use the correct helper functions.

-- Policy for chat_rooms: Users can see rooms they are members of.
DROP POLICY IF EXISTS "Allow members to see their rooms" ON public.chat_rooms;
CREATE POLICY "Allow members to see their rooms"
ON public.chat_rooms
FOR SELECT
USING (
  id IN (SELECT room_id FROM public.get_chat_rooms_for_user(auth.uid()))
);

-- Policy for chat_room_members: Users can see members of rooms they are in.
DROP POLICY IF EXISTS "Allow members to see other members in their rooms" ON public.chat_room_members;
CREATE POLICY "Allow members to see other members in their rooms"
ON public.chat_room_members
FOR SELECT
USING (
  room_id IN (SELECT room_id FROM public.get_chat_rooms_for_user(auth.uid()))
);

-- Ensure users can insert into chat_room_members if they are creating the room
-- or are already a member (for group chats).
DROP POLICY IF EXISTS "Allow members to insert into their own rooms" ON public.chat_room_members;
CREATE POLICY "Allow members to insert into their own rooms"
ON public.chat_room_members
FOR INSERT
WITH CHECK (
  (SELECT created_by FROM chat_rooms WHERE id = room_id) = auth.uid() OR
  room_id IN (SELECT room_id FROM public.get_chat_rooms_for_user(auth.uid()))
);
