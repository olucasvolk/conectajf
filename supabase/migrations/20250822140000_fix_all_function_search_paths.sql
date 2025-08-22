/*
          # [OPERATION] Secure All Custom Functions
          This migration script hardens the security of all custom PostgreSQL functions in the database by explicitly setting the `search_path`. This is a critical security best practice that prevents a class of vulnerabilities where a malicious user could potentially execute arbitrary code by creating objects (like tables or functions) in a schema they control.

          ## Query Description:
          This operation is **completely safe** and has **no impact on existing data or application functionality**. It only modifies the metadata of the functions to make them more secure. It iterates through all known custom functions and applies the `ALTER FUNCTION` command to set their `search_path` to `'public'`.

          ## Metadata:
          - Schema-Category: "Safe"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - `handle_new_user()`
          - `update_last_message_at()`
          - `increment_likes_count()`
          - `decrement_likes_count()`
          - `increment_comments_count()`
          - `decrement_comments_count()`
          - `get_existing_private_chat(uuid, uuid)`
          - `check_user_in_room(uuid, uuid)`
          - `get_chat_rooms_for_user(uuid)`
          - `is_chat_member(uuid, uuid)`

          ## Security Implications:
          - RLS Status: Not Affected
          - Policy Changes: No
          - Auth Requirements: None
          - **Benefit**: Mitigates the "Function Search Path Mutable" security warning by preventing potential privilege escalation attacks.

          ## Performance Impact:
          - Indexes: Not Affected
          - Triggers: Not Affected
          - Estimated Impact: None. This is a metadata change with no runtime performance impact.
          */

-- Secure all custom functions by setting a non-mutable search path.
ALTER FUNCTION public.handle_new_user() SET search_path = 'public';
ALTER FUNCTION public.update_last_message_at() SET search_path = 'public';
ALTER FUNCTION public.increment_likes_count() SET search_path = 'public';
ALTER FUNCTION public.decrement_likes_count() SET search_path = 'public';
ALTER FUNCTION public.increment_comments_count() SET search_path = 'public';
ALTER FUNCTION public.decrement_comments_count() SET search_path = 'public';
ALTER FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid) SET search_path = 'public';
ALTER FUNCTION public.check_user_in_room(p_room_id uuid, p_user_id uuid) SET search_path = 'public';
ALTER FUNCTION public.get_chat_rooms_for_user(p_user_id uuid) SET search_path = 'public';
ALTER FUNCTION public.is_chat_member(room_id uuid, user_id uuid) SET search_path = 'public';
