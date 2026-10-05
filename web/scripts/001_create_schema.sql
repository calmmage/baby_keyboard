-- Words table: stores word data with support for multiple languages
-- Global words (user_id = null) vs user-specific words
CREATE TABLE IF NOT EXISTS words (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Word in different languages
  word_en TEXT,
  word_ru TEXT,
  word_de TEXT,
  
  -- Generated image URL (shared globally when user_id is null)
  generated_image_url TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Custom audio recordings for words
CREATE TABLE IF NOT EXISTS custom_audio (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Which language this audio is for
  language TEXT NOT NULL CHECK (language IN ('en', 'ru', 'de')),
  
  -- Audio file URL (stored in Supabase Storage)
  audio_url TEXT NOT NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Custom images for words (per-user)
CREATE TABLE IF NOT EXISTS custom_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Image file URL (stored in Supabase Storage)
  image_url TEXT NOT NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User settings for language preferences
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  primary_language TEXT NOT NULL DEFAULT 'en' CHECK (primary_language IN ('en', 'ru', 'de')),
  secondary_language TEXT NOT NULL DEFAULT 'ru' CHECK (secondary_language IN ('en', 'ru', 'de')),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_audio ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for words
-- Everyone can read global words (user_id is null)
CREATE POLICY "words_select_global" ON words
  FOR SELECT
  USING (user_id IS NULL);

-- Users can read their own words
CREATE POLICY "words_select_own" ON words
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own words
CREATE POLICY "words_insert_own" ON words
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own words
CREATE POLICY "words_update_own" ON words
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own words
CREATE POLICY "words_delete_own" ON words
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for custom_audio
CREATE POLICY "custom_audio_select_own" ON custom_audio
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "custom_audio_insert_own" ON custom_audio
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "custom_audio_delete_own" ON custom_audio
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for custom_images
CREATE POLICY "custom_images_select_own" ON custom_images
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "custom_images_insert_own" ON custom_images
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "custom_images_delete_own" ON custom_images
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for user_settings
CREATE POLICY "user_settings_select_own" ON user_settings
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "user_settings_insert_own" ON user_settings
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_settings_update_own" ON user_settings
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX idx_words_user_id ON words(user_id);
CREATE INDEX idx_custom_audio_word_id ON custom_audio(word_id);
CREATE INDEX idx_custom_audio_user_id ON custom_audio(user_id);
CREATE INDEX idx_custom_images_word_id ON custom_images(word_id);
CREATE INDEX idx_custom_images_user_id ON custom_images(user_id);
