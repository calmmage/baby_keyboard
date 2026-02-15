-- Add review settings to user_settings table
ALTER TABLE user_settings 
ADD COLUMN IF NOT EXISTS review_probability float DEFAULT 0.2,
ADD COLUMN IF NOT EXISTS enable_review boolean DEFAULT true;
