import "server-only";

import { readFile } from "node:fs/promises";
import path from "node:path";

export type CanonicalTranslation = {
  language: string;
  text: string;
};

export type CanonicalDefinition = {
  language: string;
  text: string;
  source?: string | null;
};

export type CanonicalAsset = {
  kind: "image" | "audio";
  language?: string | null;
  uri: string;
  rotationDegrees?: number | null;
};

export type CanonicalWordEntry = {
  id: string;
  spelling: string;
  meaningKey?: string | null;
  partOfSpeech?: string | null;
  category?: string | null;
  tags: string[];
  translations: CanonicalTranslation[];
  definitions: CanonicalDefinition[];
  assets: CanonicalAsset[];
};

export type CanonicalWordSet = {
  id: string;
  name: string;
  wordIDs: string[];
};

export type CanonicalCatalog = {
  version: number;
  source?: string | null;
  entries: CanonicalWordEntry[];
  sets: CanonicalWordSet[];
};

type LegacyCatalog = {
  version?: number;
  source?: string | null;
  sets: Array<{
    name: string;
    words: Array<{
      english: string;
      translation: string;
      clarification?: string | null;
    }>;
  }>;
};

function normalizeSpelling(value: string): string {
  return value.trim().toLowerCase();
}

function normalizeMeaningKey(value: string): string {
  const lowered = value.trim().toLowerCase();
  if (!lowered) {
    return "";
  }
  return lowered
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+/g, "")
    .replace(/-+$/g, "");
}

function slug(value: string): string {
  return normalizeMeaningKey(value) || "set";
}

export function makeWordID(spelling: string, meaningKey?: string | null): string {
  const base = normalizeSpelling(spelling);
  const meaning = normalizeMeaningKey(meaningKey ?? "");
  return meaning ? `${base}|${meaning}` : base;
}

function splitWordID(id: string): { spelling: string; meaningKey?: string } {
  const splitIndex = id.indexOf("|");
  if (splitIndex < 0) {
    return { spelling: id };
  }
  const spelling = id.slice(0, splitIndex);
  const meaning = id.slice(splitIndex + 1).trim();
  return { spelling, meaningKey: meaning || undefined };
}

function normalizeCanonicalCatalog(raw: CanonicalCatalog): CanonicalCatalog {
  const entries = raw.entries.map((entry) => {
    const split = splitWordID(entry.id);
    const spelling = entry.spelling.trim() || split.spelling;
    const meaningKey = entry.meaningKey ?? split.meaningKey;
    return {
      ...entry,
      spelling,
      meaningKey,
      id: makeWordID(spelling, meaningKey),
      tags: entry.tags ?? [],
      translations: entry.translations ?? [],
      definitions: entry.definitions ?? [],
      assets: entry.assets ?? [],
    };
  });

  return {
    version: raw.version ?? 2,
    source: raw.source ?? null,
    entries,
    sets: raw.sets ?? [],
  };
}

function convertLegacyCatalog(raw: LegacyCatalog): CanonicalCatalog {
  const variantsBySpelling = new Map<string, Set<string>>();
  for (const set of raw.sets ?? []) {
    for (const word of set.words ?? []) {
      const spelling = normalizeSpelling(word.english);
      const translation = normalizeMeaningKey(word.translation ?? "");
      if (!spelling || !translation) {
        continue;
      }
      if (!variantsBySpelling.has(spelling)) {
        variantsBySpelling.set(spelling, new Set<string>());
      }
      variantsBySpelling.get(spelling)?.add(translation);
    }
  }

  const entriesById = new Map<string, CanonicalWordEntry>();
  const orderedIDs: string[] = [];
  const sets: CanonicalWordSet[] = [];

  for (const [setIndex, set] of (raw.sets ?? []).entries()) {
    const setID = `set-${slug(set.name)}-${setIndex}`;
    const wordIDs: string[] = [];

    for (const word of set.words ?? []) {
      const spelling = word.english?.trim();
      if (!spelling) {
        continue;
      }
      const normalizedSpelling = normalizeSpelling(spelling);
      const translation = (word.translation ?? "").trim();
      const normalizedTranslation = normalizeMeaningKey(translation);
      const ambiguous = (variantsBySpelling.get(normalizedSpelling)?.size ?? 0) > 1;
      const meaningKey = ambiguous ? normalizedTranslation || "meaning" : undefined;
      const wordID = makeWordID(spelling, meaningKey);

      wordIDs.push(wordID);

      if (!entriesById.has(wordID)) {
        entriesById.set(wordID, {
          id: wordID,
          spelling,
          meaningKey,
          partOfSpeech: null,
          category: null,
          tags: [],
          translations: translation ? [{ language: "ru", text: translation }] : [],
          definitions: [],
          assets: [],
        });
        orderedIDs.push(wordID);
      }
    }

    sets.push({
      id: setID,
      name: set.name,
      wordIDs,
    });
  }

  return {
    version: Math.max(raw.version ?? 1, 2),
    source: raw.source ?? null,
    entries: orderedIDs.map((wordID) => entriesById.get(wordID)!).filter(Boolean),
    sets,
  };
}

async function readBundledCatalogJSON(): Promise<string> {
  const candidates = [
    path.resolve(process.cwd(), "..", "BabyKeyboardLock", "Resources", "word_sets.json"),
    path.resolve(process.cwd(), "BabyKeyboardLock", "Resources", "word_sets.json"),
  ];

  for (const candidate of candidates) {
    try {
      return await readFile(candidate, "utf8");
    } catch {
      continue;
    }
  }

  throw new Error("Cannot find BabyKeyboardLock/Resources/word_sets.json");
}

export async function loadCanonicalCatalog(): Promise<CanonicalCatalog> {
  const rawText = await readBundledCatalogJSON();
  const parsed = JSON.parse(rawText) as Partial<CanonicalCatalog> | LegacyCatalog;
  if (Array.isArray((parsed as CanonicalCatalog).entries)) {
    return normalizeCanonicalCatalog(parsed as CanonicalCatalog);
  }
  return convertLegacyCatalog(parsed as LegacyCatalog);
}

export function buildWordSetIndex(sets: CanonicalWordSet[]): Map<string, string[]> {
  const setIDsByWordID = new Map<string, string[]>();
  for (const set of sets) {
    for (const wordID of set.wordIDs) {
      if (!setIDsByWordID.has(wordID)) {
        setIDsByWordID.set(wordID, []);
      }
      setIDsByWordID.get(wordID)?.push(set.id);
    }
  }
  return setIDsByWordID;
}

export function translationsToMap(translations: CanonicalTranslation[]): Record<string, string> {
  const mapped: Record<string, string> = {};
  for (const translation of translations) {
    const key = translation.language.trim().toLowerCase();
    if (!key || !translation.text?.trim()) {
      continue;
    }
    mapped[key] = translation.text.trim();
  }
  return mapped;
}

export function pickTranslation(
  translations: CanonicalTranslation[],
  preferredLanguages: string[],
): string | undefined {
  const map = translationsToMap(translations);
  for (const preferred of preferredLanguages) {
    const normalized = preferred.trim().toLowerCase();
    if (!normalized) {
      continue;
    }
    if (map[normalized]) {
      return map[normalized];
    }
    const base = normalized.split("-")[0];
    if (base && map[base]) {
      return map[base];
    }
  }
  return undefined;
}

export function pickAssetURI(
  entry: CanonicalWordEntry,
  kind: CanonicalAsset["kind"],
  language?: string,
): string | undefined {
  if (language) {
    const normalized = language.trim().toLowerCase();
    const byLanguage = entry.assets.find(
      (asset) =>
        asset.kind === kind &&
        asset.language?.trim().toLowerCase() === normalized &&
        asset.uri?.trim(),
    );
    if (byLanguage?.uri) {
      return byLanguage.uri;
    }
  }
  return entry.assets.find((asset) => asset.kind === kind && asset.uri?.trim())?.uri;
}
