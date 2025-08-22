/*
# [SECURITY] Set Secure Search Path for All Functions
This migration enhances security by explicitly setting the `search_path` for all custom database functions. This prevents a class of vulnerabilities where a malicious user could temporarily create a function that gets executed instead of the intended one.

## Query Description:
This operation is safe and non-destructive. It modifies the metadata of existing functions without altering their logic or affecting any data. It is recommended for all production databases.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by altering the function again to remove the setting)

## Structure Details:
- Modifies `public.handle_new_user()`
- Modifies `public.update_last_message_at()`
- Modifies `public.update_likes_count()`
- Modifies `public.get_existing_private_chat(uuid, uuid)`
- Modifies `public.get_chat_rooms_for_user(uuid)`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates: "Function Search Path Mutable" security warning.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible.
*/

-- Set a secure search path for the user profile trigger function
ALTER FUNCTION public.handle_new_user() SET search_path = public;

-- Set a secure search path for the chat timestamp update function
ALTER FUNCTION public.update_last_message_at() SET search_path = public;

-- Set a secure search path for the likes count update function
ALTER FUNCTION public.update_likes_count() SET search_path = public;

-- Set a secure search path for the private chat lookup function
ALTER FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid) SET search_path = public;

-- Set a secure search path for the chat room list function
ALTER FUNCTION public.get_chat_rooms_for_user(user_id uuid) SET search_path = public;
