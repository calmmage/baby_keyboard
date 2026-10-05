-- Add image_style column to words table
ALTER TABLE words ADD COLUMN IF NOT EXISTS image_style TEXT DEFAULT 'simple' CHECK (image_style IN ('crayon', 'doodle', 'pencil', 'simple', 'watercolor'));

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_words_image_style ON words(image_style);
