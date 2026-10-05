import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ images: [] });
    }

    const { data: images, error } = await supabase
      .from('custom_images')
      .select('*')
      .eq('user_id', user.id);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ images: images || [] });
  } catch (error) {
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    console.log('[v0] Starting image upload for user:', user.id);

    const formData = await request.formData();
    const imageFile = formData.get('image') as File;
    const wordId = formData.get('word_id') as string;
    const applyToAllStyles = formData.get('apply_to_all_styles') === 'true'; 
    const currentStyle = formData.get('style') as string;

    console.log('[v0] Upload params:', { wordId, currentStyle, applyToAllStyles, fileSize: imageFile?.size });

    if (!imageFile || !wordId) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    const arrayBuffer = await imageFile.arrayBuffer();
    
    const fileName = `${user.id}/${wordId}-${Date.now()}.${imageFile.name.split('.').pop()}`;
    
    console.log('[v0] Uploading to storage:', fileName);
    
    const { error: uploadError } = await supabase.storage
      .from('images')
      .upload(fileName, arrayBuffer, {
        contentType: imageFile.type,
        cacheControl: '3600',
        upsert: true,
      });

    if (uploadError) {
      console.error('[v0] Storage upload error:', uploadError);
      return NextResponse.json({ error: `Storage error: ${uploadError.message}` }, { status: 500 });
    }

    const { data: { publicUrl } } = supabase.storage
      .from('images')
      .getPublicUrl(fileName);

    console.log('[v0] Image uploaded successfully:', publicUrl);

    const styleValue = applyToAllStyles ? null : currentStyle;

    let query = supabase
      .from('custom_images')
      .select('id')
      .eq('word_id', wordId)
      .eq('user_id', user.id);
      
    if (styleValue === null) {
      query = query.is('style', null);
    } else {
      query = query.eq('style', styleValue);
    }
      
    const { data: existing } = await query.limit(1);

    if (existing && existing.length > 0) {
      const { error } = await supabase
        .from('custom_images')
        .update({ image_url: publicUrl })
        .eq('id', existing[0].id);

      if (error) {
        console.error('[v0] Database update error:', error);
        return NextResponse.json({ error: `Database error: ${error.message}` }, { status: 500 });
      }
    } else {
      const { error } = await supabase
        .from('custom_images')
        .insert({
          word_id: wordId,
          image_url: publicUrl,
          user_id: user.id,
          style: styleValue
        });

      if (error) {
        console.error('[v0] Database insert error:', error);
        return NextResponse.json({ error: `Database error: ${error.message}` }, { status: 500 });
      }
    }

    console.log('[v0] Upload complete');
    return NextResponse.json({ imageUrl: publicUrl });
  } catch (error: any) {
    console.error('[v0] Error in custom-images POST API:', error);
    return NextResponse.json({ 
      error: 'Internal server error', 
      details: error.message 
    }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const wordId = searchParams.get('word_id');

    if (!wordId) {
      return NextResponse.json({ error: 'Missing word_id' }, { status: 400 });
    }

    const { error } = await supabase
      .from('custom_images')
      .delete()
      .eq('word_id', wordId)
      .eq('user_id', user.id);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
