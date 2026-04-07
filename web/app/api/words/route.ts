import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const style = searchParams.get('style') || 'simple';
    const paramLimit = searchParams.get('limit') ? parseInt(searchParams.get('limit')!) : null;
    const paramTopics = searchParams.get('topics') ? searchParams.get('topics')!.split(',') : null;
    const mode = searchParams.get('mode'); // Add mode parameter

    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    // 1. Fetch all words first
    let query = supabase
      .from('words')
      .select('*')
      .order('created_at', { ascending: true }); // Stable ordering for "Active Pool" logic

    // If user is logged in, filter by their words + global words
    if (user) {
      query = query.or(`user_id.is.null,user_id.eq.${user.id}`);
    } else {
      query = query.is('user_id', null);
    }

    const { data: allWords, error } = await query;

    if (error) {
      console.error('Error fetching words:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Fetch word_images separately (safe if table doesn't exist)
    let wordImages: any[] = [];
    try {
      const { data: wi } = await supabase
        .from('word_images')
        .select('word_id, image_url, style');
      wordImages = wi || [];
    } catch {
      // word_images table may not exist yet
    }

    // Fetch custom images for the user if logged in
    let customImages: any[] = [];
    if (user) {
      try {
        const { data: ci } = await supabase
          .from('custom_images')
          .select('*')
          .eq('user_id', user.id);
        customImages = ci || [];
      } catch {
        // custom_images table may not exist yet
      }
    }

    let finalWords = allWords || [];

    if (mode === 'manage') {
      const processedWords = finalWords.map(word => {
        // Check for custom image first
        const customImage = customImages.find(ci => ci.word_id === word.id && (ci.style === style || ci.style === null));
        
        const myImages = wordImages.filter((img: any) => img.word_id === word.id);
        const styleImage = myImages.find((img: any) => img.style === style);
        const simpleImage = myImages.find((img: any) => img.style === 'simple');
        const anyImage = myImages[0];
        
        const imageUrl = customImage?.image_url || styleImage?.image_url || simpleImage?.image_url || anyImage?.image_url || word.generated_image_url;

        return {
          ...word,
          image_url: imageUrl,
        };
      });
      return NextResponse.json({ words: processedWords });
    }

    let knownWordIds = new Set<string>();

    // 2. Apply Learning Logic
    
    // Fetch user settings/progress if logged in
    let activeLimit = 10;
    let enabledTopics: string[] = [];

    if (user) {
      const { data: settings } = await supabase
        .from('user_settings')
        .select('active_word_limit, enabled_topics')
        .eq('user_id', user.id)
        .maybeSingle();

      activeLimit = settings?.active_word_limit || 10;
      enabledTopics = settings?.enabled_topics || [];

      const { data: progress } = await supabase
        .from('user_word_progress')
        .select('word_id, is_known')
        .eq('user_id', user.id);

      if (progress) {
        progress.filter(p => p.is_known).forEach(p => knownWordIds.add(p.word_id));
      }
    }

    if (paramLimit !== null) activeLimit = paramLimit;
    if (paramTopics !== null) enabledTopics = paramTopics;

    // Filter by topics (if any are enabled)
    if (enabledTopics.length > 0) {
      finalWords = finalWords.filter(w => enabledTopics.includes(w.topic_id));
    }

    // Split into pools
    const knownPool = finalWords.filter(w => knownWordIds.has(w.id));
    const unknownPool = finalWords.filter(w => !knownWordIds.has(w.id));

    if (user) {
      unknownPool.sort((a, b) => {
        const aIsCustom = a.user_id === user.id;
        const bIsCustom = b.user_id === user.id;
        if (aIsCustom && !bIsCustom) return -1;
        if (!aIsCustom && bIsCustom) return 1;
        return 0;
      });
    }

    // Apply Active Limit to unknown pool (take first N)
    // The initial query already sorts by created_at
    const activeUnknownPool = unknownPool.slice(0, activeLimit);

    // Process images for both pools
    const processWord = (word: any) => {
      // Check for custom image first
      const customImage = customImages.find(ci => ci.word_id === word.id && (ci.style === style || ci.style === null));

      const styleImage = word.word_images?.find((img: any) => img.style === style);
      const simpleImage = word.word_images?.find((img: any) => img.style === 'simple');
      const anyImage = word.word_images?.[0];
      
      const imageUrl = customImage?.image_url || styleImage?.image_url || simpleImage?.image_url || anyImage?.image_url || word.generated_image_url;

      return {
        ...word,
        image_url: imageUrl,
        is_known: knownWordIds.has(word.id),
        word_images: undefined
      };
    };

    return NextResponse.json({ 
      words: activeUnknownPool.map(processWord), // The "Active Pool"
      knownWords: knownPool.map(processWord)     // The "Known Words"
    });
  } catch (error) {
    console.error('Error in words API:', error);
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

    const body = await request.json();
    
    // Validate required fields
    if (!body.word_en && !body.word_ru && !body.word_de) {
      return NextResponse.json(
        { error: 'At least one language is required' },
        { status: 400 }
      );
    }

    const { data, error } = await supabase
      .from('words')
      .insert({
        ...body,
        user_id: user.id,
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating word:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json(data);
  } catch (error) {
    console.error('Error in words POST API:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
