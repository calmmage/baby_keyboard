-- Create a table to store generated images for each word and style combination
CREATE TABLE IF NOT EXISTS word_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  style TEXT NOT NULL CHECK (style IN ('crayon', 'doodle', 'pencil', 'simple', 'watercolor')),
  image_url TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure one image per word+style
  UNIQUE(word_id, style)
);

-- Enable RLS
ALTER TABLE word_images ENABLE ROW LEVEL SECURITY;

-- Everyone can read word images
CREATE POLICY "word_images_select_public" ON word_images
  FOR SELECT
  USING (true);

-- Only authenticated users can insert (via API)
CREATE POLICY "word_images_insert_auth" ON word_images
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Create index
CREATE INDEX idx_word_images_lookup ON word_images(word_id, style);
