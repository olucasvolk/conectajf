/*
# [Fix] Chat Security Policies
This migration fixes an infinite recursion error in the Row-Level Security (RLS) policies for the chat functionality by introducing a SECURITY DEFINER function.

## Query Description:
This operation will replace the existing security policies on the `chat_room_members` table. The old policies caused a server error by creating an infinite loop. The new policies use a helper function to safely check user permissions, resolving the error and securing the chat feature. No data will be lost.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true (by restoring old policies)

## Structure Details:
- **Tables Affected**: `chat_room_members`
- **Functions Created**: `is_chat_member(uuid)`
- **Policies Replaced**: `SELECT`, `INSERT`, `DELETE` policies on `chat_room_members`

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes. This change is critical to fix a security flaw that made the chat feature unusable.
- Auth Requirements: All chat operations will be correctly gated by user authentication.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. The function call is highly efficient.
*/

-- Step 1: Create a helper function to check room membership safely.
-- The SECURITY DEFINER clause is crucial. It makes the function run with the permissions
-- of the user who created it, bypassing the RLS policy of the calling user and
-- thus avoiding the infinite recursion.
CREATE OR REPLACE FUNCTION public.is_chat_member(p_room_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
-- Setting search_path is a security best practice for SECURITY DEFINER functions.
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = auth.uid()
  );
$$;

-- Step 2: Drop existing policies on chat_room_members to avoid conflicts.
-- We drop all policies to ensure a clean slate.
DO $$
DECLARE
    policy_name text;
BEGIN
    FOR policy_name IN (SELECT policyname FROM pg_policies WHERE tablename = 'chat_room_members' AND schemaname = 'public')
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_name || '" ON public.chat_room_members;';
    END LOOP;
END$$;


-- Step 3: Create new, non-recursive policies.

-- Users can see all members of a room they are part of.
CREATE POLICY "Allow select for members"
ON public.chat_room_members
FOR SELECT
USING (public.is_chat_member(room_id));

-- Users can only insert themselves into a room.
CREATE POLICY "Allow insert for own user_id"
ON public.chat_room_members
FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Users can only remove themselves from a room (leave).
CREATE POLICY "Allow delete for own user_id"
ON public.chat_room_members
FOR DELETE
USING (user_id = auth.uid());
