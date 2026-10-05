import "server-only";

import { readFile } from "node:fs/promises";
import path from "node:path";

type PresynthAudioItem = {
  word_id: string;
  language: string;
  url: string;
  text?: string;
  voice?: string;
};

type PresynthManifest = {
  generated_at?: string;
  items?: PresynthAudioItem[];
};

export function normalizeLanguage(value: string): string {
  return value.trim().toLowerCase();
}

export function keyForWordAndLanguage(wordID: string, language: string): string {
  return `${wordID}|${normalizeLanguage(language)}`;
}

export async function loadPresynthAudioMap(): Promise<Map<string, string>> {
  const manifestPath = path.resolve(
    process.cwd(),
    "public",
    "generated-audio",
    "presynth",
    "manifest.json",
  );

  try {
    const raw = await readFile(manifestPath, "utf8");
    const parsed = JSON.parse(raw) as PresynthManifest;
    const map = new Map<string, string>();
    for (const item of parsed.items ?? []) {
      if (!item.word_id || !item.language || !item.url) {
        continue;
      }
      map.set(keyForWordAndLanguage(item.word_id, item.language), item.url);
    }
    return map;
  } catch {
    return new Map<string, string>();
  }
}

