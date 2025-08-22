/*
# [Force Schema Cache Reload]
This migration forces Supabase's API (PostgREST) to reload its internal schema cache. This is necessary to resolve errors like "Could not find the 'column' in the schema cache" which occur when the API's cached version of the database structure is out of sync with the actual database schema, typically after applying other migrations.

## Query Description:
This operation is non-destructive and does not alter any data or table structures. It simply sends a notification to the PostgREST service to trigger a schema reload. It is safe to run at any time and is often used to fix inconsistencies between the database and the API layer.

## Metadata:
- Schema-Category: ["Safe"]
- Impact-Level: ["Low"]
- Requires-Backup: false
- Reversible: true

## Structure Details:
- No structural changes are made. This is a notification-only operation.

## Security Implications:
- RLS Status: [Enabled]
- Policy Changes: [No]
- Auth Requirements: [None]

## Performance Impact:
- Indexes: [Not Affected]
- Triggers: [Not Affected]
- Estimated Impact: [Negligible. There might be a brief moment of latency as the schema is reloaded by the API service, but it is typically seamless.]
*/

-- This command signals the PostgREST service to reload its schema cache.
NOTIFY pgrst, 'reload schema';
