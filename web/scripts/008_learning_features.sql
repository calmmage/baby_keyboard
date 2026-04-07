-- Create topics table
CREATE TABLE IF NOT EXISTS topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add topic_id to words
ALTER TABLE words ADD COLUMN IF NOT EXISTS topic_id UUID REFERENCES topics(id);

-- Create user_word_progress table
CREATE TABLE IF NOT EXISTS user_word_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  word_id UUID REFERENCES words(id) NOT NULL,
  is_known BOOLEAN DEFAULT FALSE,
  last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  review_count INTEGER DEFAULT 0,
  UNIQUE(user_id, word_id)
);

-- Update user_settings table
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS active_word_limit INTEGER DEFAULT 10;
ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS enabled_topics JSONB DEFAULT '[]'::jsonb;
ALTER TABLE user_settings ALTER COLUMN secondary_language DROP NOT NULL;

-- Enable RLS
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies for topics
CREATE POLICY "Topics are viewable by everyone" ON topics FOR SELECT USING (true);
CREATE POLICY "Topics are insertable by authenticated users" ON topics FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- RLS Policies for user_word_progress
CREATE POLICY "Users can view their own progress" ON user_word_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert/update their own progress" ON user_word_progress FOR ALL USING (auth.uid() = user_id);

-- Seed initial topics
INSERT INTO topics (name, slug) VALUES 
  ('Animals', 'animals'),
  ('Food', 'food'),
  ('Family', 'family'),
  ('Colors', 'colors'),
  ('Numbers', 'numbers'),
  ('Actions', 'actions'),
  ('Objects', 'objects')
ON CONFLICT (slug) DO NOTHING;

-- Assign existing words to 'Animals' topic (as a default for migration)
DO $$
DECLARE
  animals_topic_id UUID;
BEGIN
  SELECT id INTO animals_topic_id FROM topics WHERE slug = 'animals';
  UPDATE words SET topic_id = animals_topic_id WHERE topic_id IS NULL;
END $$;
