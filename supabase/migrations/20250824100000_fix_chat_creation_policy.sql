/*
# [Fix Chat Room Creation RLS Policy]
This migration fixes a row-level security (RLS) policy issue that prevents users from creating new chat rooms. The previous policy was too restrictive, causing an RLS violation on insert. This script adds a new policy that correctly allows authenticated users to create chat rooms they own.

## Query Description: [This operation modifies security policies on the 'chat_rooms' table. It ensures that users can start new conversations, a core feature of the app. There is no risk to existing data as it only adds a new permission.]

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Table affected: `public.chat_rooms`
- Policy added: "Allow users to create their own chat rooms" (INSERT)

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes. Adds a new `INSERT` policy to `chat_rooms`.
- Auth Requirements: The new policy requires a user to be authenticated to create a room.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible performance impact.
*/

CREATE POLICY "Allow users to create their own chat rooms"
ON public.chat_rooms
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = created_by);
