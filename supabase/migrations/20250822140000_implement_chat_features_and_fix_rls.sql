/*
          # [Feature] Implementação de Funcionalidades do Chat e Correção de Segurança
          Este script adiciona funcionalidades avançadas ao chat e corrige as políticas de segurança (RLS) para garantir o funcionamento correto e seguro.

          ## Descrição da Query:
          - Adiciona um status ('enviado', 'entregue', 'lido') e um campo `read_at` às mensagens.
          - Adiciona um campo `is_typing` aos membros da sala para o indicador de "digitando".
          - RECRIA TODAS AS POLÍTICAS DE SEGURANÇA (RLS) para as tabelas do chat. As novas políticas são seguras, eficientes e corrigem os erros de recursão e permissão que você enfrentou.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Medium"
          - Requires-Backup: false
          - Reversible: false (requereria a remoção manual das colunas e políticas)
          */

-- Criar o tipo ENUM para o status da mensagem, se ele não existir.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_status') THEN
        CREATE TYPE public.message_status AS ENUM ('sending', 'sent', 'delivered', 'read');
    END IF;
END$$;

-- Adicionar colunas à tabela de mensagens
ALTER TABLE public.chat_messages
ADD COLUMN IF NOT EXISTS status public.message_status DEFAULT 'sent',
ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Adicionar coluna à tabela de membros da sala
ALTER TABLE public.chat_room_members
ADD COLUMN IF NOT EXISTS is_typing BOOLEAN DEFAULT FALSE;

--
-- CORREÇÃO E REATIVAÇÃO DAS POLÍTICAS DE SEGURANÇA (RLS)
--

-- Habilitar RLS (caso esteja desabilitado)
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas para evitar conflitos
DROP POLICY IF EXISTS "Allow members to read their rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow authenticated users to create rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Allow members to read other members" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow user to manage their own membership" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow members to read messages in their rooms" ON public.chat_messages;
DROP POLICY IF EXISTS "Allow members to send messages in their rooms" ON public.chat_messages;
DROP POLICY IF EXISTS "Allow members to update their own messages" ON public.chat_messages;

-- Função auxiliar para verificar se um usuário é membro de uma sala (CHAVE PARA EVITAR RECURSÃO)
CREATE OR REPLACE FUNCTION is_chat_member(room_id_to_check UUID, user_id_to_check UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.chat_room_members
    WHERE room_id = room_id_to_check AND user_id = user_id_to_check
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Novas Políticas para chat_rooms
CREATE POLICY "Allow members to read their rooms"
ON public.chat_rooms FOR SELECT
USING (is_chat_member(id, auth.uid()));

CREATE POLICY "Allow authenticated users to create rooms"
ON public.chat_rooms FOR INSERT
WITH CHECK (auth.role() = 'authenticated');


-- Novas Políticas para chat_room_members
CREATE POLICY "Allow members to read other members"
ON public.chat_room_members FOR SELECT
USING (is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow user to manage their own membership"
ON public.chat_room_members FOR ALL
USING (auth.uid() = user_id);


-- Novas Políticas para chat_messages
CREATE POLICY "Allow members to read messages in their rooms"
ON public.chat_messages FOR SELECT
USING (is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow members to send messages in their rooms"
ON public.chat_messages FOR INSERT
WITH CHECK (is_chat_member(room_id, auth.uid()));

CREATE POLICY "Allow members to update their own messages"
ON public.chat_messages FOR UPDATE
USING (auth.uid() = user_id);
