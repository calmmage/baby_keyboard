"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { Volume2, VolumeX, Settings, LogIn, LogOut, Mic, Upload, RefreshCw, Palette, Check, Star, X, Moon, Sun, ChevronRight, ChevronLeft } from 'lucide-react';
import Link from "next/link";
import { useRouter } from 'next/navigation';
import { useTheme } from "next-themes";

type Word = {
  id: string;
  word_en: string | null;
  word_ru: string | null;
  word_de: string | null;
  generated_image_url: string | null;
  image_url?: string | null;
  image_style?: string;
  topic_id?: string; // Added topic_id
  is_known?: boolean; // Add is_known type
};

type CustomAudio = {
  id: string;
  word_id: string;
  language: string;
  audio_url: string;
};

type CustomImage = {
  id: string;
  word_id: string;
  image_url: string;
};

type LanguageCode = 'en' | 'ru' | 'de' | 'none'; // Added 'none'

const DEFAULT_PRIMARY = 'en';
const DEFAULT_SECONDARY = 'ru';

export default function FlashcardPlayer() {
  const router = useRouter();
  const { theme, setTheme } = useTheme();
  const [currentWord, setCurrentWord] = useState<Word | null>(null);
  const [words, setWords] = useState<Word[]>([]);
  const [knownWords, setKnownWords] = useState<Word[]>([]); // Add knownWords state
  const [customAudios, setCustomAudios] = useState<CustomAudio[]>([]);
  const [customImages, setCustomImages] = useState<CustomImage[]>([]);
  const [primaryLang, setPrimaryLang] = useState<LanguageCode>(DEFAULT_PRIMARY);
  const [secondaryLang, setSecondaryLang] = useState<LanguageCode>(DEFAULT_SECONDARY);
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [isGeneratingImage, setIsGeneratingImage] = useState(false);
  const [showRecordModal, setShowRecordModal] = useState(false);
  const [recordingLanguage, setRecordingLanguage] = useState<"primary" | "secondary" | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
  const [audioChunks, setAudioChunks] = useState<Blob[]>([]);
  const [imageStyle, setImageStyle] = useState<string>("simple");
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [applyToAllStyles, setApplyToAllStyles] = useState(false);
  const [activeWordLimit, setActiveWordLimit] = useState(10);
  const [enabledTopics, setEnabledTopics] = useState<string[]>([]);
  const [reviewProbability, setReviewProbability] = useState(0.2); // Add review settings
  const [enableReview, setEnableReview] = useState(true); // Add review settings
  const [availableTopics, setAvailableTopics] = useState<{id: string, name: string}[]>([]);
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const [isMuted, setIsMuted] = useState(false); // Add mute state

  useEffect(() => {
    const fetchData = async () => {
      try {
        const topicsRes = await fetch('/api/topics');
        if (topicsRes.ok) {
          const topicsData = await topicsRes.json();
          setAvailableTopics(topicsData.topics || []);
        }

        const authRes = await fetch('/api/auth/check');
        let isAuth = false;
        if (authRes.ok) {
          const authData = await authRes.json();
          setIsAuthenticated(authData.authenticated);
          isAuth = authData.authenticated;
        }

        if (isAuth) {
          const settingsRes = await fetch('/api/user-settings');
          if (settingsRes.ok) {
            const settingsData = await settingsRes.json();
            if (settingsData.primary_language) {
              setPrimaryLang(settingsData.primary_language);
            }
            setSecondaryLang(settingsData.secondary_language || 'none');
            
            if (settingsData.active_word_limit) {
              setActiveWordLimit(settingsData.active_word_limit);
            }
            if (settingsData.enabled_topics) {
              setEnabledTopics(settingsData.enabled_topics);
            }
            if (settingsData.review_probability !== undefined) setReviewProbability(settingsData.review_probability);
            if (settingsData.enable_review !== undefined) setEnableReview(settingsData.enable_review);
          }
        }

        const queryParams = new URLSearchParams({
          style: imageStyle,
          limit: activeWordLimit.toString(),
          topics: enabledTopics.join(',')
        });
        
        const wordsRes = await fetch(`/api/words?${queryParams.toString()}`);
        const wordsData = await wordsRes.json();
        setWords(wordsData.words || []);
        setKnownWords(wordsData.knownWords || []); // Set known words

        const audioRes = await fetch('/api/custom-audio');
        if (audioRes.ok) {
          const audioData = await audioRes.json();
          setCustomAudios(audioData.audios || []);
        }

        const imageRes = await fetch('/api/custom-images');
        if (imageRes.ok) {
          const imageData = await imageRes.json();
          setCustomImages(imageData.images || []);
        }
      } catch (error) {
        console.error('Error fetching data:', error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []); // Fetch only once, handle other dependencies separately

  useEffect(() => {
    const fetchWords = async () => {
      const queryParams = new URLSearchParams({
        style: imageStyle,
        limit: activeWordLimit.toString(),
        topics: enabledTopics.join(',')
      });
      
      const wordsRes = await fetch(`/api/words?${queryParams.toString()}`);
      const wordsData = await wordsRes.json();
      setWords(wordsData.words || []);
      setKnownWords(wordsData.knownWords || []); // Set known words
    };
    
    // Debounce slightly to avoid rapid firing on slider change
    const timeoutId = setTimeout(fetchWords, 500);
    return () => clearTimeout(timeoutId);
  }, [activeWordLimit, enabledTopics, imageStyle]);

  useEffect(() => {
    if (currentWord && !currentWord.image_url && !isGeneratingImage && isAuthenticated) {
      generateImageForWord(currentWord.id);
    }
  }, [currentWord, imageStyle, isAuthenticated]);

  const playAudio = useCallback((word: Word, lang: LanguageCode) => {
    if (isMuted) return Promise.resolve(); // Check mute state

    const customAudio = customAudios.find(
      (a) => a.word_id === word.id && a.language === lang
    );

    if (customAudio) {
      const audio = new Audio(customAudio.audio_url);
      audio.play();
      return new Promise((resolve) => {
        audio.onended = resolve;
      });
    } else {
      const text = word[`word_${lang}` as keyof Word] as string;
      if (text && 'speechSynthesis' in window) {
        return new Promise((resolve) => {
          const utterance = new SpeechSynthesisUtterance(text);
          utterance.lang = lang === 'en' ? 'en-US' : lang === 'ru' ? 'ru-RU' : lang === 'de' ? 'de-DE' : '';
          utterance.rate = 0.8;
          utterance.onend = () => resolve(null);
          window.speechSynthesis.speak(utterance);
        });
      }
    }
    return Promise.resolve();
  }, [customAudios, isMuted]);

  const generateImageForWord = async (wordId: string) => {
    if (isGeneratingImage) return;
    setIsGeneratingImage(true);
    try {
      const word = words.find(w => w.id === wordId);
      if (!word) return;

      const wordText = word[`word_${primaryLang}` as keyof Word] || word.word_en;

      const response = await fetch("/api/generate-image", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          word_id: wordId, 
          word_text: wordText,
          style: imageStyle 
        }),
      });
      
      if (response.ok) {
        const data = await response.json();
        const newImageUrl = data.imageUrl;
        
        setCurrentWord(prev => prev ? { ...prev, image_url: newImageUrl } : null);
        setWords(prev => prev.map(w => w.id === wordId ? { ...w, image_url: newImageUrl } : w));
      }
    } catch (error) {
      console.error("Failed to generate image:", error);
    } finally {
      setIsGeneratingImage(false);
    }
  };

  const startRecording = async (languageType: "primary" | "secondary") => {
    if (!isAuthenticated) {
      router.push('/auth/login');
      return;
    }
    setRecordingLanguage(languageType);
    setShowRecordModal(true);
    setAudioChunks([]);
    
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      
      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) setAudioChunks(prev => [...prev, e.data]);
      };
      
      recorder.start();
      setMediaRecorder(recorder);
      setIsRecording(true);
    } catch (err) {
      console.error("Error accessing microphone:", err);
    }
  };

  const stopRecording = () => {
    if (mediaRecorder && isRecording) {
      mediaRecorder.stop();
      setIsRecording(false);
      mediaRecorder.stream.getTracks().forEach(track => track.stop());
    }
  };

  const saveRecording = async () => {
    if (!currentWord || !recordingLanguage || audioChunks.length === 0) return;

    const audioBlob = new Blob(audioChunks, { type: "audio/webm" });
    const reader = new FileReader();
    
    reader.onloadend = async () => {
      const base64Audio = reader.result as string;
      const languageCode = recordingLanguage === "primary" ? primaryLang : secondaryLang;
      
      try {
        const response = await fetch("/api/custom-audio", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            wordId: currentWord.id,
            language: languageCode,
            audioUrl: base64Audio
          }),
        });

        if (response.ok) {
          const newAudio: CustomAudio = {
            id: crypto.randomUUID(),
            word_id: currentWord.id,
            language: languageCode,
            audio_url: base64Audio
          };
          
          setCustomAudios(prev => [
            ...prev.filter(a => !(a.word_id === currentWord.id && a.language === languageCode)),
            newAudio
          ]);
          
          setShowRecordModal(false);
        }
      } catch (error) {
        console.error("Failed to save recording:", error);
      }
    };
    
    reader.readAsDataURL(audioBlob);
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!isAuthenticated) {
      router.push('/auth/login');
      return;
    }
    const file = e.target.files?.[0];
    if (!file || !currentWord) return;

    try {
      const formData = new FormData();
      formData.append('image', file);
      formData.append('word_id', currentWord.id);
      formData.append('style', imageStyle);
      formData.append('apply_to_all_styles', applyToAllStyles ? 'true' : 'false');

      const response = await fetch("/api/custom-images", {
        method: "POST",
        body: formData,
      });

      if (response.ok) {
        const data = await response.json();
        const newImageUrl = data.imageUrl;
        
        setCurrentWord(prev => prev ? { ...prev, image_url: newImageUrl } : null);
        setWords(prev => prev.map(w => w.id === currentWord.id ? { ...w, image_url: newImageUrl } : w));
        
        const imageRes = await fetch('/api/custom-images');
        if (imageRes.ok) {
          const imageData = await imageRes.json();
          setCustomImages(imageData.images || []);
        }
        setShowUploadModal(false);
      } else {
        const errorData = await response.json();
        console.error("Failed to upload image:", errorData);
        alert(`Failed to upload image: ${errorData.error || 'Unknown error'}`);
      }
    } catch (error) {
      console.error("Failed to upload image:", error);
      alert("Failed to upload image. Please try again.");
    }
  };

  const showRandomWord = useCallback(async () => {
    if (words.length === 0 && knownWords.length === 0) return; // Check both pools
    
    let word: Word;

    if (enableReview && knownWords.length > 0 && Math.random() < reviewProbability) {
      // Pick from known words
      const randomIndex = Math.floor(Math.random() * knownWords.length);
      word = knownWords[randomIndex];
    } else if (words.length > 0) {
      // Pick from active pool
      const randomIndex = Math.floor(Math.random() * words.length);
      word = words[randomIndex];
    } else if (knownWords.length > 0) {
      // Fallback if active pool is empty but we have known words
      const randomIndex = Math.floor(Math.random() * knownWords.length);
      word = knownWords[randomIndex];
    } else {
      return;
    }

    setCurrentWord(word);

    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }

    await playAudio(word, primaryLang);
    
    await new Promise(resolve => setTimeout(resolve, 300));
    if (secondaryLang !== 'none') {
      await playAudio(word, secondaryLang);
    }
  }, [words, knownWords, primaryLang, secondaryLang, playAudio, enableReview, reviewProbability]);

  useEffect(() => {
    const handleInteraction = (e: KeyboardEvent | MouseEvent) => {
      // Disable interaction if generating image
      if (isGeneratingImage) return;
      
      e.preventDefault();
      showRandomWord();
    };

    window.addEventListener('keydown', handleInteraction as EventListener);
    window.addEventListener('click', handleInteraction as EventListener);

    return () => {
      window.removeEventListener('keydown', handleInteraction as EventListener);
      window.removeEventListener('click', handleInteraction as EventListener);
    };
  }, [showRandomWord, isGeneratingImage]); // Add isGeneratingImage dependency

  const markAsKnown = async (wordId: string) => {
    if (!isAuthenticated) return;
    
    const newIsKnown = !currentWord?.is_known;
    setCurrentWord(prev => prev ? { ...prev, is_known: newIsKnown } : null);
    setWords(prev => prev.map(w => w.id === wordId ? { ...w, is_known: newIsKnown } : w));
    setKnownWords(prev => prev.map(w => w.id === wordId ? { ...w, is_known: newIsKnown } : w));

    try {
      await fetch('/api/word-progress', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ word_id: wordId, is_known: newIsKnown }),
      });
      
      // Background refresh to update pool logic
      const queryParams = new URLSearchParams({
        style: imageStyle,
        limit: activeWordLimit.toString(),
        topics: enabledTopics.join(',')
      });
      const wordsRes = await fetch(`/api/words?${queryParams.toString()}`);
      const wordsData = await wordsRes.json();
      setWords(wordsData.words || []);
      setKnownWords(wordsData.knownWords || []); // Set known words
      
    } catch (error) {
      console.error('Error marking word as known:', error);
      // Revert on error
      setCurrentWord(prev => prev ? { ...prev, is_known: !newIsKnown } : null);
    }
  };

  const saveSettings = async (primary: LanguageCode, secondary: LanguageCode, limit: number, topics: string[], revProb: number, revEnabled: boolean) => { // Update signature
    try {
      setPrimaryLang(primary);
      setSecondaryLang(secondary);
      setActiveWordLimit(limit);
      setEnabledTopics(topics);
      setReviewProbability(revProb);
      setEnableReview(revEnabled);
      
      if (isAuthenticated) {
        await fetch('/api/user-settings', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            primary_language: primary,
            secondary_language: secondary === 'none' ? null : secondary,
            active_word_limit: limit,
            enabled_topics: topics,
            review_probability: revProb,
            enable_review: revEnabled
          }),
        });
      }
      
      // Words will be refetched by the useEffect
      
    } catch (error) {
      console.error('Error saving settings:', error);
    }
  };

  const getWordImageUrl = useCallback((word: Word) => {
    return word.image_url || word.generated_image_url;
  }, []);

  const handleAuthAction = (action: () => void) => {
    if (!isAuthenticated) {
      router.push('/auth/login');
      return;
    }
    action();
  };

  const renderActionButtons = () => {
    return (
      <div className="flex gap-3 mt-6 justify-center z-20 relative" onClick={(e) => e.stopPropagation()}>
        <Button 
          variant="outline" 
          size="icon"
          onClick={() => handleAuthAction(() => startRecording("primary"))}
          title={`Record ${primaryLang.toUpperCase()}`}
          className="rounded-full w-10 h-10 bg-white/80 hover:bg-white dark:bg-slate-800/80 dark:hover:bg-slate-800 shadow-sm"
        >
          <Mic className="h-4 w-4 text-purple-600 dark:text-purple-400" />
        </Button>
        
        <Button 
          variant="outline" 
          size="icon"
          onClick={() => setShowUploadModal(true)}
          title="Upload Image"
          className="rounded-full w-10 h-10 bg-white/80 hover:bg-white dark:bg-slate-800/80 dark:hover:bg-slate-800 shadow-sm"
        >
          <Upload className="h-4 w-4 text-blue-600 dark:text-blue-400" />
        </Button>

        <Button 
          variant="outline" 
          size="icon"
          onClick={() => handleAuthAction(() => currentWord && generateImageForWord(currentWord.id))}
          disabled={isGeneratingImage}
          title="Regenerate Image"
          className="rounded-full w-10 h-10 bg-white/80 hover:bg-white dark:bg-slate-800/80 dark:hover:bg-slate-800 shadow-sm"
        >
          <RefreshCw className={`h-4 w-4 text-green-600 dark:text-green-400 ${isGeneratingImage ? 'animate-spin' : ''}`} />
        </Button>

        {isAuthenticated && (
          <Button 
            variant="outline" 
            size="icon"
            onClick={() => currentWord && markAsKnown(currentWord.id)}
            title={currentWord?.is_known ? "Mark as unknown" : "I know this word!"}
            className={`rounded-full w-10 h-10 shadow-sm transition-colors ${
              currentWord?.is_known 
                ? "bg-yellow-100 border-yellow-400 hover:bg-yellow-200 dark:bg-yellow-900/30 dark:border-yellow-600" 
                : "bg-white/80 hover:bg-white dark:bg-slate-800/80 dark:hover:bg-slate-800"
            }`}
          >
            <Star className={`h-4 w-4 ${
              currentWord?.is_known 
                ? "text-yellow-500 fill-yellow-500" 
                : "text-slate-400"
            }`} />
          </Button>
        )}
      </div>
    );
  };

  const secondaryText = secondaryLang === 'none' 
    ? null 
    : currentWord?.[`word_${secondaryLang}` as keyof Word] as string;

  const SettingsPanel = () => (
    <div 
      className={`
        bg-white/90 dark:bg-slate-900/90 backdrop-blur-sm border-l border-slate-200 dark:border-slate-800 
        flex flex-col h-screen shadow-xl z-30 transition-all duration-300 ease-in-out
        ${isSidebarOpen ? 'w-80 translate-x-0' : 'w-0 translate-x-full opacity-0'}
      `}
    >
      <div className="p-6 flex flex-col gap-6 h-full overflow-y-auto">
        <div className="space-y-1 flex justify-between items-start">
          <div>
            <h2 className="text-xl font-bold text-slate-800 dark:text-slate-100">Settings</h2>
            <p className="text-xs text-slate-500 dark:text-slate-400">Customize your learning</p>
          </div>
          <Button variant="ghost" size="icon" onClick={() => setIsSidebarOpen(false)} className="lg:hidden">
            <X className="h-4 w-4" />
          </Button>
        </div>

        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <Label>Theme</Label>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
              className="rounded-full"
            >
              {theme === "dark" ? (
                <Sun className="h-4 w-4 mr-2" />
              ) : (
                <Moon className="h-4 w-4 mr-2" />
              )}
              {theme === "dark" ? "Light" : "Dark"}
            </Button>
          </div>

          <div className="space-y-2">
            <Label>Image Style</Label>
            <Select value={imageStyle} onValueChange={setImageStyle}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="simple">Simple</SelectItem>
                <SelectItem value="crayon">Crayon</SelectItem>
                <SelectItem value="doodle">Doodle</SelectItem>
                <SelectItem value="pencil">Pencil</SelectItem>
                <SelectItem value="watercolor">Watercolor</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>Primary Language</Label>
            <Select
              value={primaryLang}
              onValueChange={(val: LanguageCode) => saveSettings(val, secondaryLang, activeWordLimit, enabledTopics, reviewProbability, enableReview)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="en">English 🇺🇸</SelectItem>
                <SelectItem value="ru">Russian 🇷🇺</SelectItem>
                <SelectItem value="de">German 🇩🇪</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>Secondary Language</Label>
            <Select
              value={secondaryLang}
              onValueChange={(val: LanguageCode) => saveSettings(primaryLang, val, activeWordLimit, enabledTopics, reviewProbability, enableReview)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">None (Hidden)</SelectItem>
                <SelectItem value="en">English 🇺🇸</SelectItem>
                <SelectItem value="ru">Russian 🇷🇺</SelectItem>
                <SelectItem value="de">German 🇩🇪</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <div className="flex justify-between items-center">
              <Label>Pool Size</Label>
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  min="1"
                  max="100"
                  value={activeWordLimit}
                  onChange={(e) => {
                    const val = parseInt(e.target.value);
                    if (!isNaN(val) && val > 0) {
                      saveSettings(val, secondaryLang, activeWordLimit, enabledTopics, reviewProbability, enableReview);
                    }
                  }}
                  className="w-12 h-6 text-sm text-center rounded border border-slate-200 dark:border-slate-700 bg-transparent"
                />
              </div>
            </div>
            <input 
              type="range" 
              min="1" 
              max="50" 
              step="1"
              value={activeWordLimit}
              onChange={(e) => saveSettings(primaryLang, secondaryLang, parseInt(e.target.value), enabledTopics, reviewProbability, enableReview)}
              className="w-full accent-purple-600"
            />
            <p className="text-xs text-muted-foreground">
              Words in active rotation
            </p>
          </div>

          {isAuthenticated && (
            <div className="space-y-4 border-t border-slate-200 dark:border-slate-700 pt-4">
              <div className="flex items-center justify-between">
                <Label>Review Known Words</Label>
                <input 
                  type="checkbox"
                  checked={enableReview}
                  onChange={(e) => saveSettings(primaryLang, secondaryLang, activeWordLimit, enabledTopics, reviewProbability, e.target.checked)}
                  className="w-5 h-5 rounded border-gray-300 text-purple-600 focus:ring-purple-500"
                />
              </div>
              
              {enableReview && (
                <div className="space-y-2">
                  <div className="flex justify-between items-center">
                    <Label className="text-xs">Frequency</Label>
                    <span className="text-xs text-muted-foreground">{Math.round(reviewProbability * 100)}%</span>
                  </div>
                  <input 
                    type="range" 
                    min="0.05" 
                    max="0.5" 
                    step="0.05"
                    value={reviewProbability}
                    onChange={(e) => saveSettings(primaryLang, secondaryLang, activeWordLimit, enabledTopics, parseFloat(e.target.value), enableReview)}
                    className="w-full accent-purple-600"
                  />
                </div>
              )}
            </div>
          )}

          <div className="space-y-2">
            <Label>Topics</Label>
            <div className="grid grid-cols-1 gap-2 max-h-32 overflow-y-auto p-2 bg-slate-50 dark:bg-slate-800 rounded-md border">
              {availableTopics.map(topic => (
                <label key={topic.id} className="flex items-center gap-2 text-sm cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700 p-1 rounded">
                  <input 
                    type="checkbox"
                    checked={enabledTopics.length === 0 || enabledTopics.includes(topic.id)}
                    onChange={(e) => {
                      const newTopics = e.target.checked
                        ? [...enabledTopics, topic.id]
                        : enabledTopics.filter(id => id !== topic.id);
                      saveSettings(primaryLang, secondaryLang, activeWordLimit, newTopics, reviewProbability, enableReview);
                    }}
                    className="rounded border-gray-300 text-purple-600 focus:ring-purple-500"
                  />
                  {topic.name}
                </label>
              ))}
            </div>
          </div>

          {isAuthenticated && (
            <>
              <div className="space-y-2">
                <Label>Current Pool ({words.length})</Label>
                <div className="bg-slate-50 dark:bg-slate-800 rounded-md border p-2 max-h-48 overflow-y-auto space-y-1">
                  {words.map((word, idx) => (
                    <div key={word.id} className="text-sm flex items-center gap-2 px-2 py-1 hover:bg-slate-100 dark:hover:bg-slate-700 rounded">
                      <span className="text-slate-400 text-xs w-4">{idx + 1}.</span>
                      <span className="font-medium text-slate-700 dark:text-slate-300 flex-1">
                        {word[`word_${primaryLang}` as keyof Word] || word.word_en}
                      </span>
                      {word.is_known && <Star className="w-3 h-3 text-yellow-500 fill-yellow-500" />}
                    </div>
                  ))}
                </div>
              </div>

              <div className="pt-4 border-t border-slate-200 dark:border-slate-700 space-y-2">
                <Link href="/manage" className="w-full block"> {/* Update link to /manage */}
                  <Button variant="outline" className="w-full gap-2">
                    <Settings className="w-4 h-4" />
                    Manage Words
                  </Button>
                </Link>
              </div>
            </>
          )}
          
          <div className="pt-4 border-t border-slate-200 dark:border-slate-700">
            {isAuthenticated ? (
              <form action="/auth/sign-out" method="post">
                <Button variant="ghost" className="w-full gap-2 text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20">
                  <LogOut className="w-4 h-4" />
                  Sign Out
                </Button>
              </form>
            ) : (
              <Link href="/auth/login" className="w-full block">
                <Button className="w-full gap-2 bg-purple-600 hover:bg-purple-700 text-white">
                  <LogIn className="w-4 h-4" />
                  Log In
                </Button>
              </Link>
            )}
          </div>
        </div>
      </div>
    </div>
  );

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-blue-50 via-purple-50 to-pink-50 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900">
        <p className="text-2xl font-bold text-purple-600 dark:text-purple-400">Loading...</p>
      </div>
    );
  }

  if (words.length === 0 && knownWords.length === 0) {
    return (
      <div className="flex min-h-screen bg-gradient-to-br from-blue-50 via-purple-50 to-pink-50 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900">
        <div className="flex-1 flex items-center justify-center p-8">
          <Card className="p-8 max-w-md text-center bg-white dark:bg-slate-800">
            <p className="text-xl font-semibold text-purple-600 dark:text-purple-400">No words available yet.</p>
            <p className="text-muted-foreground mt-2">
              Please add some words in the admin dashboard.
            </p>
          </Card>
        </div>
        <SettingsPanel />
      </div>
    );
  }

  const primaryText = currentWord?.[`word_${primaryLang}` as keyof Word] as string;
  const imageUrl = currentWord ? getWordImageUrl(currentWord) : null;

  return (
    <div className="flex h-screen bg-gradient-to-br from-blue-50 via-purple-50 to-pink-50 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900 overflow-hidden select-none">
      <div className="flex-1 relative flex items-center justify-center p-4">
        {!isSidebarOpen && (
          <div className="absolute top-4 right-4 z-10">
            <Button 
              variant="outline" 
              size="icon" 
              onClick={() => setIsSidebarOpen(true)}
              className="bg-white/80 dark:bg-slate-800/80 backdrop-blur shadow-sm rounded-full"
            >
              <ChevronLeft className="h-5 w-5" />
            </Button>
          </div>
        )}

        {showRecordModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50" onClick={(e) => e.stopPropagation()}>
            <div className="bg-white p-6 rounded-xl max-w-sm w-full mx-4 shadow-2xl">
              <h3 className="text-xl font-bold mb-4 text-center">Record Audio</h3>
              
              {!recordingLanguage ? (
                <div className="grid grid-cols-2 gap-4">
                  <Button onClick={() => startRecording("primary")} className="h-24 text-lg flex flex-col gap-2">
                    <span>{primaryLang.toUpperCase()}</span>
                    <Mic className="h-6 w-6" />
                  </Button>
                  <Button onClick={() => startRecording("secondary")} className="h-24 text-lg flex flex-col gap-2">
                    <span>{secondaryLang.toUpperCase()}</span>
                    <Mic className="h-6 w-6" />
                  </Button>
                </div>
              ) : (
                <div className="flex flex-col items-center gap-6">
                  <div className={`w-24 h-24 rounded-full flex items-center justify-center transition-all duration-300 ${isRecording ? 'bg-red-100 animate-pulse scale-110' : 'bg-gray-100'}`}>
                    <Mic className={`h-12 w-12 ${isRecording ? 'text-red-500' : 'text-gray-400'}`} />
                  </div>
                  
                  <div className="flex gap-4 w-full">
                    {isRecording ? (
                      <Button onClick={stopRecording} variant="destructive" className="w-full h-12 text-lg">Stop</Button>
                    ) : (
                      <>
                        <Button onClick={() => startRecording(recordingLanguage)} variant="outline" className="flex-1 h-12">Retry</Button>
                        <Button onClick={saveRecording} className="flex-1 h-12 bg-green-600 hover:bg-green-700">Save</Button>
                      </>
                    )}
                  </div>
                </div>
              )}
              
              <Button 
                variant="ghost" 
                className="w-full mt-4" 
                onClick={() => {
                  setShowRecordModal(false);
                  setRecordingLanguage(null);
                  stopRecording();
                }}
              >
                Cancel
              </Button>
            </div>
          </div>
        )}

        {showUploadModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50" onClick={(e) => e.stopPropagation()}>
            <div className="bg-white p-6 rounded-xl max-w-sm w-full mx-4 shadow-2xl">
              <h3 className="text-xl font-bold mb-4 text-center">Upload Image</h3>
              <input 
                id="image-upload" 
                type="file" 
                accept="image/*" 
                className="hidden"
                onChange={handleImageUpload}
              />
              <div className="flex items-center gap-4 mb-6">
                <label htmlFor="apply-to-all" className="flex items-center gap-2 cursor-pointer">
                  <input 
                    id="apply-to-all" 
                    type="checkbox" 
                    checked={applyToAllStyles}
                    onChange={(e) => setApplyToAllStyles(e.target.checked)}
                    className="w-5 h-5 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <span className="text-gray-700 dark:text-gray-300">Use for all styles</span>
                </label>
              </div>
              <div className="flex gap-4 w-full">
                <Button onClick={() => setShowUploadModal(false)} variant="outline" className="flex-1 h-12">Cancel</Button>
                <Button onClick={() => document.getElementById('image-upload')?.click()} className="flex-1 h-12 bg-blue-600 hover:bg-blue-700">Select File</Button>
              </div>
            </div>
          </div>
        )}

        {currentWord ? (
          <div className="flex flex-col items-center w-full max-w-3xl">
            <Card className="w-full p-8 md:p-12 shadow-2xl border-8 border-white dark:border-slate-700 bg-white dark:bg-slate-800">
              <div className="flex flex-col items-center gap-6 md:gap-8">
                <div className="w-full aspect-square max-w-md rounded-3xl overflow-hidden bg-white dark:bg-slate-900 shadow-lg relative">
                  {imageUrl ? (
                    <img
                      src={imageUrl || "/placeholder.svg"}
                      alt={primaryText || 'word image'}
                      className="w-full h-full object-cover pointer-events-none"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-yellow-100 to-orange-100 dark:from-yellow-900/20 dark:to-orange-900/20">
                      {isGeneratingImage ? (
                        <div className="flex flex-col items-center gap-4">
                          <RefreshCw className="w-12 h-12 text-orange-400 animate-spin" />
                          <span className="text-orange-600 dark:text-orange-400 font-medium">Creating magic...</span>
                        </div>
                      ) : (
                        <span className="text-9xl text-orange-300 dark:text-orange-700">
                          {primaryText?.[0]?.toUpperCase() || '?'}
                        </span>
                      )}
                    </div>
                  )}
                </div>

                <div className="text-center space-y-2 md:space-y-4">
                  <h1 className="text-5xl md:text-7xl font-bold text-purple-600 dark:text-purple-400 leading-tight">
                    {primaryText || '—'}
                  </h1>
                  {secondaryText && (
                    <p className="text-3xl md:text-5xl font-semibold text-pink-500 dark:text-pink-400">
                      {secondaryText}
                    </p>
                  )}
                </div>

                <div className="flex items-center gap-2 text-blue-500 dark:text-blue-400">
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={(e) => {
                      e.stopPropagation();
                      setIsMuted(!isMuted);
                    }}
                    className="hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-full"
                  >
                    {isMuted ? <VolumeX className="w-6 h-6 md:w-8 md:h-8" /> : <Volume2 className="w-6 h-6 md:w-8 md:h-8" />}
                  </Button>
                  <span className="text-base md:text-lg font-medium">Press any key or click anywhere</span>
                </div>
                
                {renderActionButtons()}
              </div>
            </Card>
          </div>
        ) : (
          <Card className="w-full max-w-3xl p-20 shadow-2xl border-8 border-white dark:border-slate-700 bg-white dark:bg-slate-800 text-center">
            <h2 className="text-6xl font-bold text-purple-600 dark:text-purple-400 mb-6">
              Ready to Learn!
            </h2>
            <p className="text-3xl text-muted-foreground">
              Press any key or click anywhere to start
            </p>
          </Card>
        )}
      </div>

      <SettingsPanel />
      
      {isSidebarOpen && (
        <div 
          className="fixed inset-0 bg-black/20 z-20 lg:hidden"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}
    </div>
  );
}
