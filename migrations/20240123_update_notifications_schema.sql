-- Migration 20240123: Update notifications schema

-- 1. Add new columns to notifications table
ALTER TABLE notifications
ADD COLUMN IF NOT EXISTS type text CHECK (type IN ('transactional', 'learning', 'social', 'engagement', 'marketing')),
ADD COLUMN IF NOT EXISTS category text,
ADD COLUMN IF NOT EXISTS image_url text,
ADD COLUMN IF NOT EXISTS action_url text,
ADD COLUMN IF NOT EXISTS expires_at timestamptz;

-- 2. Create notification_preferences table
CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email_marketing boolean DEFAULT true,
  push_learning boolean DEFAULT true,
  push_social boolean DEFAULT true,
  push_marketing boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 3. RLS policies for notification_preferences
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notification_preferences' 
        AND policyname = 'Users can view their own preferences'
    ) THEN
        CREATE POLICY "Users can view their own preferences"
        ON notification_preferences FOR SELECT
        USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notification_preferences' 
        AND policyname = 'Users can update their own preferences'
    ) THEN
        CREATE POLICY "Users can update their own preferences"
        ON notification_preferences FOR UPDATE
        USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notification_preferences' 
        AND policyname = 'Users can insert their own preferences'
    ) THEN
        CREATE POLICY "Users can insert their own preferences"
        ON notification_preferences FOR INSERT
        WITH CHECK (auth.uid() = user_id);
    END IF;
END
$$;
