/*
  # [Feature] Enable Chat Room Creation
  This migration adds a new Row Level Security (RLS) policy to the `chat_rooms` table. This policy is essential for allowing users to start new conversations.

  ## Query Description:
  - This operation is safe and does not affect existing data.
  - It adds a security policy that permits any authenticated user to insert a new row into the `chat_rooms` table, which is required to create a new chat.
  - Existing policies for reading and managing chats are unaffected.

  ## Metadata:
  - Schema-Category: "Safe"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (the policy can be dropped)

  ## Security Implications:
  - RLS Status: Enabled
  - Policy Changes: Yes (Adds a new INSERT policy)
  - Auth Requirements: This policy applies to all `authenticated` users.
*/

-- Drop the policy if it already exists to make the script idempotent
DROP POLICY IF EXISTS "Allow authenticated users to create chat rooms" ON public.chat_rooms;

-- Create the policy to allow authenticated users to create new chat rooms
CREATE POLICY "Allow authenticated users to create chat rooms"
ON public.chat_rooms
FOR INSERT
TO authenticated
WITH CHECK (true);
