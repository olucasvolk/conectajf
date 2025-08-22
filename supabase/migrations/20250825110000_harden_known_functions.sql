/*
# [Harden Known Database Functions]
This migration resolves several "Function Search Path Mutable" security warnings by setting a fixed, non-mutable search_path for known database functions. This is an important security measure to prevent potential SQL injection attacks via search path manipulation.

## Query Description:
- This operation modifies the definitions of existing database functions to improve security.
- It is a non-destructive change and does not affect any data.
- Note: This script targets functions that can be inferred from the application code. If warnings persist after applying this migration, it indicates that other custom functions exist in your database that also need to be secured.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by removing the SET clause from each function)

## Structure Details:
- Affects functions: handle_new_user, update_last_message_at, get_existing_private_chat.

## Security Implications:
- RLS Status: Not affected
- Policy Changes: No
- Auth Requirements: None

## Performance Impact:
- Indexes: Not affected
- Triggers: Not affected
- Estimated Impact: Negligible.
*/

-- Harden the trigger function for creating new user profiles upon signup.
ALTER FUNCTION public.handle_new_user() SET search_path = 'public';

-- Harden the trigger function for updating the last_message_at timestamp in chat rooms.
ALTER FUNCTION public.update_last_message_at() SET search_path = 'public';

-- Harden the RPC function used to find existing one-on-one chat rooms.
ALTER FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid) SET search_path = 'public';
