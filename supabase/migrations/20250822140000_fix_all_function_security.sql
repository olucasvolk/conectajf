/*
  # [Comprehensive Security Fix]
  This migration script hardens the security of all custom database functions and triggers by explicitly setting the search_path and using SECURITY DEFINER where appropriate. This is the definitive fix for the "Function Search Path Mutable" warnings.

  ## Metadata:
  - Schema-Category: "Security"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (by recreating functions without these settings)
*/

-- Fix for: get_existing_private_chat
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid);
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
  WHERE crm1.user_id = user1_id
    AND crm2.user_id = user2_id
    AND cr.is_group = false
  LIMIT 1;
  
  RETURN room_id_result;
END;
$$;

-- Fix for: get_chat_rooms_for_user
DROP FUNCTION IF EXISTS public.get_chat_rooms_for_user(uuid);
CREATE OR REPLACE FUNCTION public.get_chat_rooms_for_user(p_user_id uuid)
RETURNS TABLE(id uuid, name text, is_group boolean, last_message_at timestamp with time zone, created_by uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT r.id, r.name, r.is_group, r.last_message_at, r.created_by
  FROM chat_rooms r
  JOIN chat_room_members m ON r.id = m.room_id
  WHERE m.user_id = p_user_id;
END;
$$;

-- Fix for trigger function: handle_new_user
CREATE OR REPLACE FUNCTION public.handle_new_user()
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

-- Fix for trigger function: update_likes_count
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
  RETURN NEW;
END;
$$;

-- Fix for trigger function: decrement_likes_count
CREATE OR REPLACE FUNCTION public.decrement_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.post_id IS NOT NULL THEN
        UPDATE news_posts
        SET likes_count = likes_count - 1
        WHERE id = OLD.post_id;
    ELSIF OLD.product_id IS NOT NULL THEN
        UPDATE marketplace_products
        SET likes_count = likes_count - 1
        WHERE id = OLD.product_id;
    END IF;
    RETURN OLD;
END;
$$;

-- Fix for trigger function: update_last_message_at
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE chat_rooms
  SET last_message_at = NOW()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

-- Grant permissions to the authenticated role
GRANT EXECUTE ON FUNCTION public.get_existing_private_chat(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_rooms_for_user(uuid) TO authenticated;

-- Re-affirm trigger bindings, just in case
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS on_like_created ON public.post_likes;
CREATE TRIGGER on_like_created
  AFTER INSERT ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public.update_likes_count();

DROP TRIGGER IF EXISTS on_like_deleted ON public.post_likes;
CREATE TRIGGER on_like_deleted
  AFTER DELETE ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public.decrement_likes_count();

DROP TRIGGER IF EXISTS on_new_message ON public.chat_messages;
CREATE TRIGGER on_new_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.update_last_message_at();
