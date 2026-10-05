import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const supabase = await createClient();
    const { id } = await params;

    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { error } = await supabase
      .from('words')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id); // Only allow deleting own words

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const supabase = await createClient();
    const { id } = await params;
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();

    // Only allow updating specific fields for now
    const updates: any = {};
    if (body.topic_id) updates.topic_id = body.topic_id;
    // Add other fields as needed

    const { data, error } = await supabase
      .from('words')
      .update(updates)
      .eq('id', id)
      // Allow updating global words? Probably not for now, or maybe yes if admin?
      // For now, let's restrict to user's words OR allow if it's just topic assignment?
      // The requirement implies parents manage words. If they can see global words, they might want to organize them.
      // But RLS usually prevents updating rows you don't own.
      // Let's assume for now they can only update their own words.
      .eq('user_id', user.id) 
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json(data);
  } catch (error) {
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
