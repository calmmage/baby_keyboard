-- Add style column to custom_images
ALTER TABLE custom_images ADD COLUMN IF NOT EXISTS style text;

-- Add constraint to ensure style is valid if provided
ALTER TABLE custom_images DROP CONSTRAINT IF EXISTS custom_images_style_check;
ALTER TABLE custom_images ADD CONSTRAINT custom_images_style_check 
  CHECK (style IN ('crayon', 'doodle', 'pencil', 'simple', 'watercolor') OR style IS NULL);
