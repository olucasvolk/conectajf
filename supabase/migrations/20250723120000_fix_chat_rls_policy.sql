/*
          # [Fix RLS Policy for Chat]
          Corrige a política de segurança (RLS) da tabela `chat_room_members` para evitar um erro de recursão infinita.

          ## Query Description:
          Esta operação irá substituir as políticas de segurança existentes na tabela `chat_room_members`. A política de seleção (SELECT) anterior estava causando um loop infinito ao verificar as permissões. A nova política é mais simples e segura, permitindo que os usuários vejam apenas os registros de associação que lhes pertencem diretamente. Isso não afeta os dados existentes, apenas corrige as regras de acesso.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Tabela afetada: `public.chat_room_members`
          - Políticas removidas:
            - "Allow members to view their own chat room memberships"
            - "Allow users to be added to rooms"
          - Políticas criadas:
            - "Allow users to view their own room memberships" (SELECT)
            - "Allow users to join rooms" (INSERT)

          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes
          - Auth Requirements: Autenticação de usuário (auth.uid())

          ## Performance Impact:
          - Indexes: Nenhum
          - Triggers: Nenhum
          - Estimated Impact: A correção melhora o desempenho ao evitar uma consulta recursiva que travava o banco de dados.
          */

-- Remove as políticas antigas e problemáticas
DROP POLICY IF EXISTS "Allow members to view their own chat room memberships" ON public.chat_room_members;
DROP POLICY IF EXISTS "Allow users to be added to rooms" ON public.chat_room_members;

-- Cria uma nova política de SELECT que não causa recursão
CREATE POLICY "Allow users to view their own room memberships"
ON public.chat_room_members FOR SELECT
USING (auth.uid() = user_id);

-- Cria uma nova política de INSERT para permitir que usuários se adicionem a salas
CREATE POLICY "Allow users to join rooms"
ON public.chat_room_members FOR INSERT
WITH CHECK (auth.uid() = user_id);
