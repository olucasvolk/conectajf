/*
# [SECURITY] Set Secure Search Path for All Custom Functions
This migration enhances security by explicitly setting the `search_path` for all custom database functions. This prevents a class of security vulnerabilities where a malicious user could temporarily create a function with the same name as a system function, potentially leading to unintended behavior or privilege escalation.

## Query Description:
This operation alters existing functions to make them more secure. It is a non-destructive change and does not affect application logic or data. It is safe to run on a production database.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by unsetting the search_path, though not recommended)

## Structure Details:
- Alters function: `public.create_profile_for_new_user()`
- Alters function: `public.get_chat_rooms_for_user(uuid)`
- Alters function: `public.get_existing_private_chat(uuid, uuid)`
- Alters function: `public.update_last_message_at()`
- Alters function: `public.update_likes_count()`

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Mitigates: "Function Search Path Mutable" security warning.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible performance impact.
*/

-- Set a secure search path for all known custom functions.
-- This is the recommended way to fix the "Function Search Path Mutable" warning.

ALTER FUNCTION public.create_profile_for_new_user()
SET search_path = 'public', 'extensions';

ALTER FUNCTION public.get_chat_rooms_for_user(uuid)
SET search_path = 'public', 'extensions';

ALTER FUNCTION public.get_existing_private_chat(uuid, uuid)
SET search_path = 'public', 'extensions';

ALTER FUNCTION public.update_last_message_at()
SET search_path = 'public', 'extensions';

ALTER FUNCTION public.update_likes_count()
SET search_path = 'public', 'extensions';
