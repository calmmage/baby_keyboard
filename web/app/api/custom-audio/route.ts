import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET() {
  try {
    const supabase = await createClient();

    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ audios: [] });
    }

    // Fetch custom audios for this user
    const { data: audios, error } = await supabase
      .from('custom_audio')
      .select('*')
      .eq('user_id', user.id);

    if (error) {
      console.error('Error fetching custom audios:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ audios: audios || [] });
  } catch (error) {
    console.error('Error in custom-audio GET API:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(request: Request) {
  try {
    const supabase = await createClient();

    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const formData = await request.formData();
    const audioFile = formData.get('audio') as File;
    const wordId = formData.get('word_id') as string;
    const language = formData.get('language') as string;

    if (!audioFile || !wordId || !language) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Create a unique file name
    const fileName = `${user.id}/${wordId}_${language}_${Date.now()}.webm`;

    // Upload to Supabase Storage
    // Note: We'll use a simple in-memory approach since Supabase Storage buckets need to be created first
    // For production, you would upload to Supabase Storage like this:
    // const { data: uploadData, error: uploadError } = await supabase.storage
    //   .from('audio')
    //   .upload(fileName, audioFile);

    // For now, we'll convert the audio to a data URL and store it directly
    const arrayBuffer = await audioFile.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    const base64Audio = buffer.toString('base64');
    const audioUrl = `data:audio/webm;base64,${base64Audio}`;

    // Check if audio already exists for this word and language
    const { data: existing } = await supabase
      .from('custom_audio')
      .select('id')
      .eq('word_id', wordId)
      .eq('language', language)
      .eq('user_id', user.id)
      .single();

    if (existing) {
      // Update existing
      const { data, error } = await supabase
        .from('custom_audio')
        .update({ audio_url: audioUrl })
        .eq('id', existing.id)
        .select()
        .single();

      if (error) {
        console.error('Error updating custom audio:', error);
        return NextResponse.json({ error: error.message }, { status: 500 });
      }

      return NextResponse.json(data);
    } else {
      // Insert new
      const { data, error } = await supabase
        .from('custom_audio')
        .insert({
          word_id: wordId,
          language,
          audio_url: audioUrl,
          user_id: user.id,
        })
        .select()
        .single();

      if (error) {
        console.error('Error creating custom audio:', error);
        return NextResponse.json({ error: error.message }, { status: 500 });
      }

      return NextResponse.json(data);
    }
  } catch (error) {
    console.error('Error in custom-audio POST API:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
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
    const language = searchParams.get('language');

    if (!wordId || !language) {
      return NextResponse.json(
        { error: 'Missing required parameters' },
        { status: 400 }
      );
    }

    const { error } = await supabase
      .from('custom_audio')
      .delete()
      .eq('word_id', wordId)
      .eq('language', language)
      .eq('user_id', user.id);

    if (error) {
      console.error('Error deleting custom audio:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error in custom-audio DELETE API:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
