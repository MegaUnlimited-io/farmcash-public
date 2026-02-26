-- Add locale column to public.users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS locale TEXT DEFAULT 'en';

-- Optional: Add comment for documentation
COMMENT ON COLUMN public.users.locale IS 'User preferred language/locale (e.g., en, de, fr)';