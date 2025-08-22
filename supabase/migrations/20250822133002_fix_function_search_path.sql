/*
  # [Fix Function Security] Set explicit search_path for database functions

  This migration addresses the "Function Search Path Mutable" security warning by explicitly setting the `search_path` for all custom database functions. This prevents potential hijacking attacks where a malicious user could create objects (like tables or functions) in a schema that the function might inadvertently use.

  ## Query Description:
  - This operation is safe and non-destructive. It modifies the definitions of existing functions without altering any data.
  - It re-creates four functions (`handle_new_user`, `get_existing_private_chat`, `get_chat_rooms_for_user`, `is_member_of`) to include `SET search_path = 'public'`.
  - This ensures that the functions always operate within the intended `public` schema, enhancing security and stability.

  ## Metadata:
  - Schema-Category: "Safe"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true

  ## Structure Details:
  - Functions being modified:
    - `public.handle_new_user()`
    - `public.get_existing_private_chat(uuid, uuid)`
    - `public.get_chat_rooms_for_user(uuid)`
    - `public.is_member_of(uuid, uuid)`

  ## Security Implications:
  - RLS Status: Unchanged
  - Policy Changes: No
  - Auth Requirements: None
  - **Benefit**: Mitigates the "Function Search Path Mutable" security vulnerability.

  ## Performance Impact:
  - Indexes: None
  - Triggers: The `handle_new_user` trigger function is updated, but its performance remains the same.
  - Estimated Impact: Negligible. The change is to the function definition and has no runtime performance cost.
*/

-- 1. Secure the `handle_new_user` trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public' -- Fix: Explicitly set search_path
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.raw_user_meta_data ->> 'username'
  );
  RETURN NEW;
END;
$$;

-- 2. Secure the `get_existing_private_chat` RPC function
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public' -- Fix: Explicitly set search_path
AS $$
  SELECT r.id
  FROM chat_rooms r
  WHERE r.is_group = false AND EXISTS (
    SELECT 1
    FROM chat_room_members m1
    WHERE m1.room_id = r.id AND m1.user_id = user1_id
  ) AND EXISTS (
    SELECT 1
    FROM chat_room_members m2
    WHERE m2.room_id = r.id AND m2.user_id = user2_id
  )
  LIMIT 1;
$$;

-- 3. Secure the `get_chat_rooms_for_user` helper function
CREATE OR REPLACE FUNCTION public.get_chat_rooms_for_user(p_user_id uuid)
RETURNS TABLE(id uuid, name text, is_group boolean, last_message_at timestamptz, created_by uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public' -- Fix: Explicitly set search_path
AS $$
  SELECT cr.id, cr.name, cr.is_group, cr.last_message_at, cr.created_by
  FROM chat_rooms cr
  JOIN chat_room_members crm ON cr.id = crm.room_id
  WHERE crm.user_id = p_user_id;
$$;

-- 4. Secure the `is_member_of` helper function
CREATE OR REPLACE FUNCTION public.is_member_of(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public' -- Fix: Explicitly set search_path
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  );
$$;
