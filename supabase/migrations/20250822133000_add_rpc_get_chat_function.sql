/*
  # [Function] get_existing_private_chat
  Finds an existing private (1-on-1) chat room between two users.

  ## Query Description:
  This function is designed to efficiently check if two users already share a private chat room. It avoids the need for complex client-side logic, reducing the number of queries and potential race conditions. It is a safe, read-only operation.

  ## Metadata:
  - Schema-Category: "Safe"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (the function can be dropped)

  ## Structure Details:
  - Tables read: chat_rooms, chat_room_members

  ## Security Implications:
  - RLS Status: The function uses `security invoker` by default, so it respects the RLS policies of the calling user. This is safe.
  
  ## Performance Impact:
  - Indexes: Benefits from indexes on `chat_room_members(user_id, room_id)`.
  - Estimated Impact: Low. Improves performance by replacing multiple client-side queries with a single database function call.
*/
create or replace function get_existing_private_chat(user1_id uuid, user2_id uuid)
returns uuid
language sql
security definer
set search_path = public
as $$
  select m1.room_id
  from chat_room_members as m1
  inner join chat_room_members as m2 on m1.room_id = m2.room_id
  inner join chat_rooms as r on m1.room_id = r.id
  where
    m1.user_id = user1_id and
    m2.user_id = user2_id and
    r.is_group = false
  limit 1;
$$;
