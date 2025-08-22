/*
# [Cache Invalidation]
This script forces a refresh of the Supabase schema cache.

## Query Description:
This operation safely re-applies an existing Row Level Security (RLS) policy on the `chat_messages` table. It does not change any data or table structures. Its sole purpose is to trigger a cache invalidation in the Supabase API, which resolves errors where newly added columns (like 'status') are not immediately recognized.

## Metadata:
- Schema-Category: ["Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
- Affects RLS policy: "Allow members to send messages" on table "chat_messages".

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No] - Re-applies the existing policy.
- Auth Requirements: [None]

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [Negligible. A one-time, quick metadata update.]
*/

-- Re-apply the policy to force a schema cache refresh
DROP POLICY IF EXISTS "Allow members to send messages" ON public.chat_messages;
CREATE POLICY "Allow members to send messages"
ON public.chat_messages
FOR INSERT
WITH CHECK (public.is_chat_member(room_id, auth.uid()));
