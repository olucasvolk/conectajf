/*
  # [Fix] Correct Chat Room Creation Policy
  This migration fixes a row-level security (RLS) issue that prevents users from creating new chat rooms. It replaces any existing INSERT policies on the `chat_rooms` table with a single, correct policy.

  ## Query Description: 
  This operation is safe and non-destructive. It modifies security policies, not data. It ensures that the application's chat functionality works as intended by allowing users to initiate new conversations.

  ## Metadata:
  - Schema-Category: "Security"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (the old policy can be restored if known)
  
  ## Structure Details:
  - Affects table: `public.chat_rooms`
  - Modifies: RLS Policies for INSERT

  ## Security Implications:
  - RLS Status: Assumes RLS is enabled.
  - Policy Changes: Yes. Drops potentially incorrect INSERT policies and adds a correct one.
  - Auth Requirements: The new policy applies to `authenticated` users.
  
  ## Performance Impact:
  - Indexes: None
  - Triggers: None
  - Estimated Impact: Negligible. RLS policy checks are very fast.
*/

-- Drop potentially conflicting old policies to ensure a clean state.
-- Using IF EXISTS to prevent errors if the policies don't exist.
DROP POLICY IF EXISTS "Allow authenticated users to create chat rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.chat_rooms;
DROP POLICY IF EXISTS "Authenticated users can create new chat rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow authenticated user to create their own chat rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow authenticated user to create chat rooms" ON public.chat_rooms;


-- Create the definitive policy for creating chat rooms.
-- This allows any authenticated user to insert a new row into `chat_rooms`
-- provided that they set the `created_by` column to their own user ID.
-- This is the standard and secure way to handle this permission.
CREATE POLICY "Authenticated users can create chat rooms"
ON public.chat_rooms
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);
