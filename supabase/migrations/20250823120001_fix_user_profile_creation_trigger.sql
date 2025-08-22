/*
# [Fix] Correct User Profile Creation Trigger
This migration fixes a critical issue where new users could not be created due to an error in the underlying database function responsible for creating their profile entry. The previous function was likely misconfigured, causing the entire user creation process to fail.

## Query Description:
This script will drop the faulty trigger and function and then recreate them with the correct implementation. This ensures that when a new user signs up, their corresponding profile is created successfully in the `public.profiles` table using the `full_name` and `username` provided during registration. This operation is safe and does not affect any existing user data.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Drops trigger `on_new_user_create_profile` on `auth.users`.
- Drops function `public.create_profile_for_new_user()`.
- Recreates function `public.create_profile_for_new_user()` with correct logic.
- Recreates trigger `on_new_user_create_profile` on `auth.users`.

## Security Implications:
- RLS Status: Not applicable to this change.
- Policy Changes: No
- Auth Requirements: The function is set to `SECURITY DEFINER` to ensure it has the necessary permissions to insert into the `public.profiles` table, which is a standard and secure practice for this type of trigger.

## Performance Impact:
- Indexes: None
- Triggers: Replaces an existing trigger. The performance impact is negligible and only occurs once per user sign-up.
- Estimated Impact: Low.
*/

-- Step 1: Drop the existing trigger and function to ensure a clean re-creation.
DROP TRIGGER IF EXISTS on_new_user_create_profile ON auth.users;
DROP FUNCTION IF EXISTS public.create_profile_for_new_user();

-- Step 2: Re-create the function to create a profile for a new user.
-- This function now correctly extracts metadata from the new user record.
CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'username'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Re-create the trigger to call the function after a new user is inserted into auth.users.
CREATE TRIGGER on_new_user_create_profile
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.create_profile_for_new_user();
