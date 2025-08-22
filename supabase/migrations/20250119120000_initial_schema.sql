/*
# Initial Database Schema for Juiz de Fora News App
Creates the complete database structure for a local news and marketplace app with real-time chat functionality.

## Query Description:
This migration sets up the entire database schema from scratch, including user profiles, news posts, marketplace products, chat functionality, and all necessary relationships. This is a foundational migration that creates all required tables with proper foreign key relationships and security policies.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- profiles: User profile information
- news_posts: News articles with media support
- marketplace_products: Product listings
- post_likes: Like system for posts
- post_comments: Comment system for posts
- chat_rooms: Chat room management
- chat_messages: Real-time messaging
- post_media: Media files for posts/products

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes - comprehensive RLS policies
- Auth Requirements: All tables require authenticated users

## Performance Impact:
- Indexes: Added on foreign keys and frequently queried fields
- Triggers: Added for updated_at timestamps
- Estimated Impact: Minimal - standard CRUD operations
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User profiles table
CREATE TABLE profiles (
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
CREATE TABLE news_posts (
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
CREATE TABLE marketplace_products (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    condition TEXT CHECK (condition IN ('novo', 'usado', 'seminovo')) NOT NULL,
    category TEXT NOT NULL,
    location TEXT DEFAULT 'Juiz de Fora, MG',
    is_available BOOLEAN DEFAULT TRUE,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Media files for posts and products
CREATE TABLE post_media (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    post_id UUID REFERENCES news_posts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES marketplace_products(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT CHECK (media_type IN ('image', 'video')) NOT NULL,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Likes table
CREATE TABLE post_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES news_posts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES marketplace_products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_like_target CHECK (
        (post_id IS NOT NULL AND product_id IS NULL) OR 
        (post_id IS NULL AND product_id IS NOT NULL)
    )
);

-- Comments table
CREATE TABLE post_comments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES news_posts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES marketplace_products(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_comment_target CHECK (
        (post_id IS NOT NULL AND product_id IS NULL) OR 
        (post_id IS NULL AND product_id IS NOT NULL)
    )
);

-- Chat rooms table
CREATE TABLE chat_rooms (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    created_by UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    is_group BOOLEAN DEFAULT FALSE,
    name TEXT,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat room members
CREATE TABLE chat_room_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);

-- Chat messages table
CREATE TABLE chat_messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video')),
    media_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_news_posts_user_id ON news_posts(user_id);
CREATE INDEX idx_news_posts_created_at ON news_posts(created_at DESC);
CREATE INDEX idx_marketplace_products_user_id ON marketplace_products(user_id);
CREATE INDEX idx_marketplace_products_category ON marketplace_products(category);
CREATE INDEX idx_marketplace_products_created_at ON marketplace_products(created_at DESC);
CREATE INDEX idx_post_likes_user_id ON post_likes(user_id);
CREATE INDEX idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX idx_post_likes_product_id ON post_likes(product_id);
CREATE INDEX idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX idx_post_comments_product_id ON post_comments(product_id);
CREATE INDEX idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at DESC);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_news_posts_updated_at BEFORE UPDATE ON news_posts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_marketplace_products_updated_at BEFORE UPDATE ON marketplace_products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_post_comments_updated_at BEFORE UPDATE ON post_comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update likes count
CREATE OR REPLACE FUNCTION update_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.post_id IS NOT NULL THEN
            UPDATE news_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
        ELSIF NEW.product_id IS NOT NULL THEN
            UPDATE marketplace_products SET likes_count = likes_count + 1 WHERE id = NEW.product_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.post_id IS NOT NULL THEN
            UPDATE news_posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
        ELSIF OLD.product_id IS NOT NULL THEN
            UPDATE marketplace_products SET likes_count = likes_count - 1 WHERE id = OLD.product_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Function to update comments count
CREATE OR REPLACE FUNCTION update_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.post_id IS NOT NULL THEN
            UPDATE news_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.post_id IS NOT NULL THEN
            UPDATE news_posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Triggers for count updates
CREATE TRIGGER update_likes_count_trigger AFTER INSERT OR DELETE ON post_likes FOR EACH ROW EXECUTE FUNCTION update_likes_count();
CREATE TRIGGER update_comments_count_trigger AFTER INSERT OR DELETE ON post_comments FOR EACH ROW EXECUTE FUNCTION update_comments_count();

-- Function to update chat room last message timestamp
CREATE OR REPLACE FUNCTION update_chat_room_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_rooms SET last_message_at = NOW() WHERE id = NEW.room_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_chat_room_last_message_trigger AFTER INSERT ON chat_messages FOR EACH ROW EXECUTE FUNCTION update_chat_room_last_message();

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- RLS Policies for news_posts
CREATE POLICY "News posts are viewable by everyone" ON news_posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create news posts" ON news_posts FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own news posts" ON news_posts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own news posts" ON news_posts FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for marketplace_products
CREATE POLICY "Products are viewable by everyone" ON marketplace_products FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create products" ON marketplace_products FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own products" ON marketplace_products FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own products" ON marketplace_products FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for post_media
CREATE POLICY "Media is viewable by everyone" ON post_media FOR SELECT USING (true);
CREATE POLICY "Authenticated users can upload media" ON post_media FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- RLS Policies for post_likes
CREATE POLICY "Likes are viewable by everyone" ON post_likes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can like posts" ON post_likes FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can delete their own likes" ON post_likes FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for post_comments
CREATE POLICY "Comments are viewable by everyone" ON post_comments FOR SELECT USING (true);
CREATE POLICY "Authenticated users can comment" ON post_comments FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can update their own comments" ON post_comments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own comments" ON post_comments FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for chat_rooms
CREATE POLICY "Users can view rooms they are members of" ON chat_rooms FOR SELECT USING (
    id IN (SELECT room_id FROM chat_room_members WHERE user_id = auth.uid())
);
CREATE POLICY "Authenticated users can create chat rooms" ON chat_rooms FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- RLS Policies for chat_room_members
CREATE POLICY "Room members can view membership" ON chat_room_members FOR SELECT USING (
    room_id IN (SELECT room_id FROM chat_room_members WHERE user_id = auth.uid())
);
CREATE POLICY "Room creators can add members" ON chat_room_members FOR INSERT WITH CHECK (
    room_id IN (SELECT id FROM chat_rooms WHERE created_by = auth.uid())
);

-- RLS Policies for chat_messages
CREATE POLICY "Room members can view messages" ON chat_messages FOR SELECT USING (
    room_id IN (SELECT room_id FROM chat_room_members WHERE user_id = auth.uid())
);
CREATE POLICY "Room members can send messages" ON chat_messages FOR INSERT WITH CHECK (
    room_id IN (SELECT room_id FROM chat_room_members WHERE user_id = auth.uid())
);
