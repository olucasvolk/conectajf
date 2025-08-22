/*
# [Fix] Comprehensive Security and Function Rebuild
This migration completely rebuilds all custom functions and triggers to resolve persistent security warnings and ensure database stability. It is idempotent and safe to run multiple times.

## Query Description:
This script will first drop all existing custom functions and their associated triggers to ensure a clean state. It then recreates them from scratch with the recommended security settings, including `SECURITY DEFINER` and a fixed `search_path`. This resolves all "Function Search Path Mutable" warnings and hardens the database against potential SQL injection vectors.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: true
- Reversible: false (Requires manual restoration of previous function versions)

## Structure Details:
- Drops and recreates functions: `is_member_of`, `get_chat_rooms_for_user`, `get_existing_private_chat`, `create_profile_for_new_user`, `update_last_message_at`, `update_likes_count`.
- Drops and recreates triggers: `on_auth_user_created`, `handle_new_message`, `handle_like_change`.

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: Requires database owner privileges to run.
- Fixes multiple "Function Search Path Mutable" security warnings.

## Performance Impact:
- Minimal impact during migration.
- Improves security and stability of database operations.
*/

-- Step 1: Drop existing triggers and functions to ensure a clean slate.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_message ON public.chat_messages;
DROP TRIGGER IF EXISTS handle_like_change ON public.post_likes;

DROP FUNCTION IF EXISTS public.create_profile_for_new_user();
DROP FUNCTION IF EXISTS public.update_last_message_at();
DROP FUNCTION IF EXISTS public.update_likes_count();
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_chat_rooms_for_user(uuid);
DROP FUNCTION IF EXISTS public.is_member_of(uuid, uuid);


-- Step 2: Recreate functions with proper security settings.

-- Function: is_member_of (Helper for RLS)
CREATE OR REPLACE FUNCTION public.is_member_of(p_user_id uuid, p_room_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM chat_room_members
    WHERE user_id = p_user_id AND room_id = p_room_id
  );
END;
$$;

-- Function: get_chat_rooms_for_user (RPC)
CREATE OR REPLACE FUNCTION public.get_chat_rooms_for_user(p_user_id uuid)
RETURNS TABLE(
  id uuid,
  name text,
  is_group boolean,
  last_message_at timestamptz,
  created_by uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cr.id,
    cr.name,
    cr.is_group,
    cr.last_message_at,
    cr.created_by
  FROM chat_rooms cr
  JOIN chat_room_members crm ON cr.id = crm.room_id
  WHERE crm.user_id = p_user_id
  ORDER BY cr.last_message_at DESC;
END;
$$;

-- Function: get_existing_private_chat (RPC)
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    room_id_result uuid;
BEGIN
    SELECT crm1.room_id INTO room_id_result
    FROM chat_room_members crm1
    JOIN chat_room_members crm2 ON crm1.room_id = crm2.room_id
    JOIN chat_rooms cr ON crm1.room_id = cr.id
    WHERE
        crm1.user_id = user1_id
        AND crm2.user_id = user2_id
        AND cr.is_group = false
    LIMIT 1;

    RETURN room_id_result;
END;
$$;

-- Function: create_profile_for_new_user
CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'username'
  );
  RETURN new;
END;
$$;

-- Function: update_last_message_at
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_rooms
  SET last_message_at = new.created_at
  WHERE id = new.room_id;
  RETURN new;
END;
$$;

-- Function: update_likes_count
CREATE OR REPLACE FUNCTION public.update_likes_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.post_id IS NOT NULL) THEN
      UPDATE news_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF (NEW.product_id IS NOT NULL) THEN
      UPDATE marketplace_products SET likes_count = likes_count + 1 WHERE id = NEW.product_id;
    END IF;
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.post_id IS NOT NULL) THEN
      UPDATE news_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
    ELSIF (OLD.product_id IS NOT NULL) THEN
      UPDATE marketplace_products SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.product_id;
    END IF;
  END IF;
  RETURN NULL; -- result is ignored since this is an AFTER trigger
END;
$$;


-- Step 3: Recreate triggers.

-- Trigger: on_auth_user_created
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.create_profile_for_new_user();

-- Trigger: handle_new_message
CREATE TRIGGER handle_new_message
AFTER INSERT ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.update_last_message_at();

-- Trigger: handle_like_change
CREATE TRIGGER handle_like_change
AFTER INSERT OR DELETE ON public.post_likes
FOR EACH ROW EXECUTE FUNCTION public.update_likes_count();
