/*
# [CRITICAL] Full Database Reset and Rebuild
This script will completely reset your database. ALL EXISTING DATA WILL BE DELETED.
This is a destructive operation and cannot be undone.

## Query Description:
This operation will:
1. Drop all existing application tables, functions, and types using CASCADE to resolve dependency issues.
2. Recreate the entire database schema from scratch with proper configurations.
3. Implement correct Row Level Security (RLS) policies for all tables.
4. Re-create all necessary database functions and triggers for the application to work correctly.

Please back up any important data before running this script.

## Metadata:
- Schema-Category: "Dangerous"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false
*/

-- PART 1: TEARDOWN (DROP ALL EXISTING OBJECTS)
-- Drop tables in reverse order of dependency, using CASCADE to handle triggers, etc.
DROP TABLE IF EXISTS public.post_comments CASCADE;
DROP TABLE IF EXISTS public.post_likes CASCADE;
DROP TABLE IF EXISTS public.chat_messages CASCADE;
DROP TABLE IF EXISTS public.chat_room_members CASCADE;
DROP TABLE IF EXISTS public.news_posts CASCADE;
DROP TABLE IF EXISTS public.marketplace_products CASCADE;
DROP TABLE IF EXISTS public.chat_rooms CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop functions using CASCADE
DROP FUNCTION IF EXISTS public.create_profile_on_signup() CASCADE;
DROP FUNCTION IF EXISTS public.update_likes_count() CASCADE;
DROP FUNCTION IF EXISTS public.update_comments_count() CASCADE;
DROP FUNCTION IF EXISTS public.update_last_message_at() CASCADE;
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid) CASCADE;

-- Drop types
DROP TYPE IF EXISTS public.message_status;
DROP TYPE IF EXISTS public.product_condition;


-- PART 2: REBUILDING THE SCHEMA
-- Create ENUM types
CREATE TYPE public.product_condition AS ENUM ('novo', 'seminovo', 'usado');
CREATE TYPE public.message_status AS ENUM ('sending', 'sent', 'delivered', 'read');

-- Create profiles table
CREATE TABLE public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    location TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.profiles IS 'Stores user profile information.';

-- Create chat_rooms table
CREATE TABLE public.chat_rooms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    is_group BOOLEAN NOT NULL DEFAULT false,
    created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.chat_rooms IS 'Stores information about chat rooms.';

-- Create chat_room_members table
CREATE TABLE public.chat_room_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_typing BOOLEAN NOT NULL DEFAULT false,
    UNIQUE(room_id, user_id)
);
COMMENT ON TABLE public.chat_room_members IS 'Associates users with chat rooms.';

-- Create chat_messages table
CREATE TABLE public.chat_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'text',
    status public.message_status NOT NULL DEFAULT 'sent',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.chat_messages IS 'Stores individual chat messages.';

-- Create news_posts table
CREATE TABLE public.news_posts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    location TEXT,
    category TEXT,
    likes_count INT NOT NULL DEFAULT 0,
    comments_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.news_posts IS 'Stores news articles posted by users.';

-- Create marketplace_products table
CREATE TABLE public.marketplace_products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    condition public.product_condition NOT NULL,
    category TEXT NOT NULL,
    location TEXT,
    is_available BOOLEAN NOT NULL DEFAULT true,
    likes_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.marketplace_products IS 'Stores products listed for sale.';

-- Create post_likes table
CREATE TABLE public.post_likes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id uuid REFERENCES public.news_posts(id) ON DELETE CASCADE,
    product_id uuid REFERENCES public.marketplace_products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT one_like_per_item CHECK (
        (post_id IS NOT NULL AND product_id IS NULL) OR 
        (post_id IS NULL AND product_id IS NOT NULL)
    ),
    UNIQUE(user_id, post_id),
    UNIQUE(user_id, product_id)
);
COMMENT ON TABLE public.post_likes IS 'Tracks likes on news posts and products.';

-- Create post_comments table
CREATE TABLE public.post_comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id uuid NOT NULL REFERENCES public.news_posts(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.post_comments IS 'Stores comments on news posts.';


-- PART 3: FUNCTIONS AND TRIGGERS
-- Function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.create_profile_on_signup()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'username'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.create_profile_on_signup() IS 'Automatically creates a user profile upon new user signup in auth.users.';

-- Trigger for profile creation
CREATE TRIGGER on_new_user_signup
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.create_profile_on_signup();

-- Function to update like counts
CREATE OR REPLACE FUNCTION public.update_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.post_id IS NOT NULL) THEN
      UPDATE public.news_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF (NEW.product_id IS NOT NULL) THEN
      UPDATE public.marketplace_products SET likes_count = likes_count + 1 WHERE id = NEW.product_id;
    END IF;
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.post_id IS NOT NULL) THEN
      UPDATE public.news_posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
    ELSIF (OLD.product_id IS NOT NULL) THEN
      UPDATE public.marketplace_products SET likes_count = likes_count - 1 WHERE id = OLD.product_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.update_likes_count() IS 'Updates the likes_count on news_posts or marketplace_products when a like is added or removed.';

-- Trigger for like counts
CREATE TRIGGER on_like_change
AFTER INSERT OR DELETE ON public.post_likes
FOR EACH ROW EXECUTE FUNCTION public.update_likes_count();

-- Function to update comment counts
CREATE OR REPLACE FUNCTION public.update_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.news_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.news_posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.update_comments_count() IS 'Updates the comments_count on news_posts when a comment is added or removed.';

-- Trigger for comment counts
CREATE TRIGGER on_comment_change
AFTER INSERT OR DELETE ON public.post_comments
FOR EACH ROW EXECUTE FUNCTION public.update_comments_count();

-- Function to update last_message_at in chat_rooms
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.chat_rooms
  SET last_message_at = NOW()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.update_last_message_at() IS 'Updates the last_message_at timestamp in a chat room upon a new message.';

-- Trigger for last message timestamp
CREATE TRIGGER on_new_message
AFTER INSERT ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.update_last_message_at();

-- RPC function to find an existing private chat
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid AS $$
DECLARE
  chat_id uuid;
BEGIN
  SELECT m1.room_id INTO chat_id
  FROM public.chat_room_members AS m1
  JOIN public.chat_room_members AS m2 ON m1.room_id = m2.room_id
  JOIN public.chat_rooms AS cr ON m1.room_id = cr.id
  WHERE m1.user_id = user1_id
    AND m2.user_id = user2_id
    AND cr.is_group = false
  LIMIT 1;
  RETURN chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
COMMENT ON FUNCTION public.get_existing_private_chat(uuid, uuid) IS 'Finds an existing 1-on-1 chat room between two users.';


-- PART 4: ROW LEVEL SECURITY (RLS)
-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for PROFILES
CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can delete their own profile" ON public.profiles FOR DELETE USING (auth.uid() = id);

-- RLS Policies for NEWS_POSTS
CREATE POLICY "Users can view all news posts" ON public.news_posts FOR SELECT USING (true);
CREATE POLICY "Users can insert their own news posts" ON public.news_posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own news posts" ON public.news_posts FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own news posts" ON public.news_posts FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for MARKETPLACE_PRODUCTS
CREATE POLICY "Users can view all marketplace products" ON public.marketplace_products FOR SELECT USING (true);
CREATE POLICY "Users can insert their own products" ON public.marketplace_products FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own products" ON public.marketplace_products FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own products" ON public.marketplace_products FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for POST_LIKES
CREATE POLICY "Users can view all likes" ON public.post_likes FOR SELECT USING (true);
CREATE POLICY "Users can insert their own likes" ON public.post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own likes" ON public.post_likes FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for POST_COMMENTS
CREATE POLICY "Users can view all comments" ON public.post_comments FOR SELECT USING (true);
CREATE POLICY "Users can insert their own comments" ON public.post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own comments" ON public.post_comments FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own comments" ON public.post_comments FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for CHAT_ROOMS
CREATE POLICY "Users can view rooms they are members of" ON public.chat_rooms FOR SELECT USING (id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));
CREATE POLICY "Users can create new chat rooms" ON public.chat_rooms FOR INSERT WITH CHECK (auth.uid() = created_by);

-- RLS Policies for CHAT_ROOM_MEMBERS
CREATE POLICY "Users can view members of rooms they are in" ON public.chat_room_members FOR SELECT USING (room_id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));
CREATE POLICY "Users can add themselves to a room" ON public.chat_room_members FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update their own typing status" ON public.chat_room_members FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can remove themselves from a room" ON public.chat_room_members FOR DELETE USING (user_id = auth.uid());

-- RLS Policies for CHAT_MESSAGES
CREATE POLICY "Users can view messages in rooms they are members of" ON public.chat_messages FOR SELECT USING (room_id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));
CREATE POLICY "Users can insert messages in rooms they are members of" ON public.chat_messages FOR INSERT WITH CHECK (user_id = auth.uid() AND room_id IN (SELECT room_id FROM public.chat_room_members WHERE user_id = auth.uid()));
CREATE POLICY "Users can update their own message status" ON public.chat_messages FOR UPDATE USING (auth.uid() = user_id);
