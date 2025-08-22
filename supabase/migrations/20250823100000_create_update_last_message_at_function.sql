/*
# [CREATE FUNCTION & TRIGGER] Create update_last_message_at function and trigger
This migration creates a function to update the `last_message_at` timestamp in `chat_rooms` and a trigger to call it when a new message is inserted. This is essential for ordering chat rooms by recent activity.

## Query Description:
This operation is non-destructive and adds core functionality to the chat system. It creates a new function and a trigger. No existing data will be modified or put at risk.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (The function and trigger can be dropped)

## Structure Details:
- Creates function: `public.update_last_message_at()`
- Creates trigger: `on_new_message` on table `public.chat_messages`

## Security Implications:
- RLS Status: Not directly affected, but supports RLS-protected tables.
- Policy Changes: No
- Auth Requirements: None for the objects themselves.

## Performance Impact:
- Indexes: None
- Triggers: Adds one `AFTER INSERT` trigger to `chat_messages`. The impact is negligible as it's a simple update on a single row.
- Estimated Impact: Low.
*/

-- Step 1: Create the function to update the last message timestamp in a chat room.
-- This function is called by a trigger whenever a new message is inserted.
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.chat_rooms
  SET last_message_at = NEW.created_at
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set a secure search path for the function to address security advisories.
ALTER FUNCTION public.update_last_message_at() SET search_path = public;


-- Step 2: Create the trigger on the chat_messages table.
-- This trigger executes the function after each new message is inserted.
-- We drop it first to ensure the migration can be run safely multiple times.
DROP TRIGGER IF EXISTS on_new_message ON public.chat_messages;

CREATE TRIGGER on_new_message
AFTER INSERT ON public.chat_messages
FOR EACH ROW
EXECUTE FUNCTION public.update_last_message_at();
