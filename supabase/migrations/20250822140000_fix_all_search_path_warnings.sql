/*
  # [Function] get_existing_private_chat
  Finds an existing 1-on-1 chat room between two users.

  ## Query Description:
  This function is safe to run. It performs a read-only query to find a mutual, non-group chat room between two specified users. It does not modify any data.

  ## Metadata:
  - Schema-Category: "Safe"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true

  ## Structure Details:
  - Tables: chat_room_members, chat_rooms

  ## Security Implications:
  - RLS Status: Assumes RLS is enabled.
  - Policy Changes: No
  - Auth Requirements: Should be called by an authenticated user.
*/
CREATE OR REPLACE FUNCTION get_existing_private_chat(user1_id uuid, user2_id uuid)
RETURNS uuid AS $$
DECLARE
  room_id_result uuid;
BEGIN
  SET search_path = 'public';
  SELECT room_id INTO room_id_result
  FROM (
    SELECT crm.room_id
    FROM chat_room_members AS crm
    JOIN chat_rooms AS cr ON crm.room_id = cr.id
    WHERE crm.user_id IN (user1_id, user2_id) AND cr.is_group = false
    GROUP BY crm.room_id
    HAVING COUNT(DISTINCT crm.user_id) = 2
  ) AS mutual_rooms
  LIMIT 1;
  RETURN room_id_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
  # [Function] handle_new_user
  Creates a profile for a new user upon signup.

  ## Query Description:
  This is a trigger function that automatically creates a new row in the `profiles` table when a new user is added to `auth.users`. It populates the profile with data from the user's metadata. This is a critical function for user onboarding.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Medium"
  - Requires-Backup: false
  - Reversible: true (by dropping the trigger)

  ## Structure Details:
  - Tables: profiles, auth.users

  ## Security Implications:
  - RLS Status: The function runs with the permissions of the user that defines it (SECURITY DEFINER).
  - Policy Changes: No
  - Auth Requirements: Triggered by Supabase Auth.
*/
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  SET search_path = 'public';
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'username'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
  # [Function] is_chat_member
  Checks if a user is a member of a specific chat room.

  ## Query Description:
  A security helper function used in RLS policies to determine if a given user is part of a chat room. It is a read-only function and safe to run.

  ## Metadata:
  - Schema-Category: "Safe"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true

  ## Structure Details:
  - Tables: chat_room_members

  ## Security Implications:
  - RLS Status: Used within RLS policies.
  - Policy Changes: No
  - Auth Requirements: Called by RLS policies.
*/
CREATE OR REPLACE FUNCTION is_chat_member(p_room_id uuid, p_user_id uuid)
RETURNS boolean AS $$
DECLARE
  is_member boolean;
BEGIN
  SET search_path = 'public';
  SELECT EXISTS (
    SELECT 1
    FROM chat_room_members
    WHERE room_id = p_room_id AND user_id = p_user_id
  ) INTO is_member;
  RETURN is_member;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

/*
  # [Function] can_read_message
  Checks if the current user can read a message in a chat.

  ## Query Description:
  A security helper function for RLS policies on the `chat_messages` table. It checks if the currently authenticated user is a member of the chat room to which the message belongs.

  ## Metadata:
  - Schema-Category: "Safe"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true

  ## Structure Details:
  - Tables: chat_messages, chat_room_members

  ## Security Implications:
  - RLS Status: Used within RLS policies.
  - Policy Changes: No
  - Auth Requirements: Called by RLS policies.
*/
CREATE OR REPLACE FUNCTION public.can_read_message(p_message_id uuid)
RETURNS boolean AS $$
DECLARE
  v_room_id uuid;
BEGIN
  SET search_path = 'public';
  SELECT room_id INTO v_room_id FROM chat_messages WHERE id = p_message_id;
  RETURN is_chat_member(v_room_id, auth.uid());
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

/*
  # [Function] get_chat_rooms_for_user
  Retrieves all chat rooms for a given user.

  ## Query Description:
  This function fetches all chat rooms a specified user is a member of. It is a read-only operation and is safe to execute.

  ## Metadata:
  - Schema-Category: "Safe"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true

  ## Structure Details:
  - Tables: chat_rooms, chat_room_members

  ## Security Implications:
  - RLS Status: Assumes RLS is handled on the tables or in the calling query.
  - Policy Changes: No
  - Auth Requirements: Should be called by an authenticated user.
*/
CREATE OR REPLACE FUNCTION public.get_chat_rooms_for_user(p_user_id uuid)
RETURNS SETOF chat_rooms AS $$
BEGIN
  SET search_path = 'public';
  RETURN QUERY
  SELECT cr.*
  FROM chat_rooms cr
  JOIN chat_room_members crm ON cr.id = crm.room_id
  WHERE crm.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

/*
  # [Function] increment_likes_count / decrement_likes_count
  Trigger functions to manage like counts on posts and products.

  ## Query Description:
  These functions automatically update the `likes_count` on the `news_posts` or `marketplace_products` tables when a like is added or removed from the `post_likes` table.

  ## Metadata:
  - Schema-Category: "Data"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (by dropping the triggers)

  ## Structure Details:
  - Tables: news_posts, marketplace_products, post_likes

  ## Security Implications:
  - RLS Status: N/A (Trigger)
  - Policy Changes: No
  - Auth Requirements: Triggered by INSERT/DELETE on `post_likes`.
*/
CREATE OR REPLACE FUNCTION public.increment_likes_count()
RETURNS trigger AS $$
BEGIN
  SET search_path = 'public';
  IF (NEW.post_id IS NOT NULL) THEN
    UPDATE news_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF (NEW.product_id IS NOT NULL) THEN
    UPDATE marketplace_products SET likes_count = likes_count + 1 WHERE id = NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_likes_count()
RETURNS trigger AS $$
BEGIN
  SET search_path = 'public';
  IF (OLD.post_id IS NOT NULL) THEN
    UPDATE news_posts SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
  ELSIF (OLD.product_id IS NOT NULL) THEN
    UPDATE marketplace_products SET likes_count = likes_count - 1 WHERE id = OLD.product_id;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
  # [Function] increment_comments_count / decrement_comments_count
  Trigger functions to manage comment counts on posts.

  ## Query Description:
  These functions automatically update the `comments_count` on the `news_posts` table when a comment is added or removed from the `post_comments` table.

  ## Metadata:
  - Schema-Category: "Data"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (by dropping the triggers)

  ## Structure Details:
  - Tables: news_posts, post_comments

  ## Security Implications:
  - RLS Status: N/A (Trigger)
  - Policy Changes: No
  - Auth Requirements: Triggered by INSERT/DELETE on `post_comments`.
*/
CREATE OR REPLACE FUNCTION public.increment_comments_count()
RETURNS trigger AS $$
BEGIN
  SET search_path = 'public';
  UPDATE news_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_comments_count()
RETURNS trigger AS $$
BEGIN
  SET search_path = 'public';
  UPDATE news_posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

/*
  # [Function] update_last_message_at
  Trigger function to update the timestamp of the last message in a chat room.

  ## Query Description:
  This function automatically updates the `last_message_at` timestamp on the `chat_rooms` table whenever a new message is inserted into the `chat_messages` table.

  ## Metadata:
  - Schema-Category: "Data"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (by dropping the trigger)

  ## Structure Details:
  - Tables: chat_rooms, chat_messages

  ## Security Implications:
  - RLS Status: N/A (Trigger)
  - Policy Changes: No
  - Auth Requirements: Triggered by INSERT on `chat_messages`.
*/
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS trigger AS $$
BEGIN
  SET search_path = 'public';
  UPDATE chat_rooms
  SET last_message_at = NOW()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
