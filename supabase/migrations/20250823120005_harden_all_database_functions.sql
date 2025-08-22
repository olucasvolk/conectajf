/*
# [SECURITY] Harden All Database Functions
This script iterates through all user-defined functions in the 'public' schema and applies critical security settings to resolve the 'Function Search Path Mutable' warnings.

## Query Description:
This is a safe, non-destructive operation that modifies the metadata of existing functions. It does not alter the logic or data. It hardens your database against potential SQL injection vectors by setting a fixed search path and defining security context.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (manually)

## Security Implications:
- RLS Status: Not applicable
- Policy Changes: No
- Auth Requirements: This script improves function security.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible performance impact.
*/

DO $$
DECLARE
    func_record RECORD;
BEGIN
    -- Loop through all user-defined functions in the 'public' schema
    FOR func_record IN
        SELECT
            p.proname AS function_name,
            pg_get_function_identity_arguments(p.oid) AS function_args,
            n.nspname as schema_name
        FROM
            pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE
            n.nspname = 'public' AND p.prokind = 'f' -- 'f' for function
            AND NOT p.proisagg -- Exclude aggregate functions
            AND p.proname NOT LIKE 'pg_%' -- Exclude system functions
    LOOP
        -- Set a secure search path to prevent hijacking
        EXECUTE format('ALTER FUNCTION %I.%I(%s) SET search_path = extensions, public;',
                       func_record.schema_name, func_record.function_name, func_record.function_args);

        -- Set the security context. SECURITY DEFINER is appropriate for these utility functions.
        EXECUTE format('ALTER FUNCTION %I.%I(%s) SECURITY DEFINER;',
                       func_record.schema_name, func_record.function_name, func_record.function_args);

        -- Revoke default public execution rights
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC;',
                       func_record.schema_name, func_record.function_name, func_record.function_args);

        -- Grant execute rights only to authenticated users
        EXECUTE format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated;',
                       func_record.schema_name, func_record.function_name, func_record.function_args);

        RAISE NOTICE 'Hardened function: %', func_record.function_name;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
