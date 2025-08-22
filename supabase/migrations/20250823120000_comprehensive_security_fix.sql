/*
# [CRITICAL SECURITY FIX] Enable RLS and Harden Functions
This migration addresses critical security advisories by enabling Row Level Security on all tables with existing policies and hardening all database functions.

## Query Description:
This is a critical security update. It enables RLS on all tables, which means the access policies we've defined will now be enforced. Without this, your data is publicly accessible. It also secures database functions against potential injection attacks. There is no risk to existing data, but it is essential for protecting your data going forward.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true (by disabling RLS, but this is not recommended)

## Structure Details:
- Enables RLS for: profiles, news_posts, marketplace_products, post_likes, post_comments, chat_rooms, chat_room_members, chat_messages.
- Secures functions: create_profile_on_signup, update_last_message_at, get_or_create_chat_room.

## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: No. This enables existing policies.
- Auth Requirements: All data access will now be correctly governed by RLS policies.

## Performance Impact:
- Indexes: None.
- Triggers: None.
- Estimated Impact: A minor performance overhead on queries due to RLS checks, which is standard and necessary for security.
*/

-- 1. Enable Row Level Security on all tables
-- This is a critical step to enforce all the policies we've created.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- 2. Harden all database functions
-- This prevents potential security vulnerabilities by setting a fixed search_path and defining security context.

-- Function to create a profile on new user signup
CREATE OR REPLACE FUNCTION public.create_profile_on_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'username'
  );
  RETURN NEW;
END;
$$;

-- Function to update the last message timestamp in a chat room
CREATE OR REPLACE FUNCTION public.update_last_message_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.chat_rooms
  SET last_message_at = NOW()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$;

-- Function to get or create a 1-on-1 chat room
CREATE OR REPLACE FUNCTION public.get_or_create_chat_room(user1_id uuid, user2_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  existing_room_id uuid;
  new_room_id uuid;
BEGIN
  -- Check if a 1-on-1 chat room already exists between the two users
  SELECT room_id INTO existing_room_id
  FROM (
    SELECT room_id
    FROM chat_room_members
    WHERE user_id IN (user1_id, user2_id)
  ) AS user_rooms
  JOIN chat_rooms ON chat_rooms.id = user_rooms.room_id
  WHERE chat_rooms.is_group = false
  GROUP BY room_id
  HAVING COUNT(DISTINCT user_id) = 2;

  -- If a room exists, return its ID
  IF existing_room_id IS NOT NULL THEN
    RETURN existing_room_id;
  END IF;

  -- If no room exists, create a new one
  INSERT INTO public.chat_rooms (created_by, is_group)
  VALUES (user1_id, false)
  RETURNING id INTO new_room_id;

  -- Add both users as members of the new room
  INSERT INTO public.chat_room_members (room_id, user_id)
  VALUES (new_room_id, user1_id), (new_room_id, user2_id);

  RETURN new_room_id;
END;
$$;
