/*
          # [Fix] Handle Username Uniqueness on Signup
          This migration updates the `create_profile_on_signup` function to be more resilient.
          It now handles cases where a chosen username already exists by appending a short,
          random suffix to ensure the username is unique. This prevents the signup process
          from failing due to a unique constraint violation.

          ## Query Description: 
          - This operation modifies a database function. It does not alter table structures or delete data.
          - It is a safe operation that improves the reliability of the user registration process.
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true (by reverting to the previous function definition)
          
          ## Structure Details:
          - Function affected: `public.create_profile_on_signup()`
          
          ## Security Implications:
          - RLS Status: Not applicable to this function.
          - Policy Changes: No
          - Auth Requirements: This function is a trigger called by Supabase Auth.
          
          ## Performance Impact:
          - This change adds a single, fast `EXISTS` check during user creation. The performance impact is negligible.
          */

CREATE OR REPLACE FUNCTION public.create_profile_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  generated_username TEXT := COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1));
BEGIN
  -- If the desired username is already taken, append a random 4-char suffix to ensure uniqueness.
  IF EXISTS (SELECT 1 FROM public.profiles WHERE username = generated_username) THEN
    generated_username := generated_username || '_' || substr(md5(random()::text), 0, 5);
  END IF;
  
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Nome não informado'),
    generated_username
  );
  RETURN NEW;
END;
$$;
