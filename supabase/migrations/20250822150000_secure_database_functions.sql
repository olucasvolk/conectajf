/*
# [SECURITY] Harden Database Functions

This migration enhances the security of all custom database functions by explicitly setting the `search_path`. This prevents potential security vulnerabilities where a malicious user could temporarily create a function that gets executed instead of the intended one. This addresses the "Function Search Path Mutable" security advisory.

## Query Description:
This operation is safe and non-destructive. It modifies the metadata of existing functions without altering their logic or impacting any data.

## Metadata:
- Schema-Category: ["Security", "Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true (by unsetting the search_path)

## Structure Details:
- Modifies the configuration of the following functions:
  - `handle_new_user()`
  - `update_likes_count()`
  - `update_last_message_at()`
  - `get_chat_rooms_for_user(uuid)`
  - `get_existing_private_chat(uuid, uuid)`

## Security Implications:
- Mitigates: Potential for search path hijacking attacks.

## Performance Impact:
- Estimated Impact: Negligible. This is a metadata change.
*/

-- Secure the trigger function for new user profile creation
ALTER FUNCTION public.handle_new_user()
SET search_path = 'public';

-- Secure the trigger function for updating likes count
ALTER FUNCTION public.update_likes_count()
SET search_path = 'public';

-- Secure the trigger function for updating the last message timestamp
ALTER FUNCTION public.update_last_message_at()
SET search_path = 'public';

-- Secure the RPC function for fetching user chat rooms
ALTER FUNCTION public.get_chat_rooms_for_user(user_id uuid)
SET search_path = 'public';

-- Secure the RPC function for finding a private chat room
ALTER FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
SET search_path = 'public';
