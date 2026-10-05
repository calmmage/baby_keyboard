"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ImageIcon, Mic, RefreshCw, Square, Trash2, Upload, Volume2, VolumeX, WandSparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type WordV2 = {
  id: string;
  spelling: string;
  meaningKey: string | null;
  translations: Record<string, string>;
  primaryText: string;
  secondaryText?: string;
  preSynthAudioURI?: string;
  audioURI?: string;
  imageURI?: string;
  setIDs: string[];
};

type WordSetV2 = {
  id: string;
  name: string;
  wordIDs: string[];
};

type WordsResponseV2 = {
  words: WordV2[];
  sets: WordSetV2[];
};

type SupportedLanguage = "en" | "ru" | "de";
type ImageStyle = "simple" | "crayon" | "doodle" | "watercolor" | "pencil";

const GENERATED_IMAGES_KEY = "baby-keyboard.generated-images.v2";
const CUSTOM_AUDIO_OVERRIDES_KEY = "baby-keyboard.custom-audio-overrides.v2";
const FEATURED_WORD_IDS_KEY = "baby-keyboard.featured-word-ids.v2";
const FEATURED_CUSTOM_WORDS_KEY = "baby-keyboard.featured-custom-words.v2";

const languageOptions: Array<{ value: SupportedLanguage; label: string }> = [
  { value: "en", label: "English" },
  { value: "ru", label: "Russian" },
  { value: "de", label: "German" },
];

const imageStyleOptions: Array<{ value: ImageStyle; label: string }> = [
  { value: "simple", label: "Simple" },
  { value: "crayon", label: "Crayon" },
  { value: "doodle", label: "Doodle" },
  { value: "watercolor", label: "Watercolor" },
  { value: "pencil", label: "Pencil" },
];

function resolveWordText(word: WordV2, language: SupportedLanguage): string {
  if (language === "en") {
    return word.spelling;
  }
  return word.translations[language] ?? word.spelling;
}

export default function FlashcardPlayerV2() {
  const [words, setWords] = useState<WordV2[]>([]);
  const [sets, setSets] = useState<WordSetV2[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedSetID, setSelectedSetID] = useState<string>("all");
  const [primaryLanguage, setPrimaryLanguage] = useState<SupportedLanguage>("en");
  const [secondaryLanguage, setSecondaryLanguage] = useState<SupportedLanguage>("ru");
  const [imageStyle, setImageStyle] = useState<ImageStyle>("simple");
  const [generatedImages, setGeneratedImages] = useState<Record<string, string>>({});
  const [customAudioOverrides, setCustomAudioOverrides] = useState<Record<string, string>>({});
  const [isLoading, setIsLoading] = useState(true);
  const [isGeneratingImage, setIsGeneratingImage] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [isUploadingRecording, setIsUploadingRecording] = useState(false);
  const [recordedAudioBlob, setRecordedAudioBlob] = useState<Blob | null>(null);
  const [recordedAudioPreviewURL, setRecordedAudioPreviewURL] = useState<string | null>(null);
  const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
  const [autoSpeak, setAutoSpeak] = useState(true);
  const [isMuted, setIsMuted] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [featuredWordIDs, setFeaturedWordIDs] = useState<string[]>([]);
  const [featuredCustomWords, setFeaturedCustomWords] = useState<WordV2[]>([]);
  const [featuredQuery, setFeaturedQuery] = useState("");
  const [featuredTranslation, setFeaturedTranslation] = useState("");

  const audioOverrideKey = useCallback(
    (wordId: string, language: SupportedLanguage) => `${wordId}|${language}`,
    [],
  );

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(GENERATED_IMAGES_KEY);
      if (raw) {
        setGeneratedImages(JSON.parse(raw) as Record<string, string>);
      }
    } catch {
      setGeneratedImages({});
    }
  }, []);

  useEffect(() => {
    window.localStorage.setItem(GENERATED_IMAGES_KEY, JSON.stringify(generatedImages));
  }, [generatedImages]);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(CUSTOM_AUDIO_OVERRIDES_KEY);
      if (raw) {
        setCustomAudioOverrides(JSON.parse(raw) as Record<string, string>);
      }
    } catch {
      setCustomAudioOverrides({});
    }
  }, []);

  useEffect(() => {
    window.localStorage.setItem(CUSTOM_AUDIO_OVERRIDES_KEY, JSON.stringify(customAudioOverrides));
  }, [customAudioOverrides]);

  useEffect(() => {
    try {
      const rawIDs = window.localStorage.getItem(FEATURED_WORD_IDS_KEY);
      if (rawIDs) {
        setFeaturedWordIDs(JSON.parse(rawIDs) as string[]);
      }
      const rawCustom = window.localStorage.getItem(FEATURED_CUSTOM_WORDS_KEY);
      if (rawCustom) {
        setFeaturedCustomWords(JSON.parse(rawCustom) as WordV2[]);
      }
    } catch {
      setFeaturedWordIDs([]);
      setFeaturedCustomWords([]);
    }
  }, []);

  useEffect(() => {
    window.localStorage.setItem(FEATURED_WORD_IDS_KEY, JSON.stringify(featuredWordIDs));
  }, [featuredWordIDs]);

  useEffect(() => {
    window.localStorage.setItem(FEATURED_CUSTOM_WORDS_KEY, JSON.stringify(featuredCustomWords));
  }, [featuredCustomWords]);

  const fetchWords = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const query = new URLSearchParams({
        primaryLanguage,
        secondaryLanguage,
      });
      if (selectedSetID !== "all") {
        query.set("set", selectedSetID);
      }
      if (featuredWordIDs.length > 0) {
        query.set("featured", featuredWordIDs.join(","));
      }
      const response = await fetch(`/api/v2/words?${query.toString()}`);
      if (!response.ok) {
        throw new Error(`Failed to load words (${response.status})`);
      }
      const data = (await response.json()) as WordsResponseV2;
      const mergedWords = [...(data.words ?? [])];
      for (const customWord of featuredCustomWords) {
        if (!mergedWords.some((word) => word.id === customWord.id)) {
          mergedWords.push(customWord);
        }
      }
      setWords(mergedWords);
      setSets(data.sets ?? []);
      setCurrentIndex(0);
    } catch (fetchError) {
      setError(fetchError instanceof Error ? fetchError.message : "Failed to load words");
      setWords([]);
    } finally {
      setIsLoading(false);
    }
  }, [primaryLanguage, secondaryLanguage, selectedSetID, featuredWordIDs, featuredCustomWords]);

  useEffect(() => {
    void fetchWords();
  }, [fetchWords]);

  const currentWord = words[currentIndex] ?? null;
  const currentImage = currentWord
    ? generatedImages[`${currentWord.id}|${imageStyle}`] ?? currentWord.imageURI
    : undefined;
  const currentCustomAudioURL = currentWord
    ? customAudioOverrides[audioOverrideKey(currentWord.id, secondaryLanguage)]
    : undefined;
  const currentAudioURL =
    currentCustomAudioURL ?? currentWord?.preSynthAudioURI ?? currentWord?.audioURI;

  const advanceWord = useCallback(() => {
    setCurrentIndex((prev) => {
      if (words.length === 0) {
        return 0;
      }
      return (prev + 1) % words.length;
    });
  }, [words.length]);

  const triggerImageGeneration = useCallback(async () => {
    if (!currentWord || isGeneratingImage) {
      return;
    }
    setIsGeneratingImage(true);
    try {
      const response = await fetch("/api/v2/assets/image/generate", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          wordId: currentWord.id,
          spelling: currentWord.spelling,
          style: imageStyle,
        }),
      });
      if (!response.ok) {
        throw new Error(`Generation failed (${response.status})`);
      }
      const payload = (await response.json()) as { imageUrl?: string };
      if (payload.imageUrl) {
        const key = `${currentWord.id}|${imageStyle}`;
        setGeneratedImages((prev) => ({ ...prev, [key]: payload.imageUrl! }));
      }
    } catch (generationError) {
      setError(generationError instanceof Error ? generationError.message : "Image generation failed");
    } finally {
      setIsGeneratingImage(false);
    }
  }, [currentWord, imageStyle, isGeneratingImage]);

  const speak = useCallback(
    async (word: WordV2) => {
      if (isMuted || typeof window === "undefined") {
        return;
      }
      const override = customAudioOverrides[audioOverrideKey(word.id, secondaryLanguage)];
      const preferredAudioURL = override ?? word.preSynthAudioURI ?? word.audioURI;
      if (preferredAudioURL) {
        try {
          const audio = new Audio(preferredAudioURL);
          await audio.play();
          return;
        } catch {
          // fall back to browser TTS
        }
      }
      if (!("speechSynthesis" in window)) {
        return;
      }
      const text = resolveWordText(word, secondaryLanguage);
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang =
        secondaryLanguage === "ru" ? "ru-RU" : secondaryLanguage === "de" ? "de-DE" : "en-US";
      utterance.rate = 0.85;
      window.speechSynthesis.cancel();
      window.speechSynthesis.speak(utterance);
    },
    [audioOverrideKey, customAudioOverrides, isMuted, secondaryLanguage],
  );

  useEffect(() => {
    if (autoSpeak && currentWord) {
      void speak(currentWord);
    }
  }, [autoSpeak, currentWord, speak]);

  useEffect(() => {
    if (!currentWord) {
      return;
    }
    const key = audioOverrideKey(currentWord.id, secondaryLanguage);
    if (customAudioOverrides[key]) {
      return;
    }
    const query = new URLSearchParams({
      wordId: currentWord.id,
      language: secondaryLanguage,
    });
    void fetch(`/api/v2/assets/audio/resolve?${query.toString()}`)
      .then(async (response) => {
        if (!response.ok) {
          return null;
        }
        return (await response.json()) as { source?: string; url?: string | null };
      })
      .then((resolved) => {
        if (resolved?.source === "custom" && resolved.url) {
          setCustomAudioOverrides((previous) => ({
            ...previous,
            [key]: resolved.url!,
          }));
        }
      })
      .catch(() => null);
  }, [audioOverrideKey, currentWord, customAudioOverrides, secondaryLanguage]);

  const startRecording = useCallback(async () => {
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      const chunks: BlobPart[] = [];

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunks.push(event.data);
        }
      };

      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: recorder.mimeType || "audio/webm" });
        setRecordedAudioBlob(blob);
        setRecordedAudioPreviewURL((previous) => {
          if (previous) {
            URL.revokeObjectURL(previous);
          }
          return URL.createObjectURL(blob);
        });
        stream.getTracks().forEach((track) => track.stop());
        setMediaRecorder(null);
      };

      recorder.start();
      setMediaRecorder(recorder);
      setRecordedAudioBlob(null);
      setRecordedAudioPreviewURL((previous) => {
        if (previous) {
          URL.revokeObjectURL(previous);
        }
        return null;
      });
      setIsRecording(true);
    } catch {
      setError("Microphone permission is required to record custom audio.");
    }
  }, []);

  const stopRecording = useCallback(() => {
    if (!mediaRecorder || mediaRecorder.state !== "recording") {
      return;
    }
    mediaRecorder.stop();
    setIsRecording(false);
  }, [mediaRecorder]);

  const uploadRecording = useCallback(async () => {
    if (!currentWord || !recordedAudioBlob) {
      return;
    }
    setError(null);
    setIsUploadingRecording(true);
    try {
      const formData = new FormData();
      const extension = recordedAudioBlob.type.includes("mp4") ? "m4a" : "webm";
      formData.append("file", recordedAudioBlob, `${currentWord.id}.${extension}`);
      formData.append("wordId", currentWord.id);
      formData.append("language", secondaryLanguage);

      const response = await fetch("/api/v2/assets/audio/upload", {
        method: "POST",
        body: formData,
      });
      if (!response.ok) {
        throw new Error(`Audio upload failed (${response.status})`);
      }
      const payload = (await response.json()) as { url?: string };
      if (payload.url) {
        const key = audioOverrideKey(currentWord.id, secondaryLanguage);
        setCustomAudioOverrides((previous) => ({
          ...previous,
          [key]: payload.url!,
        }));
      }
      setRecordedAudioBlob(null);
      setRecordedAudioPreviewURL((previous) => {
        if (previous) {
          URL.revokeObjectURL(previous);
        }
        return null;
      });
    } catch (uploadError) {
      setError(uploadError instanceof Error ? uploadError.message : "Failed to upload recording");
    } finally {
      setIsUploadingRecording(false);
    }
  }, [audioOverrideKey, currentWord, recordedAudioBlob, secondaryLanguage]);

  const clearCustomAudioOverride = useCallback(async () => {
    if (!currentWord) {
      return;
    }
    setError(null);
    try {
      const params = new URLSearchParams({
        wordId: currentWord.id,
        language: secondaryLanguage,
      });
      await fetch(`/api/v2/assets/audio/upload?${params.toString()}`, {
        method: "DELETE",
      });
      const key = audioOverrideKey(currentWord.id, secondaryLanguage);
      setCustomAudioOverrides((previous) => {
        const next = { ...previous };
        delete next[key];
        return next;
      });
    } catch {
      setError("Failed to clear custom audio override.");
    }
  }, [audioOverrideKey, currentWord, secondaryLanguage]);

  useEffect(() => {
    return () => {
      if (recordedAudioPreviewURL) {
        URL.revokeObjectURL(recordedAudioPreviewURL);
      }
    };
  }, [recordedAudioPreviewURL]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.tagName === "INPUT" || target?.tagName === "TEXTAREA" || event.metaKey || event.ctrlKey) {
        return;
      }
      advanceWord();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [advanceWord]);

  const setOptions = useMemo(
    () => [{ id: "all", name: "All sets", wordIDs: [] as string[] }, ...sets],
    [sets],
  );

  const featuredSuggestions = useMemo(() => {
    const normalized = featuredQuery.trim().toLowerCase();
    if (!normalized) {
      return [];
    }
    return words
      .filter((word) => {
        if (word.spelling.toLowerCase().includes(normalized)) {
          return true;
        }
        return Object.values(word.translations).some((value) => value.toLowerCase().includes(normalized));
      })
      .slice(0, 8);
  }, [featuredQuery, words]);

  const addFeaturedWord = useCallback((wordId: string) => {
    setFeaturedWordIDs((previous) => (previous.includes(wordId) ? previous : [...previous, wordId]));
  }, []);

  const removeFeaturedWord = useCallback((wordId: string) => {
    setFeaturedWordIDs((previous) => previous.filter((id) => id !== wordId));
    setFeaturedCustomWords((previous) => previous.filter((word) => word.id !== wordId));
  }, []);

  const featuredWords = useMemo(
    () => words.filter((word) => featuredWordIDs.includes(word.id)),
    [featuredWordIDs, words],
  );

  const addCustomFeaturedWord = useCallback(() => {
    const spelling = featuredQuery.trim();
    const translation = featuredTranslation.trim();
    if (!spelling || !translation) {
      return;
    }
    const id = `custom|${spelling.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`;
    const customWord: WordV2 = {
      id,
      spelling,
      meaningKey: null,
      translations: { [secondaryLanguage]: translation },
      primaryText: spelling,
      secondaryText: translation,
      setIDs: [],
    };
    setFeaturedCustomWords((previous) => {
      const next = previous.filter((word) => word.id !== id);
      next.push(customWord);
      return next;
    });
    setFeaturedWordIDs((previous) => (previous.includes(id) ? previous : [...previous, id]));
    setFeaturedQuery("");
    setFeaturedTranslation("");
  }, [featuredQuery, featuredTranslation, secondaryLanguage]);

  return (
    <main className="min-h-screen bg-[radial-gradient(circle_at_10%_20%,#fde68a_0%,#fdba74_35%,#fb7185_100%)] p-4 text-slate-900 sm:p-8">
      <div className="mx-auto flex w-full max-w-5xl flex-col gap-5">
        <Card className="border-slate-900/20 bg-white/80 shadow-xl backdrop-blur">
          <CardHeader className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div className="space-y-2">
              <CardTitle className="font-[Verdana] text-2xl tracking-tight sm:text-3xl">
                Baby Keyboard Web
              </CardTitle>
              <p className="text-sm text-slate-700">
                Press any key to trigger next word. Click card or Next button for touch mode.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <Select value={selectedSetID} onValueChange={setSelectedSetID}>
                <SelectTrigger className="w-[150px] bg-white">
                  <SelectValue placeholder="Set" />
                </SelectTrigger>
                <SelectContent>
                  {setOptions.map((set) => (
                    <SelectItem key={set.id} value={set.id}>
                      {set.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Select value={primaryLanguage} onValueChange={(value) => setPrimaryLanguage(value as SupportedLanguage)}>
                <SelectTrigger className="w-[130px] bg-white">
                  <SelectValue placeholder="Primary" />
                </SelectTrigger>
                <SelectContent>
                  {languageOptions.map((lang) => (
                    <SelectItem key={lang.value} value={lang.value}>
                      {lang.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Select
                value={secondaryLanguage}
                onValueChange={(value) => setSecondaryLanguage(value as SupportedLanguage)}
              >
                <SelectTrigger className="w-[130px] bg-white">
                  <SelectValue placeholder="Secondary" />
                </SelectTrigger>
                <SelectContent>
                  {languageOptions.map((lang) => (
                    <SelectItem key={lang.value} value={lang.value}>
                      {lang.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </CardHeader>
        </Card>

        <Card className="border-slate-900/20 bg-white/80 shadow-xl backdrop-blur">
          <CardHeader className="space-y-2">
            <CardTitle className="font-[Verdana] text-lg">Featured Words</CardTitle>
            <p className="text-xs text-slate-600">
              Featured words are always included in the learning rotation. Keep a weekly batch here.
            </p>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="grid gap-2 sm:grid-cols-3">
              <Input
                value={featuredQuery}
                onChange={(event) => setFeaturedQuery(event.target.value)}
                placeholder="Search word or type new"
              />
              <Input
                value={featuredTranslation}
                onChange={(event) => setFeaturedTranslation(event.target.value)}
                placeholder="Translation for new word"
              />
              <Button
                variant="outline"
                onClick={addCustomFeaturedWord}
                disabled={!featuredQuery.trim() || !featuredTranslation.trim()}
              >
                Add New Word
              </Button>
            </div>

            {featuredSuggestions.length > 0 ? (
              <div className="grid gap-2 sm:grid-cols-2">
                {featuredSuggestions.map((word) => (
                  <div key={word.id} className="flex items-center justify-between rounded-md border bg-white px-3 py-2">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium">{word.spelling}</p>
                      <p className="truncate text-xs text-slate-600">{resolveWordText(word, secondaryLanguage)}</p>
                    </div>
                    <Button variant="ghost" size="sm" onClick={() => addFeaturedWord(word.id)}>
                      Add
                    </Button>
                  </div>
                ))}
              </div>
            ) : null}

            <div className="flex flex-wrap gap-2">
              {featuredWords.length === 0 ? (
                <p className="text-xs text-slate-600">No featured words selected yet.</p>
              ) : (
                featuredWords.map((word) => (
                  <button
                    key={word.id}
                    type="button"
                    onClick={() => removeFeaturedWord(word.id)}
                    className="rounded-full border bg-white px-3 py-1 text-xs"
                  >
                    {word.spelling} · {resolveWordText(word, secondaryLanguage)} ×
                  </button>
                ))
              )}
            </div>
          </CardContent>
        </Card>

        <Card
          className="border-slate-900/25 bg-white/85 pb-4 shadow-2xl backdrop-blur"
          onClick={advanceWord}
          role="button"
          tabIndex={0}
          onKeyDown={(event) => {
            if (event.key === "Enter" || event.key === " ") {
              advanceWord();
            }
          }}
        >
          <CardContent className="flex flex-col gap-5">
            {isLoading ? (
              <div className="flex h-[420px] items-center justify-center text-2xl font-semibold">Loading words...</div>
            ) : null}
            {!isLoading && error ? (
              <div className="rounded-lg border border-red-300 bg-red-50 p-4 text-red-700">{error}</div>
            ) : null}
            {!isLoading && !error && !currentWord ? (
              <div className="flex h-[420px] items-center justify-center text-2xl font-semibold">
                No words found for this set.
              </div>
            ) : null}
            {!isLoading && !error && currentWord ? (
              <>
                <div className="relative overflow-hidden rounded-2xl border border-slate-900/15 bg-white">
                  {currentImage ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={currentImage}
                      alt={currentWord.spelling}
                      className="h-[300px] w-full object-cover sm:h-[380px]"
                    />
                  ) : (
                    <div className="flex h-[300px] w-full items-center justify-center bg-gradient-to-br from-slate-100 to-slate-200 sm:h-[380px]">
                      <ImageIcon className="size-14 text-slate-500" />
                    </div>
                  )}
                </div>

                <div className="space-y-2 text-center">
                  <p className="font-[Verdana] text-4xl font-bold tracking-wide sm:text-6xl">
                    {resolveWordText(currentWord, primaryLanguage)}
                  </p>
                  <p className="text-2xl text-slate-700 sm:text-3xl">
                    {resolveWordText(currentWord, secondaryLanguage)}
                  </p>
                </div>

                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5" onClick={(event) => event.stopPropagation()}>
                  <Button className="h-12 text-base font-semibold" onClick={advanceWord}>
                    Next
                  </Button>
                  <Button
                    variant="outline"
                    className="h-12 text-base"
                    onClick={() => currentWord && void speak(currentWord)}
                  >
                    {isMuted ? <VolumeX className="size-4" /> : <Volume2 className="size-4" />}
                    Speak
                  </Button>
                  <Button
                    variant="outline"
                    className="h-12 text-base"
                    onClick={() => setIsMuted((value) => !value)}
                  >
                    {isMuted ? "Unmute" : "Mute"}
                  </Button>
                  <Button
                    variant="outline"
                    className="h-12 text-base"
                    onClick={() => setAutoSpeak((value) => !value)}
                  >
                    {autoSpeak ? "Auto Speak On" : "Auto Speak Off"}
                  </Button>
                  <Button
                    variant="secondary"
                    className="h-12 text-base"
                    onClick={triggerImageGeneration}
                    disabled={isGeneratingImage}
                  >
                    {isGeneratingImage ? (
                      <RefreshCw className="size-4 animate-spin" />
                    ) : (
                      <WandSparkles className="size-4" />
                    )}
                    Generate Image
                  </Button>
                </div>

                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" onClick={(event) => event.stopPropagation()}>
                  <Select value={imageStyle} onValueChange={(value) => setImageStyle(value as ImageStyle)}>
                    <SelectTrigger className="w-full bg-white">
                      <SelectValue placeholder="Image style" />
                    </SelectTrigger>
                    <SelectContent>
                      {imageStyleOptions.map((style) => (
                        <SelectItem key={style.value} value={style.value}>
                          {style.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <Button variant="outline" onClick={fetchWords}>
                    Reload
                  </Button>
                  <div className="flex items-center justify-center rounded-md border bg-white px-4 text-sm text-slate-600">
                    {currentIndex + 1} / {words.length}
                  </div>
                </div>

                <div className="rounded-lg border border-slate-200 bg-white p-4" onClick={(event) => event.stopPropagation()}>
                  <div className="mb-3 flex items-center justify-between">
                    <p className="text-sm font-semibold text-slate-700">
                      Audio: pre-synth + custom override
                    </p>
                    <p className="text-xs text-slate-500">
                      {currentCustomAudioURL ? "Custom override active" : "Using pre-synth or TTS"}
                    </p>
                  </div>

                  <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
                    {!isRecording ? (
                      <Button variant="outline" onClick={startRecording}>
                        <Mic className="size-4" />
                        Record
                      </Button>
                    ) : (
                      <Button variant="destructive" onClick={stopRecording}>
                        <Square className="size-4" />
                        Stop
                      </Button>
                    )}

                    <Button
                      variant="secondary"
                      onClick={uploadRecording}
                      disabled={!recordedAudioBlob || isUploadingRecording}
                    >
                      <Upload className="size-4" />
                      {isUploadingRecording ? "Uploading..." : "Save Override"}
                    </Button>

                    <Button
                      variant="outline"
                      onClick={clearCustomAudioOverride}
                      disabled={!currentCustomAudioURL}
                    >
                      <Trash2 className="size-4" />
                      Clear Override
                    </Button>

                    <Button
                      variant="outline"
                      onClick={() => currentAudioURL && void new Audio(currentAudioURL).play()}
                      disabled={!currentAudioURL}
                    >
                      <Volume2 className="size-4" />
                      Play File
                    </Button>

                    <div className="flex items-center justify-center rounded-md border px-3 text-xs text-slate-500">
                      {currentAudioURL ? "audio ready" : "no file audio"}
                    </div>
                  </div>

                  {recordedAudioPreviewURL ? (
                    <audio className="mt-3 w-full" controls src={recordedAudioPreviewURL} />
                  ) : null}
                </div>
              </>
            ) : null}
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
