import { NextResponse } from "next/server";

import { deleteMediaObject, listMediaObjectsByPrefix, uploadMedia } from "@/lib/media-storage";

const EXTENSIONS_BY_MIME: Record<string, string> = {
  "video/mp4": "mp4",
  "video/webm": "webm",
  "video/quicktime": "mov",
  "video/x-matroska": "mkv",
};

function sanitizeWordID(value: string): string {
  return encodeURIComponent(value.trim().toLowerCase());
}

function pickExtension(file: File): string {
  const byMime = EXTENSIONS_BY_MIME[file.type.trim().toLowerCase()];
  if (byMime) {
    return byMime;
  }
  const byName = file.name.split(".").pop()?.toLowerCase();
  return byName && /^[a-z0-9]+$/.test(byName) ? byName : "mp4";
}

export async function POST(request: Request) {
  try {
    const formData = await request.formData();
    const file = formData.get("file");
    const wordId = String(formData.get("wordId") ?? "").trim();

    if (!(file instanceof File) || !wordId) {
      return NextResponse.json({ error: "file and wordId are required" }, { status: 400 });
    }

    const extension = pickExtension(file);
    const safeWordID = sanitizeWordID(wordId);
    const objectKey = `generated-media/video/${safeWordID}.${extension}`;
    const arrayBuffer = await file.arrayBuffer();
    const uploaded = await uploadMedia({
      objectKey,
      data: Buffer.from(arrayBuffer),
      contentType: file.type || `video/${extension}`,
      cacheControl: "public,max-age=31536000,immutable",
    });

    return NextResponse.json({
      ok: true,
      wordId,
      url: uploaded.publicUrl,
      objectKey: uploaded.objectKey,
      storageProvider: uploaded.provider,
      mimeType: file.type || `video/${extension}`,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to upload video" },
      { status: 500 },
    );
  }
}

export async function DELETE(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const wordId = String(searchParams.get("wordId") ?? "").trim();
    if (!wordId) {
      return NextResponse.json({ error: "wordId is required" }, { status: 400 });
    }

    const safeWordID = sanitizeWordID(wordId);
    const prefix = `generated-media/video/${safeWordID}`;
    const entries = await listMediaObjectsByPrefix(prefix);
    for (const entry of entries) {
      if (entry.includes(`${safeWordID}.`)) {
        await deleteMediaObject(entry);
      }
    }

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to delete video" },
      { status: 500 },
    );
  }
}

