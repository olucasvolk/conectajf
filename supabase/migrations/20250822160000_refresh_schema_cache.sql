/*
# [Schema Cache Refresh]
Esta migração foi projetada para resolver o erro "Could not find column in schema cache" do Supabase. Ela força a API PostgREST a recarregar o cache do esquema fazendo uma pequena alteração não destrutiva.

## Descrição da Query:
Esta operação reaplica de forma segura uma política de segurança (RLS) existente na tabela `chat_messages`. Ela não altera nenhum dado ou lógica, mas sinaliza ao Supabase que uma alteração no esquema ocorreu, solicitando uma atualização do cache.

## Metadados:
- Categoria do Esquema: ["Segura"]
- Nível de Impacto: ["Baixo"]
- Requer Backup: [false]
- Reversível: [true]

## Implicações de Segurança:
- Status do RLS: [Habilitado]
- Mudanças na Política: [Não] - Reaplica a política existente.
*/

-- Reaplicar esta política irá acionar uma atualização do cache do esquema no Supabase.
-- É seguro executar, mesmo que a política já exista.
DROP POLICY IF EXISTS "Allow members to read messages in their rooms" ON "public"."chat_messages";
CREATE POLICY "Allow members to read messages in their rooms"
ON "public"."chat_messages"
AS PERMISSIVE
FOR SELECT
TO authenticated
USING (
  is_chat_member(room_id, auth.uid())
);
