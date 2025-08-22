/*
# [Operation] Harden All Database Functions
This script automatically finds and secures all user-defined functions in the public schema by setting a secure search_path and defining them as SECURITY DEFINER. This is a critical security measure to prevent potential function-based attacks.

## Query Description:
- This operation iterates through all functions in the 'public' schema.
- For each function, it applies `ALTER FUNCTION` to set a safe `search_path` and apply `SECURITY DEFINER`.
- This change is non-destructive and only modifies function metadata. It does not affect data.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (manually, by altering functions back)

## Security Implications:
- RLS Status: Not applicable
- Policy Changes: No
- Auth Requirements: Requires database owner privileges to run.
- Mitigates: `Function Search Path Mutable` security warnings.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible. This is a one-time metadata update.
*/

DO $$
DECLARE
    func_record RECORD;
    alter_statement TEXT;
BEGIN
    FOR func_record IN
        SELECT
            p.proname AS function_name,
            n.nspname AS schema_name,
            pg_get_function_identity_arguments(p.oid) AS function_args
        FROM
            pg_proc p
        JOIN
            pg_namespace n ON p.pronamespace = n.oid
        WHERE
            n.nspname = 'public' -- Only functions in the public schema
            AND p.prokind = 'f' -- 'f' for regular functions
            -- Exclude PostGIS functions if they exist
            AND p.proname NOT LIKE 'st_%'
            AND p.proname NOT LIKE 'postgis_%'
    LOOP
        -- Construct the ALTER FUNCTION statement
        alter_statement := format(
            'ALTER FUNCTION public.%I(%s) SET search_path = "$user", public, extensions; ALTER FUNCTION public.%I(%s) SECURITY DEFINER;',
            func_record.function_name,
            func_record.function_args,
            func_record.function_name,
            func_record.function_args
        );

        -- Execute the statement
        RAISE NOTICE 'Executing: %', alter_statement;
        EXECUTE alter_statement;
    END LOOP;
END $$;
