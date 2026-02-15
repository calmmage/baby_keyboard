import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { word_id, is_known } = await request.json();

    if (!word_id) {
      return NextResponse.json({ error: 'Word ID is required' }, { status: 400 });
    }

    const { data, error } = await supabase
      .from('user_word_progress')
      .upsert({
        user_id: user.id,
        word_id,
        is_known,
        last_seen_at: new Date().toISOString(),
        // Increment review count if it exists, else 1
      }, { onConflict: 'user_id, word_id' })
      .select()
      .single();

    if (error) {
      console.error('Error updating progress:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json(data);
  } catch (error) {
    console.error('Error in word-progress API:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
