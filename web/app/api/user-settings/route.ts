import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET() {
  try {
    const supabase = await createClient();

    const { data: { user } } = await supabase.auth.getUser();

    // If no user, return defaults
    if (!user) {
      return NextResponse.json({
        primary_language: 'en',
        secondary_language: 'ru',
        active_word_limit: 10,
        enabled_topics: [],
        review_probability: 0.5, // Default value for review_probability
        enable_review: false, // Default value for enable_review
      });
    }

    const { data: settings, error } = await supabase
      .from('user_settings')
      .select('*')
      .eq('user_id', user.id);

    if (error) {
      console.error('Error fetching user settings:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // If no settings exist yet, return defaults
    if (!settings || settings.length === 0) {
      return NextResponse.json({
        primary_language: 'en',
        secondary_language: 'ru',
        active_word_limit: 10,
        enabled_topics: [],
        review_probability: 0.5, // Default value for review_probability
        enable_review: false, // Default value for enable_review
      });
    }

    // Return the first (and only) settings record
    return NextResponse.json(settings[0]);
  } catch (error) {
    console.error('Error in user-settings API:', error);
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

    const body = await request.json();
    const { 
      primary_language, 
      secondary_language, 
      active_word_limit, 
      enabled_topics,
      review_probability, // Add new field
      enable_review // Add new field
    } = body;

    // Upsert user settings
    const { data, error } = await supabase
      .from('user_settings')
      .upsert({
        user_id: user.id,
        primary_language,
        secondary_language: secondary_language === 'none' ? null : secondary_language,
        active_word_limit: active_word_limit || 10,
        enabled_topics: enabled_topics || [],
        review_probability: review_probability, // Add new field
        enable_review: enable_review, // Add new field
        updated_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) {
      console.error('Error updating user settings:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json(data);
  } catch (error) {
    console.error('Error in user-settings POST API:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
