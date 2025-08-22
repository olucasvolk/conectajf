/*
  # [Function] Create Profile for New User
  This function automatically creates a new user profile in the `public.profiles` table
  whenever a new user signs up via Supabase Auth. It is triggered by an insert
  on the `auth.users` table.

  ## Query Description:
  This operation creates a new database function and a trigger. It is non-destructive
  and essential for the application's sign-up process to work correctly. It ensures
  that every authenticated user has a corresponding profile record.

  ## Metadata:
  - Schema-Category: "Structural"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: true (by dropping the function and trigger)

  ## Structure Details:
  - Creates function: `public.create_profile_for_new_user()`
  - Creates trigger: `on_auth_user_created` on `auth.users`

  ## Security Implications:
  - RLS Status: Not directly affected, but enables profile-based RLS policies.
  - Policy Changes: No
  - Auth Requirements: The function runs with definer rights to insert into `public.profiles`.

  ## Performance Impact:
  - Indexes: None
  - Triggers: Adds one trigger to `auth.users`.
  - Estimated Impact: Negligible impact on sign-up performance.
*/

-- 1. Create the function to handle new user profile creation
CREATE OR REPLACE FUNCTION public.create_profile_for_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'username'
  );
  RETURN new;
END;
$$;

-- 2. Create the trigger to call the function after a new user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.create_profile_for_new_user();
