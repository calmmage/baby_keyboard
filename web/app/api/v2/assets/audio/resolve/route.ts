import { NextResponse } from "next/server";

import { keyForWordAndLanguage, loadPresynthAudioMap, normalizeLanguage } from "@/lib/audio-manifest";
import { listMediaObjectsByPrefix, publicUrlForObjectKey } from "@/lib/media-storage";

function sanitizeWordID(value: string): string {
  return encodeURIComponent(value.trim().toLowerCase());
}

function safeLanguage(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-");
}

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const wordId = String(searchParams.get("wordId") ?? "").trim();
    const language = safeLanguage(String(searchParams.get("language") ?? ""));
    if (!wordId || !language) {
      return NextResponse.json(
        { error: "wordId and language are required" },
        { status: 400 },
      );
    }

    const safeWordID = sanitizeWordID(wordId);
    const prefix = `generated-media/audio/custom/${language}/${safeWordID}`;
    const entries = await listMediaObjectsByPrefix(prefix);
    const custom = entries.find((entry) => entry.includes(`${safeWordID}.`));
    if (custom) {
      return NextResponse.json({
        source: "custom",
        url: publicUrlForObjectKey(custom),
      });
    }

    const map = await loadPresynthAudioMap();
    const presynth = map.get(keyForWordAndLanguage(wordId, normalizeLanguage(language)));
    if (presynth) {
      return NextResponse.json({
        source: "presynth",
        url: presynth,
      });
    }

    return NextResponse.json({ source: null, url: null });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to resolve audio" },
      { status: 500 },
    );
  }
}
