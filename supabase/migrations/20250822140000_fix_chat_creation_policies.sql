/*
          # [Operation Name]
          Fix Chat Creation RLS Policies

          ## Query Description: [This operation fixes the Row Level Security (RLS) policies for chat room and member creation. It ensures that users can create new chat rooms and add members to them securely, resolving the "violates row-level security policy" error. This change is safe and does not affect existing data.]
          
          ## Metadata:
          - Schema-Category: "Safe"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Affects policies on tables: `chat_rooms`, `chat_room_members`
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes
          - Auth Requirements: Authenticated users
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Negligible performance impact. Improves application functionality.
          */

-- Drop existing policies to ensure a clean state
DROP POLICY IF EXISTS "Allow authenticated users to create chat rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow room creator to add members" ON public.chat_room_members;

-- Policy: Allow any authenticated user to create a chat room.
-- The `created_by` column will be set to the user's ID by the application logic.
CREATE POLICY "Allow authenticated users to create chat rooms"
ON public.chat_rooms
FOR INSERT TO authenticated
WITH CHECK (true);

-- Policy: Allow the user who created a chat room to add members to it.
-- This is crucial for the getOrCreateChatRoom function to succeed.
CREATE POLICY "Allow room creator to add members"
ON public.chat_room_members
FOR INSERT TO authenticated
WITH CHECK (
  (SELECT created_by FROM public.chat_rooms WHERE id = room_id) = auth.uid()
);
