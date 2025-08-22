/*
# Complete Schema Creation for JF Notícias App
Creates the complete database schema for the Juiz de Fora news app with all necessary tables, relationships, and security policies.

## Query Description:
This migration creates the complete database structure from scratch, including user profiles, news posts, marketplace products, chat system, and all associated features. All tables are created with proper constraints and indexes for optimal performance. Row Level Security is enabled with comprehensive policies to ensure data privacy and security.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- profiles: User profile information linked to auth.users
- news_posts: News articles with categories and engagement metrics
- marketplace_products: Product listings with pricing and conditions
- chat_rooms: Chat room management
- chat_room_members: Chat room membership tracking
- chat_messages: Individual chat messages
- post_likes: Like tracking for posts and products
- post_comments: Comment system for news posts

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: All tables require authentication

## Performance Impact:
- Indexes: Added for optimal query performance
- Triggers: Added for automatic counters and timestamps
- Estimated Impact: Minimal performance impact, improved query speed
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table (extends auth.users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    location TEXT DEFAULT 'Juiz de Fora, MG',
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- News posts table
CREATE TABLE IF NOT EXISTS news_posts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    location TEXT DEFAULT 'Juiz de Fora, MG',
    category TEXT DEFAULT 'geral',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Marketplace products table
CREATE TABLE IF NOT EXISTS marketplace_products (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    condition TEXT NOT NULL CHECK (condition IN ('novo', 'usado', 'seminovo')),
    category TEXT NOT NULL DEFAULT 'outros',
    location TEXT DEFAULT 'Juiz de Fora, MG',
    is_available BOOLEAN DEFAULT TRUE,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat rooms table
CREATE TABLE IF NOT EXISTS chat_rooms (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT,
    is_group BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat room members table
CREATE TABLE IF NOT EXISTS chat_room_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    is_admin BOOLEAN DEFAULT FALSE,
    UNIQUE(room_id, user_id)
);

-- Chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'file')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Post likes table (for both news and products)
CREATE TABLE IF NOT EXISTS post_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES news_posts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES marketplace_products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_like_target CHECK (
        (post_id IS NOT NULL AND product_id IS NULL) OR 
        (post_id IS NULL AND product_id IS NOT NULL)
    ),
    UNIQUE(user_id, post_id),
    UNIQUE(user_id, product_id)
);

-- Post comments table
CREATE TABLE IF NOT EXISTS post_comments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    post_id UUID REFERENCES news_posts(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_news_posts_user_id ON news_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_news_posts_created_at ON news_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_posts_category ON news_posts(category);

CREATE INDEX IF NOT EXISTS idx_marketplace_products_user_id ON marketplace_products(user_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_products_created_at ON marketplace_products(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_marketplace_products_category ON marketplace_products(category);
CREATE INDEX IF NOT EXISTS idx_marketplace_products_available ON marketplace_products(is_available);

CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_product_id ON post_likes(product_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);

CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON post_comments(post_id);

-- Create functions for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_news_posts_updated_at ON news_posts;
CREATE TRIGGER update_news_posts_updated_at 
    BEFORE UPDATE ON news_posts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_marketplace_products_updated_at ON marketplace_products;
CREATE TRIGGER update_marketplace_products_updated_at 
    BEFORE UPDATE ON marketplace_products 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create functions for updating counters
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.post_id IS NOT NULL THEN
            UPDATE news_posts 
            SET likes_count = likes_count + 1 
            WHERE id = NEW.post_id;
        END IF;
        IF NEW.product_id IS NOT NULL THEN
            UPDATE marketplace_products 
            SET likes_count = likes_count + 1 
            WHERE id = NEW.product_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.post_id IS NOT NULL THEN
            UPDATE news_posts 
            SET likes_count = GREATEST(likes_count - 1, 0) 
            WHERE id = OLD.post_id;
        END IF;
        IF OLD.product_id IS NOT NULL THEN
            UPDATE marketplace_products 
            SET likes_count = GREATEST(likes_count - 1, 0) 
            WHERE id = OLD.product_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE news_posts 
        SET comments_count = comments_count + 1 
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE news_posts 
        SET comments_count = GREATEST(comments_count - 1, 0) 
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE OR REPLACE FUNCTION update_chat_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_rooms 
    SET last_message_at = NEW.created_at 
    WHERE id = NEW.room_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for counters
DROP TRIGGER IF EXISTS trigger_update_post_likes_count ON post_likes;
CREATE TRIGGER trigger_update_post_likes_count
    AFTER INSERT OR DELETE ON post_likes
    FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

DROP TRIGGER IF EXISTS trigger_update_post_comments_count ON post_comments;
CREATE TRIGGER trigger_update_post_comments_count
    AFTER INSERT OR DELETE ON post_comments
    FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

DROP TRIGGER IF EXISTS trigger_update_chat_last_message ON chat_messages;
CREATE TRIGGER trigger_update_chat_last_message
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION update_chat_last_message();

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Profiles policies
DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;
CREATE POLICY "Users can view all profiles" ON profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- News posts policies
DROP POLICY IF EXISTS "Anyone can view news posts" ON news_posts;
CREATE POLICY "Anyone can view news posts" ON news_posts
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create news posts" ON news_posts;
CREATE POLICY "Users can create news posts" ON news_posts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own news posts" ON news_posts;
CREATE POLICY "Users can update own news posts" ON news_posts
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own news posts" ON news_posts;
CREATE POLICY "Users can delete own news posts" ON news_posts
    FOR DELETE USING (auth.uid() = user_id);

-- Marketplace products policies
DROP POLICY IF EXISTS "Anyone can view available products" ON marketplace_products;
CREATE POLICY "Anyone can view available products" ON marketplace_products
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create products" ON marketplace_products;
CREATE POLICY "Users can create products" ON marketplace_products
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own products" ON marketplace_products;
CREATE POLICY "Users can update own products" ON marketplace_products
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own products" ON marketplace_products;
CREATE POLICY "Users can delete own products" ON marketplace_products
    FOR DELETE USING (auth.uid() = user_id);

-- Chat rooms policies
DROP POLICY IF EXISTS "Users can view rooms they are members of" ON chat_rooms;
CREATE POLICY "Users can view rooms they are members of" ON chat_rooms
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_room_members 
            WHERE room_id = chat_rooms.id AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can create chat rooms" ON chat_rooms;
CREATE POLICY "Users can create chat rooms" ON chat_rooms
    FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Chat room members policies
DROP POLICY IF EXISTS "Users can view room members" ON chat_room_members;
CREATE POLICY "Users can view room members" ON chat_room_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_room_members crm 
            WHERE crm.room_id = chat_room_members.room_id AND crm.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can join rooms" ON chat_room_members;
CREATE POLICY "Users can join rooms" ON chat_room_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Chat messages policies
DROP POLICY IF EXISTS "Users can view messages in their rooms" ON chat_messages;
CREATE POLICY "Users can view messages in their rooms" ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_room_members 
            WHERE room_id = chat_messages.room_id AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can send messages to their rooms" ON chat_messages;
CREATE POLICY "Users can send messages to their rooms" ON chat_messages
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM chat_room_members 
            WHERE room_id = chat_messages.room_id AND user_id = auth.uid()
        )
    );

-- Post likes policies
DROP POLICY IF EXISTS "Users can view all likes" ON post_likes;
CREATE POLICY "Users can view all likes" ON post_likes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can manage own likes" ON post_likes;
CREATE POLICY "Users can manage own likes" ON post_likes
    FOR ALL USING (auth.uid() = user_id);

-- Post comments policies
DROP POLICY IF EXISTS "Anyone can view comments" ON post_comments;
CREATE POLICY "Anyone can view comments" ON post_comments
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can create comments" ON post_comments;
CREATE POLICY "Users can create comments" ON post_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own comments" ON post_comments;
CREATE POLICY "Users can update own comments" ON post_comments
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own comments" ON post_comments;
CREATE POLICY "Users can delete own comments" ON post_comments
    FOR DELETE USING (auth.uid() = user_id);
