import { NextResponse } from "next/server";

import { deleteMediaObject, listMediaObjectsByPrefix, uploadMedia } from "@/lib/media-storage";

const EXTENSIONS_BY_MIME: Record<string, string> = {
  "audio/webm": "webm",
  "audio/mp4": "m4a",
  "audio/mpeg": "mp3",
  "audio/wav": "wav",
  "audio/x-wav": "wav",
  "audio/ogg": "ogg",
};

function safeSegment(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-");
}

function sanitizeWordID(value: string): string {
  return encodeURIComponent(value.trim().toLowerCase());
}

function pickExtension(file: File): string {
  const byMime = EXTENSIONS_BY_MIME[file.type.trim().toLowerCase()];
  if (byMime) {
    return byMime;
  }
  const byName = file.name.split(".").pop()?.toLowerCase();
  return byName && /^[a-z0-9]+$/.test(byName) ? byName : "webm";
}

export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const file = formData.get("file");
    const wordId = String(formData.get("wordId") ?? "").trim();
    const language = safeSegment(String(formData.get("language") ?? ""));

    if (!(file instanceof File) || !wordId || !language) {
      return NextResponse.json(
        { error: "file, wordId, language are required" },
        { status: 400 },
      );
    }

    const extension = pickExtension(file);
    const safeWordID = sanitizeWordID(wordId);
    const objectKey = `generated-media/audio/custom/${language}/${safeWordID}.${extension}`;
    const arrayBuffer = await file.arrayBuffer();
    const uploaded = await uploadMedia({
      objectKey,
      data: Buffer.from(arrayBuffer),
      contentType: file.type || `audio/${extension}`,
      cacheControl: "public,max-age=31536000,immutable",
    });

    return NextResponse.json({
      ok: true,
      wordId,
      language,
      url: uploaded.publicUrl,
      objectKey: uploaded.objectKey,
      storageProvider: uploaded.provider,
      mimeType: file.type || `audio/${extension}`,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to upload audio" },
      { status: 500 },
    );
  }
}

export async function DELETE(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const wordId = String(searchParams.get("wordId") ?? "").trim();
    const language = safeSegment(String(searchParams.get("language") ?? ""));
    if (!wordId || !language) {
      return NextResponse.json(
        { error: "wordId and language are required" },
        { status: 400 },
      );
    }

    const safeWordID = sanitizeWordID(wordId);
    const prefix = `generated-media/audio/custom/${language}/${safeWordID}`;
    const entries = await listMediaObjectsByPrefix(prefix);

    for (const entry of entries) {
      if (entry.includes(`${safeWordID}.`)) {
        await deleteMediaObject(entry);
      }
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to delete audio override" },
      { status: 500 },
    );
  }
}
