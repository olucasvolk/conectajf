/*
# [Fix] Resolve Infinite Recursion in Chat Policy
This migration fixes a critical database error where a Row Level Security (RLS) policy on the `chat_room_members` table was causing an infinite recursion loop when fetching chat rooms.

## Query Description:
- **Problem**: The previous `SELECT` policy on `chat_room_members` likely checked for room membership by querying itself, leading to the error.
- **Solution**: This script replaces the faulty policy with a simpler, non-recursive one. The new policy allows users to view only their own membership records, which is sufficient for the application's current queries and completely safe.
- **Impact**: This change is safe and resolves the error preventing the chat screen from loading. It does not delete any data.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes. The `SELECT` policy for `chat_room_members` is being replaced to enhance security and stability.
- Auth Requirements: This policy relies on `auth.uid()` to identify the current user.
*/

-- Step 1: Drop old, potentially recursive SELECT policies to ensure a clean slate.
DROP POLICY IF EXISTS "Users can view members of rooms they are in" ON public.chat_room_members;
DROP POLICY IF EXISTS "Users can view their own membership records" ON public.chat_room_members;


-- Step 2: Create a new, safe SELECT policy.
-- This policy allows users to fetch their own membership records, which is what the
-- application needs to list the chat rooms they belong to. It is not recursive.
CREATE POLICY "Users can view their own membership records"
ON public.chat_room_members
FOR SELECT
USING (auth.uid() = user_id);


-- Step 3: Ensure the INSERT policy is secure.
-- This policy ensures that a user can only add themselves to a chat room,
-- preventing them from adding other users.
DROP POLICY IF EXISTS "Users can insert their own membership" ON public.chat_room_members;

CREATE POLICY "Users can insert their own membership"
ON public.chat_room_members
FOR INSERT
WITH CHECK (auth.uid() = user_id);
