const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.local' });

// CONFIGURATION
const IMAGES_DIR = './BabyKeyboardLock/Resources/FlashcardImages'; // Update this to your actual path
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Error: Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env.local');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function uploadImages() {
  console.log('Starting upload process...');
  
  // Recursive function to find all png files
  function getFiles(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(function(file) {
      file = path.resolve(dir, file);
      const stat = fs.statSync(file);
      if (stat && stat.isDirectory()) { 
        results = results.concat(getFiles(file));
      } else { 
        if (file.endsWith('.png')) results.push(file);
      }
    });
    return results;
  }

  try {
    const files = getFiles(IMAGES_DIR);
    console.log(`Found ${files.length} images to process.`);

    for (const filePath of files) {
      const filename = path.basename(filePath);
      // Expected format: style_word.png (e.g., crayon_apple.png)
      const match = filename.match(/^([^_]+)_([^\.]+)\.png$/);
      
      if (!match) {
        console.warn(`Skipping file with invalid format: ${filename}`);
        continue;
      }

      const [_, style, wordText] = match;
      const normalizedWord = wordText.toLowerCase();

      console.log(`Processing: ${filename} -> Word: ${normalizedWord}, Style: ${style}`);

      // 1. Find or Create the Word
      let wordId;
      const { data: existingWord, error: findError } = await supabase
        .from('words')
        .select('id')
        .eq('text_en', normalizedWord)
        .single();

      if (findError && findError.code !== 'PGRST116') {
        console.error(`Error finding word ${normalizedWord}:`, findError.message);
        continue;
      }

      if (existingWord) {
        wordId = existingWord.id;
      } else {
        // Create new word
        const { data: newWord, error: createError } = await supabase
          .from('words')
          .insert({ 
            text_en: normalizedWord,
            text_ru: normalizedWord, // Placeholder, you can update later
            text_de: normalizedWord  // Placeholder
          })
          .select('id')
          .single();

        if (createError) {
          console.error(`Error creating word ${normalizedWord}:`, createError.message);
          continue;
        }
        wordId = newWord.id;
        console.log(`Created new word: ${normalizedWord}`);
      }

      // 2. Read file and convert to base64
      const fileBuffer = fs.readFileSync(filePath);
      const base64Image = `data:image/png;base64,${fileBuffer.toString('base64')}`;

      // 3. Upsert into word_images
      const { error: upsertError } = await supabase
        .from('word_images')
        .upsert({
          word_id: wordId,
          style: style,
          image_url: base64Image
        }, {
          onConflict: 'word_id,style'
        });

      if (upsertError) {
        console.error(`Error uploading image for ${normalizedWord} (${style}):`, upsertError.message);
      } else {
        console.log(`Successfully uploaded: ${normalizedWord} (${style})`);
      }
    }

    console.log('Upload process complete!');

  } catch (err) {
    console.error('Fatal error:', err);
  }
}

uploadImages();
