/*
# [Function] get_existing_private_chat
Creates a helper function to efficiently find an existing private (1-on-1) chat room between two users. This avoids complex and inefficient client-side logic.

## Query Description:
This operation creates a PostgreSQL function. It is a safe, non-destructive operation that adds new functionality to the database. It does not modify or delete any existing data. This function is designed to improve the performance of finding chat rooms.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (The function can be dropped)

## Structure Details:
- Function Name: `get_existing_private_chat`
- Arguments: `user1_id UUID`, `user2_id UUID`
- Returns: `UUID` (the room_id) or `NULL`

## Security Implications:
- RLS Status: The function runs with the permissions of the user calling it, respecting all RLS policies.
- Policy Changes: No
- Auth Requirements: The user must be authenticated to call this function.

## Performance Impact:
- Indexes: The query inside the function will benefit from existing indexes on `chat_room_members(user_id)` and `chat_room_members(room_id)`.
- Triggers: None
- Estimated Impact: Positive. Reduces the number of round-trips between the client and the database.
*/

CREATE OR REPLACE FUNCTION get_existing_private_chat(user1_id UUID, user2_id UUID)
RETURNS UUID AS $$
DECLARE
    room_uuid UUID;
BEGIN
    SELECT crm1.room_id INTO room_uuid
    FROM chat_room_members AS crm1
    JOIN chat_room_members AS crm2 ON crm1.room_id = crm2.room_id
    JOIN chat_rooms AS cr ON crm1.room_id = cr.id
    WHERE
        crm1.user_id = user1_id AND
        crm2.user_id = user2_id AND
        cr.is_group = false
    LIMIT 1;

    RETURN room_uuid;
END;
$$ LANGUAGE plpgsql;
