/*
# [Function] update_likes_count
Creates a function and trigger to automatically update the `likes_count` on news posts and marketplace products when a like is added or removed.

## Query Description: 
This script creates a database function and a trigger. It does not modify or delete any existing user data. It ensures that like counts are automatically and accurately maintained, which improves data consistency and performance by avoiding manual count queries.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by dropping the trigger and function)

## Structure Details:
- Creates function: `public.update_likes_count()`
- Creates trigger: `trg_update_likes_count` on table `public.post_likes`

## Security Implications:
- RLS Status: Not directly affected, but the function runs with definer's rights.
- Policy Changes: No
- Auth Requirements: None for the migration itself.

## Performance Impact:
- Indexes: None
- Triggers: Adds a trigger to `post_likes`. This adds a tiny overhead to like/unlike operations but significantly improves data integrity.
- Estimated Impact: Positive. Improves data integrity and read performance.
*/

-- Drop existing objects to ensure a clean, idempotent run
DROP TRIGGER IF EXISTS trg_update_likes_count ON public.post_likes;
DROP FUNCTION IF EXISTS public.update_likes_count();

-- Create the function to update likes count
CREATE OR REPLACE FUNCTION public.update_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = '' -- Secure the function against search path hijacking
AS $$
BEGIN
  -- If a like is added (INSERT)
  IF (TG_OP = 'INSERT') THEN
    -- If the like is for a news post
    IF (NEW.post_id IS NOT NULL) THEN
      UPDATE public.news_posts
      SET likes_count = likes_count + 1
      WHERE id = NEW.post_id;
    END IF;
    -- If the like is for a marketplace product
    IF (NEW.product_id IS NOT NULL) THEN
      UPDATE public.marketplace_products
      SET likes_count = likes_count + 1
      WHERE id = NEW.product_id;
    END IF;

  -- If a like is removed (DELETE)
  ELSIF (TG_OP = 'DELETE') THEN
    -- If the like was for a news post
    IF (OLD.post_id IS NOT NULL) THEN
      UPDATE public.news_posts
      SET likes_count = GREATEST(0, likes_count - 1) -- Use GREATEST to prevent negative counts
      WHERE id = OLD.post_id;
    END IF;
    -- If the like was for a marketplace product
    IF (OLD.product_id IS NOT NULL) THEN
      UPDATE public.marketplace_products
      SET likes_count = GREATEST(0, likes_count - 1) -- Use GREATEST to prevent negative counts
      WHERE id = OLD.product_id;
    END IF;
  END IF;

  RETURN NULL; -- The result is ignored for AFTER triggers
END;
$$;

-- Create the trigger that executes the function after a like is added or removed
CREATE TRIGGER trg_update_likes_count
AFTER INSERT OR DELETE ON public.post_likes
FOR EACH ROW EXECUTE FUNCTION public.update_likes_count();
