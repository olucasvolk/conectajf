/*
# [DANGEROUS] Complete Schema Reset
This migration will completely drop all existing tables and data, then recreate the entire schema from scratch.

## Query Description:
- **IMPACT**: HIGH - ALL DATA WILL BE PERMANENTLY DELETED.
- **RISK**: This is a destructive operation. Before applying, ensure you have backed up any data you wish to preserve.
- **REASON**: To resolve persistent schema and RLS policy conflicts by starting with a clean, corrected structure.

## Metadata:
- Schema-Category: "Dangerous"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false

## Structure Details:
- **DROPS**: All application tables, types, and functions.
- **CREATES**: Corrected tables for profiles, posts, products, and chat.
- **SECURITY**: Enables RLS and applies secure policies for all tables.
- **FUNCTIONS**: Recreates triggers for profile creation and helper functions for chat.

## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: All policies are redefined to be secure and functional.
- Auth Requirements: Policies are based on `auth.uid()`.
*/

-- Step 1: Drop all existing objects in reverse order of dependency to avoid errors.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.create_profile_on_signup();
DROP FUNCTION IF EXISTS public.update_last_message_at();
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid);

DROP TABLE IF EXISTS public.chat_messages CASCADE;
DROP TABLE IF EXISTS public.chat_room_members CASCADE;
DROP TABLE IF EXISTS public.post_comments CASCADE;
DROP TABLE IF EXISTS public.post_likes CASCADE;
DROP TABLE IF EXISTS public.news_posts CASCADE;
DROP TABLE IF EXISTS public.marketplace_products CASCADE;
DROP TABLE IF EXISTS public.chat_rooms CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

DROP TYPE IF EXISTS public.message_status;
DROP TYPE IF EXISTS public.product_condition;

-- Step 2: Create custom types
CREATE TYPE public.message_status AS ENUM ('sending', 'sent', 'delivered', 'read');
CREATE TYPE public.product_condition AS ENUM ('novo', 'usado', 'seminovo');

-- Step 3: Create Tables
-- Profiles table (linked to auth.users)
CREATE TABLE public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username text UNIQUE NOT NULL,
    full_name text NOT NULL,
    avatar_url text,
    bio text,
    location text,
    phone text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.profiles IS 'Stores public user profile information.';

-- News Posts table
CREATE TABLE public.news_posts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title text NOT NULL,
    content text NOT NULL,
    location text,
    category text,
    likes_count integer DEFAULT 0 NOT NULL,
    comments_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.news_posts IS 'Stores news articles posted by users.';

-- Marketplace Products table
CREATE TABLE public.marketplace_products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text NOT NULL,
    price numeric(10, 2) NOT NULL,
    condition product_condition NOT NULL,
    category text NOT NULL,
    location text,
    is_available boolean DEFAULT true NOT NULL,
    likes_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.marketplace_products IS 'Stores products for sale in the marketplace.';

-- Likes table (for both news and products)
CREATE TABLE public.post_likes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id uuid REFERENCES public.news_posts(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.marketplace_products(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_once_per_item UNIQUE (user_id, post_id, product_id),
    CONSTRAINT either_post_or_product CHECK ((post_id IS NOT NULL AND product_id IS NULL) OR (post_id IS NULL AND product_id IS NOT NULL))
);
COMMENT ON TABLE public.post_likes IS 'Tracks user likes on news posts and marketplace products.';

-- Chat Rooms table
CREATE TABLE public.chat_rooms (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text,
    is_group boolean DEFAULT false NOT NULL,
    created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
    last_message_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.chat_rooms IS 'Stores information about chat rooms.';

-- Chat Room Members table
CREATE TABLE public.chat_room_members (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    is_typing boolean DEFAULT false NOT NULL,
    CONSTRAINT user_once_per_room UNIQUE (user_id, room_id)
);
COMMENT ON TABLE public.chat_room_members IS 'Associates users with chat rooms.';

-- Chat Messages table
CREATE TABLE public.chat_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content text NOT NULL,
    message_type text DEFAULT 'text'::text NOT NULL,
    status message_status DEFAULT 'sent'::message_status NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.chat_messages IS 'Stores messages within chat rooms.';

-- Step 4: Enable Row Level Security (RLS) for all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Step 5: Create RLS Policies
-- Profiles Policies
CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- News Posts Policies
CREATE POLICY "Anyone can view news posts" ON public.news_posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create news posts" ON public.news_posts FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own news posts" ON public.news_posts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own news posts" ON public.news_posts FOR DELETE USING (auth.uid() = user_id);

-- Marketplace Products Policies
CREATE POLICY "Anyone can view products" ON public.marketplace_products FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create products" ON public.marketplace_products FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own products" ON public.marketplace_products FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own products" ON public.marketplace_products FOR DELETE USING (auth.uid() = user_id);

-- Post Likes Policies
CREATE POLICY "Anyone can view likes" ON public.post_likes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create likes" ON public.post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own likes" ON public.post_likes FOR DELETE USING (auth.uid() = user_id);

-- Chat Policies (This is the critical part to fix the chat issues)
CREATE POLICY "Users can see chat rooms they are members of" ON public.chat_rooms FOR SELECT
  USING (id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));

CREATE POLICY "Authenticated users can create chat rooms" ON public.chat_rooms FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can see members of rooms they are in" ON public.chat_room_members FOR SELECT
  USING (room_id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can add themselves to a room" ON public.chat_room_members FOR INSERT
  WITH CHECK (user_id = auth.uid()); -- This is handled by backend logic, but policy provides a safeguard.

CREATE POLICY "Users can see messages in rooms they are members of" ON public.chat_messages FOR SELECT
  USING (room_id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));

CREATE POLICY "Users can send messages in rooms they are members of" ON public.chat_messages FOR INSERT
  WITH CHECK (room_id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));

-- Step 6: Create Functions and Triggers
-- Function to create a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.create_profile_on_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'username'
  );
  RETURN NEW;
END;
$$;

-- Trigger to call the function on new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.create_profile_on_signup();

-- Function to update the last message timestamp in a chat room
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.chat_rooms
  SET last_message_at = NOW()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

-- Trigger to update timestamp on new message
CREATE TRIGGER on_new_chat_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.update_last_message_at();

-- Function to efficiently find an existing private chat room
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT m1.room_id
  FROM chat_room_members m1
  JOIN chat_room_members m2 ON m1.room_id = m2.room_id
  JOIN chat_rooms r ON m1.room_id = r.id
  WHERE m1.user_id = user1_id AND m2.user_id = user2_id AND r.is_group = false;
$$;

-- Step 7: Create a Test User for Seeding (Optional)
-- The `sampleData.ts` script expects a user with the username 'vendedor_teste'.
-- It's best to create this user manually through the Supabase dashboard (Sign Up)
-- and then update their username in the `profiles` table if needed.
-- The trigger `on_auth_user_created` will automatically create their profile entry.
-- Example manual creation:
-- 1. Go to Authentication -> Users -> Add User.
-- 2. Use a test email and password.
-- 3. Go to Table Editor -> profiles table.
-- 4. Find the new user and change their `username` to 'vendedor_teste'.
-- This ensures the auth and profile data are correctly linked.

-- Final step: Refresh schema cache
NOTIFY pgrst, 'reload schema';
