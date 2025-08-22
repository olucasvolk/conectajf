/*
# [Operation Name]
Fix User Profile Creation on Signup (Robust)

## Query Description: [This operation replaces the database function and trigger responsible for creating a user profile upon signup. The new version is more robust and handles cases where user metadata (like full name or username) might be missing by providing default values. This prevents the entire signup process from failing and ensures that a profile is always created successfully.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Medium"]
- Requires-Backup: [false]
- Reversible: [false]

## Structure Details:
- Replaces function: `public.handle_new_user`
- Replaces trigger: `on_auth_user_created` on `auth.users`

## Security Implications:
- RLS Status: [N/A]
- Policy Changes: [No]
- Auth Requirements: [This function runs with definer rights to insert into the public profiles table.]

## Performance Impact:
- Indexes: [N/A]
- Triggers: [Modified]
- Estimated Impact: [Negligible impact on signup performance.]
*/

-- First, drop the existing trigger and function to ensure a clean slate.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create a more robust function to handle new user profile creation.
-- This version provides default values to prevent errors if metadata is missing.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', 'Usuário Novo'),
    -- Generates a unique username if one isn't provided, to satisfy the UNIQUE constraint.
    COALESCE(new.raw_user_meta_data->>'username', 'user' || substr(new.id::text, 1, 8))
  );
  RETURN new;
END;
$$;

-- Recreate the trigger to execute the new function after a user signs up.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
