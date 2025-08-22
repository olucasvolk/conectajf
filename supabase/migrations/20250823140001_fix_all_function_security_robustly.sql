/*
  # [MIGRATION] Robust Security Fix for All Database Functions

  This migration corrects a previous SQL error and robustly addresses all remaining "Function Search Path Mutable" security warnings.

  ## Query Description:
  This script dynamically identifies all functions in the 'public' schema that do not have a secure `search_path` defined and applies the necessary fix.
  1.  **Iterates Functions**: It loops through all functions in the public schema.
  2.  **Applies Security Fix**: For each function missing a `search_path`, it executes an `ALTER FUNCTION` command to set `search_path = ''`. This is a critical security best practice to prevent certain types of SQL injection.
  3.  **Error-Safe**: The script is written to avoid the `query has no destination for result data` error.
  4.  **Refreshes Schema Cache**: It notifies PostgREST to reload its schema cache, ensuring all changes are immediately effective.

  This operation is safe, idempotent, and does not affect existing data.

  ## Metadata:
  - Schema-Category: "Security"
  - Impact-Level: "Low"
  - Requires-Backup: false
  - Reversible: false (but the change is a security improvement)

  ## Security Implications:
  - Mitigates: All "Function Search Path Mutable" warnings.
*/

DO $$
DECLARE
    func_def RECORD;
BEGIN
    -- This loop finds all functions in the 'public' schema
    -- that do not already have a 'search_path' configured.
    FOR func_def IN
        SELECT
            p.oid::regprocedure AS func_signature
        FROM
            pg_proc p
        JOIN
            pg_namespace n ON p.pronamespace = n.oid
        WHERE
            n.nspname = 'public' AND
            p.prokind = 'f' AND -- 'f' for normal functions
            NOT EXISTS (
                SELECT 1
                FROM unnest(p.proconfig) AS config
                WHERE config LIKE 'search_path=%'
            )
    LOOP
        -- For each function found, this command alters it to set a secure,
        -- empty search_path. This resolves the security vulnerability.
        EXECUTE 'ALTER FUNCTION ' || func_def.func_signature || ' SET search_path = '''';';
        RAISE NOTICE 'Hardened function: %', func_def.func_signature;
    END LOOP;
END;
$$;

-- This command notifies PostgREST that the schema has changed and it should
-- reload its internal cache to reflect the function updates.
NOTIFY pgrst, 'reload schema';
