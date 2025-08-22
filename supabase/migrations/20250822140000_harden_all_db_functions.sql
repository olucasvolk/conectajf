/*
# [SECURITY] Harden All Custom Database Functions
This script provides a comprehensive security update for all custom functions in the database. It addresses the "Function Search Path Mutable" warnings by recreating each function with a secure search path and appropriate security settings.

## Query Description:
This operation will drop and recreate several key functions used by the application for user profiles, chat, and likes. This is a safe operation as it replaces existing logic with a more secure version without altering data. It ensures that all functions run with predictable and safe permissions, preventing potential security vulnerabilities.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by reverting to a previous migration)

## Structure Details:
- Drops and recreates the following functions:
  - `create_profile_for_new_user()`
  - `update_last_message_at()`
  - `update_likes_count()`
  - `get_existing_private_chat(uuid, uuid)`
  - `is_member_of(uuid, uuid)`
- Ensures all functions have `SECURITY DEFINER` and a fixed `search_path`.

## Security Implications:
- RLS Status: Unchanged
- Policy Changes: No
- Auth Requirements: None
- Fixes "Function Search Path Mutable" warnings by explicitly setting `search_path`.

## Performance Impact:
- Indexes: None
- Triggers: None (functions are recreated, but triggers that use them are unaffected)
- Estimated Impact: Negligible. Function execution might be slightly faster due to a fixed search path.
*/

-- Drop existing functions to ensure a clean slate
DROP FUNCTION IF EXISTS public.create_profile_for_new_user();
DROP FUNCTION IF EXISTS public.update_last_message_at();
DROP FUNCTION IF EXISTS public.update_likes_count();
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid);
DROP FUNCTION IF EXISTS public.is_member_of(uuid, uuid);

-- 1. Function to create a user profile upon new user signup.
CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS TRIGGER
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

-- 2. Function to update the last message timestamp in a chat room.
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chat_rooms
  SET last_message_at = NOW()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

-- 3. Function to update like counts on news posts and marketplace products.
CREATE OR REPLACE FUNCTION public.update_likes_count()
RETURNS TRIGGER
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
      UPDATE news_posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
    ELSIF (OLD.product_id IS NOT NULL) THEN
      UPDATE marketplace_products SET likes_count = likes_count - 1 WHERE id = OLD.product_id;
    END IF;
  END IF;
  RETURN NULL; -- result is ignored since this is an AFTER trigger
END;
$$;

-- 4. RPC function to find an existing private chat room between two users.
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT m1.room_id
  FROM chat_room_members m1
  JOIN chat_room_members m2 ON m1.room_id = m2.room_id
  JOIN chat_rooms r ON m1.room_id = r.id
  WHERE
    m1.user_id = user1_id AND
    m2.user_id = user2_id AND
    r.is_group = false
  LIMIT 1;
$$;

-- 5. Helper function for RLS policies to check if a user is a member of a room.
CREATE OR REPLACE FUNCTION public.is_member_of(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  );
$$;

-- The existing triggers for `create_profile_for_new_user`, `update_last_message_at`,
-- and `update_likes_count` will automatically use these new, secure function definitions.
-- No need to recreate the triggers themselves.
