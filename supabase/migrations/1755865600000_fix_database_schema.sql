/*
# Correção do Schema do Banco de Dados - JF Notícias
Esta migração corrige e completa o schema do banco de dados, criando apenas as tabelas e estruturas que ainda não existem.

## Query Description: 
Esta operação irá verificar e criar apenas as tabelas necessárias que não existem no banco. É uma operação segura que não afetará dados existentes. Recomenda-se backup por precaução, mas o risco é mínimo.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low" 
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Tabelas: news_posts, marketplace_products, post_likes, comments, chat_rooms, chat_room_members, messages
- Colunas: Estrutura completa para app de notícias e marketplace
- Constraints: Chaves primárias, estrangeiras e índices

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: Políticas RLS para controle de acesso

## Performance Impact:
- Indexes: Added
- Triggers: Added
- Estimated Impact: Melhoria na performance de consultas
*/

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Atualizar tabela profiles se necessário (apenas adicionar colunas que não existem)
DO $$ 
BEGIN
    -- Adicionar coluna bio se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'bio') THEN
        ALTER TABLE profiles ADD COLUMN bio TEXT;
    END IF;
    
    -- Adicionar coluna location se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'location') THEN
        ALTER TABLE profiles ADD COLUMN location TEXT;
    END IF;
    
    -- Adicionar coluna phone se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'phone') THEN
        ALTER TABLE profiles ADD COLUMN phone TEXT;
    END IF;
    
    -- Adicionar coluna updated_at se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'updated_at') THEN
        ALTER TABLE profiles ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Criar tabela news_posts se não existir
CREATE TABLE IF NOT EXISTS news_posts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    location TEXT,
    category TEXT DEFAULT 'geral',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela marketplace_products se não existir
CREATE TABLE IF NOT EXISTS marketplace_products (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    condition TEXT CHECK (condition IN ('novo', 'seminovo', 'usado')) NOT NULL,
    category TEXT NOT NULL,
    location TEXT,
    is_available BOOLEAN DEFAULT true,
    likes_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela post_likes se não existir
CREATE TABLE IF NOT EXISTS post_likes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES news_posts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES marketplace_products(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT check_like_target CHECK (
        (post_id IS NOT NULL AND product_id IS NULL) OR 
        (post_id IS NULL AND product_id IS NOT NULL)
    ),
    UNIQUE(user_id, post_id),
    UNIQUE(user_id, product_id)
);

-- Criar tabela comments se não existir
CREATE TABLE IF NOT EXISTS comments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES news_posts(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela chat_rooms se não existir
CREATE TABLE IF NOT EXISTS chat_rooms (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT,
    is_group BOOLEAN DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela chat_room_members se não existir
CREATE TABLE IF NOT EXISTS chat_room_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);

-- Criar tabela messages se não existir
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'video', 'file')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_news_posts_user_id ON news_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_news_posts_created_at ON news_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_posts_category ON news_posts(category);

CREATE INDEX IF NOT EXISTS idx_marketplace_products_user_id ON marketplace_products(user_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_products_category ON marketplace_products(category);
CREATE INDEX IF NOT EXISTS idx_marketplace_products_available ON marketplace_products(is_available);
CREATE INDEX IF NOT EXISTS idx_marketplace_products_created_at ON marketplace_products(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_product_id ON post_likes(product_id);

CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON comments(parent_id);

CREATE INDEX IF NOT EXISTS idx_chat_room_members_room_id ON chat_room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_room_members_user_id ON chat_room_members(user_id);

CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);

-- Habilitar RLS em todas as tabelas
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para profiles
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" ON profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Políticas RLS para news_posts
DROP POLICY IF EXISTS "News posts are viewable by everyone" ON news_posts;
CREATE POLICY "News posts are viewable by everyone" ON news_posts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own news posts" ON news_posts;
CREATE POLICY "Users can insert their own news posts" ON news_posts FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own news posts" ON news_posts;
CREATE POLICY "Users can update own news posts" ON news_posts FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own news posts" ON news_posts;
CREATE POLICY "Users can delete own news posts" ON news_posts FOR DELETE USING (auth.uid() = user_id);

-- Políticas RLS para marketplace_products
DROP POLICY IF EXISTS "Products are viewable by everyone" ON marketplace_products;
CREATE POLICY "Products are viewable by everyone" ON marketplace_products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own products" ON marketplace_products;
CREATE POLICY "Users can insert their own products" ON marketplace_products FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own products" ON marketplace_products;
CREATE POLICY "Users can update own products" ON marketplace_products FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own products" ON marketplace_products;
CREATE POLICY "Users can delete own products" ON marketplace_products FOR DELETE USING (auth.uid() = user_id);

-- Políticas RLS para post_likes
DROP POLICY IF EXISTS "Users can view all likes" ON post_likes;
CREATE POLICY "Users can view all likes" ON post_likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can manage their own likes" ON post_likes;
CREATE POLICY "Users can manage their own likes" ON post_likes FOR ALL USING (auth.uid() = user_id);

-- Políticas RLS para comments
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON comments;
CREATE POLICY "Comments are viewable by everyone" ON comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own comments" ON comments;
CREATE POLICY "Users can insert their own comments" ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own comments" ON comments;
CREATE POLICY "Users can update own comments" ON comments FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own comments" ON comments;
CREATE POLICY "Users can delete own comments" ON comments FOR DELETE USING (auth.uid() = user_id);

-- Políticas RLS para chat_rooms
DROP POLICY IF EXISTS "Users can view rooms they are members of" ON chat_rooms;
CREATE POLICY "Users can view rooms they are members of" ON chat_rooms FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM chat_room_members 
        WHERE chat_room_members.room_id = chat_rooms.id 
        AND chat_room_members.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Users can create chat rooms" ON chat_rooms;
CREATE POLICY "Users can create chat rooms" ON chat_rooms FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Políticas RLS para chat_room_members
DROP POLICY IF EXISTS "Users can view room memberships" ON chat_room_members;
CREATE POLICY "Users can view room memberships" ON chat_room_members FOR SELECT USING (
    user_id = auth.uid() OR 
    EXISTS (
        SELECT 1 FROM chat_room_members crm 
        WHERE crm.room_id = chat_room_members.room_id 
        AND crm.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Users can join rooms" ON chat_room_members;
CREATE POLICY "Users can join rooms" ON chat_room_members FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Políticas RLS para messages
DROP POLICY IF EXISTS "Users can view messages in their rooms" ON messages;
CREATE POLICY "Users can view messages in their rooms" ON messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM chat_room_members 
        WHERE chat_room_members.room_id = messages.room_id 
        AND chat_room_members.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Users can send messages to their rooms" ON messages;
CREATE POLICY "Users can send messages to their rooms" ON messages FOR INSERT WITH CHECK (
    auth.uid() = user_id AND 
    EXISTS (
        SELECT 1 FROM chat_room_members 
        WHERE chat_room_members.room_id = messages.room_id 
        AND chat_room_members.user_id = auth.uid()
    )
);

-- Criar funções para atualizar contadores
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.post_id IS NOT NULL THEN
        UPDATE news_posts 
        SET likes_count = likes_count + 1 
        WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' AND OLD.post_id IS NOT NULL THEN
        UPDATE news_posts 
        SET likes_count = likes_count - 1 
        WHERE id = OLD.post_id;
    ELSIF TG_OP = 'INSERT' AND NEW.product_id IS NOT NULL THEN
        UPDATE marketplace_products 
        SET likes_count = likes_count + 1 
        WHERE id = NEW.product_id;
    ELSIF TG_OP = 'DELETE' AND OLD.product_id IS NOT NULL THEN
        UPDATE marketplace_products 
        SET likes_count = likes_count - 1 
        WHERE id = OLD.product_id;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger para atualizar contadores de likes
DROP TRIGGER IF EXISTS trigger_update_post_likes_count ON post_likes;
CREATE TRIGGER trigger_update_post_likes_count
    AFTER INSERT OR DELETE ON post_likes
    FOR EACH ROW
    EXECUTE FUNCTION update_post_likes_count();

-- Criar função para atualizar contador de comentários
CREATE OR REPLACE FUNCTION update_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE news_posts 
        SET comments_count = comments_count + 1 
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE news_posts 
        SET comments_count = comments_count - 1 
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger para atualizar contador de comentários
DROP TRIGGER IF EXISTS trigger_update_comments_count ON comments;
CREATE TRIGGER trigger_update_comments_count
    AFTER INSERT OR DELETE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_comments_count();

-- Criar função para atualizar timestamp de updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar triggers para atualizar updated_at
DROP TRIGGER IF EXISTS trigger_update_profiles_updated_at ON profiles;
CREATE TRIGGER trigger_update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_news_posts_updated_at ON news_posts;
CREATE TRIGGER trigger_update_news_posts_updated_at
    BEFORE UPDATE ON news_posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_marketplace_products_updated_at ON marketplace_products;
CREATE TRIGGER trigger_update_marketplace_products_updated_at
    BEFORE UPDATE ON marketplace_products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_comments_updated_at ON comments;
CREATE TRIGGER trigger_update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_messages_updated_at ON messages;
CREATE TRIGGER trigger_update_messages_updated_at
    BEFORE UPDATE ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
