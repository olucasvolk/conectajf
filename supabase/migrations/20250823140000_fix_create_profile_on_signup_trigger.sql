/*
          # [Operation] Fix User Profile Creation on Signup
          This migration corrects the database function and trigger responsible for creating a user profile when a new user signs up. It ensures that user metadata (full name, username) is correctly saved.

          ## Query Description:
          This operation is safe and non-destructive. It drops the existing, potentially faulty function and trigger and recreates them with the correct logic. It does not affect any existing user data. The main risk of not applying this is that new user registrations will continue to fail.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - Drops and recreates the `handle_new_user` function.
          - Drops and recreates the `on_auth_user_created` trigger on the `auth.users` table.

          ## Security Implications:
          - RLS Status: Not directly affected, but the function uses `SECURITY DEFINER` to correctly insert into the `profiles` table.
          - Policy Changes: No
          - Auth Requirements: This function is tied to the `auth.users` table.

          ## Performance Impact:
          - Indexes: None
          - Triggers: Recreates one trigger.
          - Estimated Impact: Negligible. The trigger only runs once per new user signup.
          */

-- Drop the existing trigger and function if they exist to ensure a clean slate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create the function to create a profile for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

-- Create the trigger to execute the function after a new user is inserted into auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Add a comment to the function for clarity
COMMENT ON FUNCTION public.handle_new_user() IS 'Creates a profile for a new user from the data provided at signup.';
