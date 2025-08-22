/*
          # [OPERATION] Harden User Creation and Chat Functions
          This migration replaces the user profile creation trigger and the chat room creation function with more robust, secure, and resilient versions to prevent common errors.

          ## Query Description: 
          This operation is safe and primarily affects backend logic. It drops and recreates two functions and one trigger.
          1. `handle_new_user`: This function now runs as `SECURITY DEFINER` to prevent permission issues. It gracefully handles missing `full_name` or `username` metadata by providing defaults. Most importantly, it now includes a loop to guarantee username uniqueness by appending a random suffix if a collision is detected, making user creation much more reliable.
          2. `get_or_create_chat_room`: This function is also updated to run as `SECURITY DEFINER` and with a fixed `search_path` for better security and stability.
          3. `on_auth_user_created`: The trigger is recreated to point to the new, improved `handle_new_user` function.
          
          There should be no impact on existing data. This change makes the user registration and chat initiation processes significantly more stable.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Functions Dropped: `handle_new_user`, `get_or_create_chat_room`
          - Trigger Dropped: `on_auth_user_created` on `auth.users`
          - Functions Created: `handle_new_user`, `get_or_create_chat_room` (new versions)
          - Trigger Created: `on_auth_user_created` on `auth.users` (new version)

          ## Security Implications:
          - RLS Status: Not directly changed, but functions now use `SECURITY DEFINER`.
          - Policy Changes: No
          - Auth Requirements: The trigger is tied to `auth.users`.

          ## Performance Impact:
          - Indexes: None
          - Triggers: Recreated
          - Estimated Impact: Negligible. The user creation might be infinitesimally slower if a username collision occurs, but this is rare and the process becomes more reliable.
          */

-- Drop existing objects if they exist to ensure a clean slate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.get_or_create_chat_room(uuid, uuid);

-- Create a robust function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER -- Ensures the function has permissions to insert into the profiles table
SET search_path = public
AS $$
DECLARE
  _username TEXT;
  _full_name TEXT;
  _final_username TEXT;
  _suffix TEXT;
  _is_unique BOOLEAN := false;
  _counter INTEGER := 0;
BEGIN
  -- Extract metadata, providing defaults if null
  _full_name := COALESCE(new.raw_user_meta_data ->> 'full_name', 'Novo Usuário');
  _username := COALESCE(new.raw_user_meta_data ->> 'username', 'user_' || substr(new.id::text, 1, 8));

  -- Sanitize username: remove leading '@', spaces, and convert to lowercase
  _username := lower(regexp_replace(btrim(_username), '^@', ''));
  _final_username := _username;

  -- Loop to ensure username is unique
  WHILE NOT _is_unique AND _counter < 10 LOOP
    PERFORM 1 FROM public.profiles WHERE public.profiles.username = _final_username;
    IF NOT FOUND THEN
      _is_unique := true;
    ELSE
      -- If username exists, append a random 4-character suffix
      _suffix := substr(md5(random()::text), 1, 4);
      _final_username := _username || '_' || _suffix;
    END IF;
    _counter := _counter + 1;
  END LOOP;

  -- If after 10 tries we still have no unique username, something is wrong.
  -- As a last resort, use the user's UUID.
  IF NOT _is_unique THEN
    _final_username := 'user_' || new.id::text;
  END IF;

  -- Insert the new profile
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (new.id, _full_name, _final_username);
  
  RETURN new;
END;
$$;

-- Recreate the trigger on the auth.users table
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Recreate the chat room function with security best practices
CREATE OR REPLACE FUNCTION public.get_or_create_chat_room(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    existing_room_id uuid;
    new_room_id uuid;
BEGIN
    -- Ensure users are not the same
    IF user1_id = user2_id THEN
        RAISE EXCEPTION 'Cannot create a chat room with the same user.';
    END IF;

    -- Find an existing 1-on-1 chat room
    SELECT room_id INTO existing_room_id
    FROM chat_room_members m1
    JOIN chat_room_members m2 ON m1.room_id = m2.room_id
    JOIN chat_rooms cr ON m1.room_id = cr.id
    WHERE m1.user_id = user1_id
      AND m2.user_id = user2_id
      AND cr.is_group = false
    LIMIT 1;

    -- If a room exists, return its ID
    IF existing_room_id IS NOT NULL THEN
        RETURN existing_room_id;
    END IF;

    -- If no room exists, create a new one
    INSERT INTO chat_rooms (created_by)
    VALUES (user1_id)
    RETURNING id INTO new_room_id;

    -- Add both users as members
    INSERT INTO chat_room_members (room_id, user_id)
    VALUES (new_room_id, user1_id), (new_room_id, user2_id);

    RETURN new_room_id;
END;
$$;
