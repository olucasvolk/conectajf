/*
          # [Operation Name]
          Correção Definitiva e Melhoria do Sistema de Chat

          ## Query Description: [Este script realiza uma correção completa e definitiva no sistema de chat, resolvendo erros de migração e permissão (RLS) e adicionando as funcionalidades solicitadas (status de mensagem, "digitando" e "visto"). Ele primeiro remove todas as configurações antigas e problemáticas para garantir uma instalação limpa e segura.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "High"
          - Requires-Backup: true
          - Reversible: false
          
          ## Structure Details:
          - Funções Removidas: is_chat_member, get_existing_private_chat
          - Funções Criadas: is_chat_member (corrigida), get_existing_private_chat (corrigida)
          - Políticas Removidas: Todas as políticas de RLS das tabelas de chat.
          - Políticas Criadas: Novas políticas de RLS seguras e não-recursivas para chat_rooms, chat_room_members, chat_messages.
          - Colunas Adicionadas: status, read_at (em chat_messages), is_typing (em chat_room_members).
          
          ## Security Implications:
          - RLS Status: Habilitado para todas as tabelas de chat.
          - Policy Changes: Sim, as políticas são completamente recriadas.
          - Auth Requirements: Apenas usuários autenticados podem interagir com o chat.
          
          ## Performance Impact:
          - Indexes: Nenhum índice novo.
          - Triggers: Nenhum trigger novo.
          - Estimated Impact: Positivo. As novas políticas e funções são mais eficientes e evitam loops de recursão.
          */

-- Remove completamente as configurações antigas para evitar conflitos
DROP POLICY IF EXISTS "Allow members to read their rooms" ON "public"."chat_rooms";
DROP POLICY IF EXISTS "Allow authenticated users to create rooms" ON "public"."chat_rooms";
DROP POLICY IF EXISTS "Allow members to see other members in their rooms" ON "public"."chat_room_members";
DROP POLICY IF EXISTS "Allow users to add members to a new room they created" ON "public"."chat_room_members";
DROP POLICY IF EXISTS "Allow users to update their own typing status" ON "public"."chat_room_members";
DROP POLICY IF EXISTS "Allow members to view messages in their rooms" ON "public"."chat_messages";
DROP POLICY IF EXISTS "Allow members to send messages in their rooms" ON "public"."chat_messages";
DROP POLICY IF EXISTS "Allow members to update message status in their rooms" ON "public"."chat_messages";

DROP FUNCTION IF EXISTS public.is_chat_member(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_existing_private_chat(uuid, uuid);

-- Adiciona as colunas necessárias para as novas funcionalidades, se ainda não existirem
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS status public.message_status DEFAULT 'sent'::public.message_status;
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS read_at timestamp with time zone;
ALTER TABLE public.chat_room_members ADD COLUMN IF NOT EXISTS is_typing boolean DEFAULT false;

-- Cria uma função auxiliar segura para verificar se um usuário é membro de uma sala (evita recursão)
CREATE OR REPLACE FUNCTION public.is_chat_member(p_room_id uuid, p_user_id uuid)
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

-- Cria uma função para encontrar conversas privadas existentes de forma eficiente
CREATE OR REPLACE FUNCTION public.get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid AS $$
  SELECT crm1.room_id
  FROM chat_room_members AS crm1
  JOIN chat_room_members AS crm2 ON crm1.room_id = crm2.room_id
  JOIN chat_rooms AS cr ON crm1.room_id = cr.id
  WHERE
    crm1.user_id = user1_id AND
    crm2.user_id = user2_id AND
    cr.is_group = false
  LIMIT 1;
$$ LANGUAGE sql STABLE;

-- Reativa a segurança (RLS) com as políticas corretas e funcionais
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Políticas para a tabela chat_rooms
CREATE POLICY "Allow members to read their rooms" ON "public"."chat_rooms"
FOR SELECT USING (is_chat_member(id, auth.uid()));

CREATE POLICY "Allow authenticated users to create rooms" ON "public"."chat_rooms"
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Políticas para a tabela chat_room_members
CREATE POLICY "Allow members to see other members in their rooms" ON "public"."chat_room_members"
FOR SELECT USING (is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow users to add members when creating a room" ON "public"."chat_room_members"
FOR INSERT WITH CHECK (
  (SELECT created_by FROM chat_rooms WHERE id = room_id) = auth.uid() OR is_chat_member(room_id, auth.uid())
);

CREATE POLICY "Allow users to update their own typing status" ON "public"."chat_room_members"
FOR UPDATE USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Políticas para a tabela chat_messages
CREATE POLICY "Allow members to view messages in their rooms" ON "public"."chat_messages"
FOR SELECT USING (is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow members to send messages in their rooms" ON "public"."chat_messages"
FOR INSERT WITH CHECK (is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow members to update message status in their rooms" ON "public"."chat_messages"
FOR UPDATE USING (is_chat_member(room_id, auth.uid()));
