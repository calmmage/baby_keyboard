import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

const STYLE_PROMPTS: Record<string, string> = {
  "crayon": "Children's crayon drawing, bold outlines, bright colors, waxy texture",
  "doodle": "Simple hand-drawn doodle, clean black lines, minimal shading, high contrast",
  "pencil": "Soft pencil sketch, light shading, gentle graphite texture, minimal color",
  "simple": "Simple cool image of the requested object, white background, high quality",
  "watercolor": "Playful watercolor wash, soft gradients, organic textures, storybook vibe"
};

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { word_id, word_text, style = "simple" } = await request.json();

    if (!word_id || !word_text) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const stylePrompt = STYLE_PROMPTS[style] || STYLE_PROMPTS["simple"];
    const fullPrompt = `${stylePrompt}. Subject: ${word_text}. No text, no labels, white background.`;

    const apiKey = process.env.GOOGLE_GENERATIVE_AI_API_KEY || process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return NextResponse.json({ error: 'Missing API Key' }, { status: 500 });
    }

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: fullPrompt }
            ]
          }]
        })
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Google API Error:', errorText);
      return NextResponse.json({ error: `Google API Error: ${errorText}` }, { status: response.status });
    }

    const data = await response.json();
    
    // Extract base64 image data from the response
    // Expected path: candidates[0].content.parts[].inlineData.data
    let base64Data = null;
    const parts = data.candidates?.[0]?.content?.parts || [];
    
    for (const part of parts) {
      if (part.inlineData && part.inlineData.data) {
        base64Data = part.inlineData.data;
        break;
      }
    }

    if (!base64Data) {
      console.error('No image data found in response:', JSON.stringify(data));
      return NextResponse.json({ error: 'No image generated' }, { status: 500 });
    }

    const binaryString = atob(base64Data);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    const blob = new Blob([bytes], { type: 'image/png' });

    // Upload to Supabase Storage
    const fileName = `generated/${word_id}-${style}-${Date.now()}.png`;
    const { error: uploadError } = await supabase.storage
      .from('images')
      .upload(fileName, blob, {
        contentType: 'image/png',
        cacheControl: '31536000',
        upsert: true,
      });

    if (uploadError) {
      console.error('Storage upload error:', uploadError);
      return NextResponse.json({ error: uploadError.message }, { status: 500 });
    }

    const { data: { publicUrl } } = supabase.storage
      .from('images')
      .getPublicUrl(fileName);

    // Save to word_images table
    const { error: dbError } = await supabase
      .from('word_images')
      .upsert({
        word_id,
        style,
        image_url: publicUrl
      }, {
        onConflict: 'word_id, style'
      });

    if (dbError) {
      console.error('Database error:', dbError);
      return NextResponse.json({ error: dbError.message }, { status: 500 });
    }

    return NextResponse.json({ imageUrl: publicUrl });
  } catch (error) {
    console.error('Generation failed:', error);
    return NextResponse.json(
      { error: 'Failed to generate image' },
      { status: 500 }
    );
  }
}
