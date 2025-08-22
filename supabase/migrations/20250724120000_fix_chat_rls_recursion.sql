/*
          # [Fix] Corrige a Recursão Infinita nas Políticas de Segurança do Chat

          Este script resolve um erro crítico de "recursão infinita" que ocorria ao tentar listar as salas de chat de um usuário. O problema era causado por políticas de segurança (RLS) que chamavam a si mesmas indiretamente.

          ## Descrição da Query:
          A solução implementa uma função `is_chat_member` com `SECURITY DEFINER`. Esta função é executada com privilégios de superusuário, permitindo que ela verifique a tabela `chat_room_members` sem acionar as políticas de RLS do usuário, quebrando assim o ciclo de recursão. Em seguida, as políticas das tabelas `chat_rooms`, `chat_room_members`, e `chat_messages` são reescritas para usar esta função segura, simplificando a lógica e garantindo que as consultas sejam executadas corretamente e sem erros.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Medium"
          - Requires-Backup: false
          - Reversible: true

          ## Detalhes da Estrutura:
          - **Criação de Função:** `is_chat_member(uuid, uuid)`
          - **Alteração de Políticas:** Políticas de `SELECT` e `INSERT` nas tabelas `chat_rooms`, `chat_room_members`, `chat_messages`.

          ## Implicações de Segurança:
          - RLS Status: Ativado e Corrigido
          - Policy Changes: Sim. As políticas são substituídas por versões mais seguras e eficientes.
          - Auth Requirements: As políticas continuam a usar `auth.uid()` para garantir que os usuários só acessem seus próprios dados.

          ## Impacto na Performance:
          - Indexes: Nenhum
          - Triggers: Nenhum
          - Estimated Impact: Positivo. A correção elimina consultas recursivas que travavam o banco de dados, melhorando significativamente a performance da funcionalidade de chat.
          */

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view rooms they are members of" ON public.chat_rooms;
DROP POLICY IF EXISTS "Users can view members of rooms they are in" ON public.chat_room_members;
DROP POLICY IF EXISTS "Users can view their own room memberships" ON public.chat_room_members;
DROP POLICY IF EXISTS "Users can view messages in rooms they are members of" ON public.chat_messages;
DROP POLICY IF EXISTS "Users can insert messages in rooms they are members of" ON public.chat_messages;

-- Create a helper function with SECURITY DEFINER to break the recursion loop.
-- This function checks if a user is a member of a room without triggering the RLS policy on chat_room_members.
CREATE OR REPLACE FUNCTION public.is_chat_member(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  );
END;
$$;

-- Re-create policies using the safe helper function

-- Policy for chat_rooms: Users can see rooms they are members of.
CREATE POLICY "Users can view rooms they are members of"
ON public.chat_rooms
FOR SELECT
USING (public.is_chat_member(id, auth.uid()));

-- Policy for chat_room_members: Users can see other members of rooms they are in.
CREATE POLICY "Users can view members of rooms they are in"
ON public.chat_room_members
FOR SELECT
USING (public.is_chat_member(room_id, auth.uid()));

-- Policy for chat_messages (SELECT): Users can view messages in rooms they are members of.
CREATE POLICY "Users can view messages in rooms they are members of"
ON public.chat_messages
FOR SELECT
USING (public.is_chat_member(room_id, auth.uid()));

-- Policy for chat_messages (INSERT): Users can only insert messages into rooms they are members of.
CREATE POLICY "Users can insert messages in rooms they are members of"
ON public.chat_messages
FOR INSERT
WITH CHECK (public.is_chat_member(room_id, auth.uid()));
