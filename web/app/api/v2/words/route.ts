import { NextResponse } from "next/server";

import {
  buildWordSetIndex,
  loadCanonicalCatalog,
  pickAssetURI,
  pickTranslation,
  translationsToMap,
} from "@/lib/canonical-model";
import { keyForWordAndLanguage, loadPresynthAudioMap } from "@/lib/audio-manifest";

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const limit = Number.parseInt(searchParams.get("limit") ?? "250", 10);
    const setID = searchParams.get("set");
    const featuredParam = searchParams.get("featured") ?? "";
    const primaryLanguage = searchParams.get("primaryLanguage") ?? "en";
    const secondaryLanguage = searchParams.get("secondaryLanguage") ?? "ru";
    const featuredWordIDs = featuredParam
      .split(",")
      .map((id) => id.trim())
      .filter((id) => id.length > 0);

    const catalog = await loadCanonicalCatalog();
    const presynthAudioMap = await loadPresynthAudioMap();
    const setIndex = buildWordSetIndex(catalog.sets);
    const selectedSet = setID ? catalog.sets.find((set) => set.id === setID) : undefined;
    const allowedIDs = selectedSet ? new Set(selectedSet.wordIDs) : undefined;
    const entriesByID = new Map(catalog.entries.map((entry) => [entry.id, entry]));
    const cappedLimit = Number.isFinite(limit) && limit > 0 ? limit : 250;

    const filteredEntries = catalog.entries.filter((entry) => !allowedIDs || allowedIDs.has(entry.id));
    const mergedEntries = filteredEntries.slice(0, cappedLimit);
    for (const featuredID of featuredWordIDs) {
      const featuredEntry = entriesByID.get(featuredID);
      if (!featuredEntry) {
        continue;
      }
      if (!mergedEntries.some((entry) => entry.id === featuredEntry.id)) {
        mergedEntries.push(featuredEntry);
      }
    }

    const words = mergedEntries.map((entry) => {
      const translations = translationsToMap(entry.translations);
      return {
        id: entry.id,
        spelling: entry.spelling,
        meaningKey: entry.meaningKey ?? null,
        partOfSpeech: entry.partOfSpeech ?? null,
        category: entry.category ?? null,
        tags: entry.tags,
        setIDs: setIndex.get(entry.id) ?? [],
        translations,
        primaryText:
          primaryLanguage === "en"
            ? entry.spelling
            : pickTranslation(entry.translations, [primaryLanguage]) ?? entry.spelling,
        secondaryText:
          secondaryLanguage === "en"
            ? entry.spelling
            : pickTranslation(entry.translations, [secondaryLanguage]),
        preSynthAudioURI: presynthAudioMap.get(
          keyForWordAndLanguage(entry.id, secondaryLanguage),
        ),
        imageURI: pickAssetURI(entry, "image"),
        audioURI: pickAssetURI(entry, "audio", secondaryLanguage),
      };
    });

    return NextResponse.json({
      version: catalog.version,
      source: catalog.source,
      sets: catalog.sets,
      words,
    });
  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Failed to load words",
      },
      { status: 500 },
    );
  }
}
