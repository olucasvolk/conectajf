/*
          # [Function] handle_new_user
          [This function is triggered when a new user signs up. It automatically creates a corresponding profile in the public.profiles table.]

          ## Query Description: [This function inserts a new row into the public.profiles table using the ID and metadata from the newly created user in auth.users. This automates profile creation and ensures data consistency between authentication and user profiles. It is a safe, non-destructive operation.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Tables affected: public.profiles (INSERT)
          - Function created: public.handle_new_user()
          
          ## Security Implications:
          - RLS Status: [Not applicable to function definition]
          - Policy Changes: [No]
          - Auth Requirements: [The function runs with the security definer role, allowing it to insert into the profiles table on behalf of the system.]
          
          ## Performance Impact:
          - Indexes: [No changes]
          - Triggers: [A new trigger will be created to use this function.]
          - Estimated Impact: [Negligible. This is a lightweight function that runs once per user creation.]
          */
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, username, location)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'username',
    'Juiz de Fora, MG'
  );
  RETURN new;
END;
$$;

/*
          # [Trigger] on_auth_user_created
          [This trigger calls the handle_new_user() function after a new user is inserted into the auth.users table.]

          ## Query Description: [This trigger ensures that for every new user registered in the application, a corresponding profile is automatically created. This is a safe and essential operation for data integrity.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Low"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Tables affected: auth.users (TRIGGER)
          - Trigger created: on_auth_user_created
          
          ## Security Implications:
          - RLS Status: [Not applicable]
          - Policy Changes: [No]
          - Auth Requirements: [Fires automatically on user creation.]
          
          ## Performance Impact:
          - Indexes: [No changes]
          - Triggers: [Adds one new trigger.]
          - Estimated Impact: [Negligible.]
          */
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
