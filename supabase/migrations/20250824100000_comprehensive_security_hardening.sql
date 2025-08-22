/*
# [Comprehensive Security Hardening]
This migration addresses critical security advisories by enabling Row Level Security (RLS) on all application tables and hardening all database functions against potential vulnerabilities.

## Query Description:
This script is primarily structural and preventative. It enables security features that were previously configured but not activated, and it secures database functions.
- **RLS Activation:** Enables Row Level Security for all tables. This is a critical step to ensure that the defined access policies are actually enforced. Without this, your data is publicly accessible despite having policies written.
- **Function Hardening:** Redefines all custom database functions to be more secure. This involves setting them as `SECURITY DEFINER` and explicitly setting the `search_path`. This prevents a class of attacks known as search path hijacking and ensures functions run with predictable permissions.

There should be no impact on existing data. This is a safe, but critical, security update.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- **Tables Affected (RLS Enabled):**
  - public.profiles
  - public.news_posts
  - public.marketplace_products
  - public.post_likes
  - public.post_comments
  - public.chat_rooms
  - public.chat_room_members
  - public.chat_messages
- **Functions Re-defined (Hardened):**
  - public.get_existing_private_chat(user1_id uuid, user2_id uuid)
  - public.handle_new_user()
  - public.update_last_message_at_on_new_message()
  - public.get_post_likes_count(post_id_param uuid)
  - public.get_product_likes_count(product_id_param uuid)

## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: No. Existing policies will now be enforced.
- Auth Requirements: No change.
- This migration directly resolves multiple `[ERROR]` and `[WARN]` level security advisories.

## Performance Impact:
- Indexes: None.
- Triggers: None.
- Estimated Impact: Negligible. RLS adds a small overhead to queries, but it is essential for security and is highly optimized.
*/

-- Step 1: Enable Row Level Security on all relevant tables
-- This is the most critical fix for the "RLS Disabled" errors.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Step 2: Harden all database functions
-- This fixes the "Function Search Path Mutable" warnings.

-- Function to find an existing private chat room between two users.
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN (
    SELECT cr.id
    FROM chat_rooms cr
    JOIN chat_room_members crm1 ON cr.id = crm1.room_id
    JOIN chat_room_members crm2 ON cr.id = crm2.room_id
    WHERE
      cr.is_group = false
      AND crm1.user_id = user1_id
      AND crm2.user_id = user2_id
    LIMIT 1
  );
END;
$$;

-- Function to create a profile for a new user upon signup.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
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

-- Function to update the last_message_at timestamp in a chat room.
CREATE OR REPLACE FUNCTION public.update_last_message_at_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE public.chat_rooms
  SET last_message_at = NOW()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

-- Function to get the like count for a news post.
CREATE OR REPLACE FUNCTION public.get_post_likes_count(post_id_param uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  likes_count integer;
BEGIN
  SELECT count(*)
  INTO likes_count
  FROM public.post_likes
  WHERE post_id = post_id_param;
  RETURN likes_count;
END;
$$;

-- Function to get the like count for a marketplace product.
CREATE OR REPLACE FUNCTION public.get_product_likes_count(product_id_param uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  likes_count integer;
BEGIN
  SELECT count(*)
  INTO likes_count
  FROM public.post_likes
  WHERE product_id = product_id_param;
  RETURN likes_count;
END;
$$;

-- Grant execute permissions to the authenticated role for the functions.
GRANT EXECUTE ON FUNCTION public.get_existing_private_chat(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_post_likes_count(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_likes_count(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_last_message_at_on_new_message() TO authenticated;

-- Ensure triggers are using the updated functions.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS on_new_chat_message_update_room_timestamp ON public.chat_messages;
CREATE TRIGGER on_new_chat_message_update_room_timestamp
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.update_last_message_at_on_new_message();
