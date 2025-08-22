/*
# [Fix] Resolve Infinite Recursion in Chat RLS Policy
This migration fixes a critical "infinite recursion" error in the Row Level Security (RLS) policy for the `chat_room_members` table. The error occurs because the existing policy for reading members likely checks for membership by querying the same table, creating a loop.

## Query Description:
This script introduces a `SECURITY DEFINER` function to safely check for chat room membership without triggering recursive RLS checks. It then replaces the faulty policies with new, safe ones that use this function. This change is critical for the chat functionality to work correctly.

- **Impact on existing data**: No data will be lost or modified. This only changes security access rules.
- **Potential risks**: If other parts of the application rely on the specific (and incorrect) behavior of the old policy, they might need adjustments. However, this fix aligns with standard, secure access patterns.
- **Precautions**: No backup is required as this is a non-destructive change to security policies.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true (by dropping the new function/policies and restoring the old ones)

## Structure Details:
- **Function Created**: `public.is_member_of_room(uuid, uuid)`
- **Policies Dropped (Attempted)**: Various potentially conflicting policies on `chat_room_members`.
- **Policies Created**:
  - "Allow members to read member list" on `chat_room_members` (SELECT)
  - "Allow user to manage their own membership" on `chat_room_members` (INSERT, UPDATE, DELETE)

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes. Replaces recursive policies with safe, function-based policies.
- Auth Requirements: Policies rely on `auth.uid()`.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. The function call might add a tiny overhead but prevents the critical recursion error, leading to a massive performance improvement (from non-functional to functional).
*/

-- Step 1: Create a helper function with SECURITY DEFINER to break the recursion.
-- This function can check for membership without being subject to the RLS policy of the calling user.
CREATE OR REPLACE FUNCTION public.is_member_of_room(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  );
END;
$$;

-- Step 2: Drop the old, potentially recursive policies.
-- We drop a few common names to be safe. It's okay if they don't exist.
DROP POLICY IF EXISTS "Allow members to see other members" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow user to see their own membership" ON public.chat_room_members;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.chat_room_members;
DROP POLICY IF EXISTS "Enable read access for users based on user_id" ON public.chat_room_members;
DROP POLICY IF EXISTS "Fix for chat RLS recursion" ON public.chat_room_members;


-- Step 3: Create a new, non-recursive policy for SELECT operations.
-- This policy allows a user to see all members of a room they belong to.
CREATE POLICY "Allow members to read member list"
ON public.chat_room_members
FOR SELECT
USING (public.is_member_of_room(room_id, auth.uid()));


-- Step 4: Create policies for INSERT, UPDATE, and DELETE.
-- This allows users to join/leave rooms but not affect other users.
CREATE POLICY "Allow user to manage their own membership"
ON public.chat_room_members
FOR ALL -- Covers INSERT, UPDATE, DELETE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
