"use client";

import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from 'next/navigation';
import { Trash2, Plus, Settings, ChevronDown, ChevronUp } from 'lucide-react';
import type { User } from "@supabase/supabase-js";
import AudioRecorder from "./audio-recorder";
import ImageManager from "./image-manager";
import { Checkbox } from "@/components/ui/checkbox";

type Word = {
  id: string;
  word_en: string | null;
  word_ru: string | null;
  word_de: string | null;
  generated_image_url: string | null;
  image_style: string | null; // Added image_style field
  user_id: string | null;
  topic_id: string | null; // Added topic_id field
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

type UserSettings = {
  primary_language: 'en' | 'ru' | 'de';
  secondary_language: 'en' | 'ru' | 'de';
};

type Topic = {
  id: string;
  name: string;
  slug: string;
};

export default function AdminDashboard({ user }: { user: User }) {
  const router = useRouter();
  const [words, setWords] = useState<Word[]>([]);
  const [customAudios, setCustomAudios] = useState<CustomAudio[]>([]);
  const [customImages, setCustomImages] = useState<CustomImage[]>([]);
  const [settings, setSettings] = useState<UserSettings>({
    primary_language: 'en',
    secondary_language: 'ru',
  });
  const [isLoading, setIsLoading] = useState(true);
  const [expandedWordId, setExpandedWordId] = useState<string | null>(null);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [newWord, setNewWord] = useState({
    word_en: '',
    word_ru: '',
    word_de: '',
    topic_id: '', // Added topic_id
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      // Fetch words
      const wordsRes = await fetch('/api/words?mode=manage'); // Add mode=manage
      const wordsData = await wordsRes.json();
      setWords(wordsData.words || []);

      // Fetch custom audios
      const audioRes = await fetch('/api/custom-audio');
      if (audioRes.ok) {
        const audioData = await audioRes.json();
        setCustomAudios(audioData.audios || []);
      }

      // Fetch custom images
      const imageRes = await fetch('/api/custom-images');
      if (imageRes.ok) {
        const imageData = await imageRes.json();
        setCustomImages(imageData.images || []);
      }

      // Fetch settings
      const settingsRes = await fetch('/api/user-settings');
      if (settingsRes.ok) {
        const settingsData = await settingsRes.json();
        setSettings({
          primary_language: settingsData.primary_language || 'en',
          secondary_language: settingsData.secondary_language || 'ru',
        });
      }

      // Fetch topics
      const topicsRes = await fetch('/api/topics');
      if (topicsRes.ok) {
        const topicsData = await topicsRes.json();
        setTopics(topicsData.topics || []);
        // Set default topic if available
        if (topicsData.topics?.length > 0 && !newWord.topic_id) {
          setNewWord(prev => ({ ...prev, topic_id: topicsData.topics[0].id }));
        }
      }
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddWord = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const res = await fetch('/api/words', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newWord),
      });

      if (res.ok) {
        setNewWord({ word_en: '', word_ru: '', word_de: '', topic_id: '' });
        fetchData();
      }
    } catch (error) {
      console.error('Error adding word:', error);
    }
  };

  const handleDeleteWord = async (wordId: string) => {
    try {
      const res = await fetch(`/api/words/${wordId}`, {
        method: 'DELETE',
      });

      if (res.ok) {
        fetchData();
      }
    } catch (error) {
      console.error('Error deleting word:', error);
    }
  };

  const handleSaveSettings = async () => {
    try {
      await fetch('/api/user-settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings),
      });
      alert('Settings saved!');
    } catch (error) {
      console.error('Error saving settings:', error);
    }
  };

  const handleSignOut = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push('/auth/login');
  };

  const handleUpdateWordTopic = async (wordId: string, topicId: string) => {
    try {
      const res = await fetch(`/api/words/${wordId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ topic_id: topicId }),
      });

      if (res.ok) {
        fetchData();
      }
    } catch (error) {
      console.error('Error updating word topic:', error);
    }
  };

  const getCustomAudio = (wordId: string, language: string) => {
    return customAudios.find(
      (a) => a.word_id === wordId && a.language === language
    );
  };

  const getCustomImage = (wordId: string) => {
    return customImages.find((img) => img.word_id === wordId);
  };

  const getWordImageUrl = (word: Word) => {
    const customImage = getCustomImage(word.id);
    return customImage?.image_url || word.generated_image_url;
  };

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-lg">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background p-8">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-bold">Manage Words</h1>
            <p className="text-muted-foreground mt-1">
              Manage words and settings for your daughter&apos;s learning app
            </p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => router.push('/')}>
              View App
            </Button>
            <Button variant="outline" onClick={handleSignOut}>
              Sign Out
            </Button>
          </div>
        </div>

        <Tabs defaultValue="words" className="w-full">
          <TabsList className="grid w-full max-w-md grid-cols-2">
            <TabsTrigger value="words">Words</TabsTrigger>
            <TabsTrigger value="settings">
              <Settings className="w-4 h-4 mr-2" />
              Settings
            </TabsTrigger>
          </TabsList>

          {/* Words Tab */}
          <TabsContent value="words" className="space-y-6">
            {/* Add New Word */}
            <Card>
              <CardHeader>
                <CardTitle>Add New Word</CardTitle>
                <CardDescription>
                  Add a word in all three languages
                </CardDescription>
              </CardHeader>
              <CardContent>
                <form onSubmit={handleAddWord} className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="word-en">English</Label>
                      <Input
                        id="word-en"
                        value={newWord.word_en}
                        onChange={(e) =>
                          setNewWord({ ...newWord, word_en: e.target.value })
                        }
                        placeholder="cat"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="word-ru">Russian</Label>
                      <Input
                        id="word-ru"
                        value={newWord.word_ru}
                        onChange={(e) =>
                          setNewWord({ ...newWord, word_ru: e.target.value })
                        }
                        placeholder="кот"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="word-de">German</Label>
                      <Input
                        id="word-de"
                        value={newWord.word_de}
                        onChange={(e) =>
                          setNewWord({ ...newWord, word_de: e.target.value })
                        }
                        placeholder="Katze"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="topic">Topic</Label>
                      <Select
                        value={newWord.topic_id}
                        onValueChange={(val) => setNewWord({ ...newWord, topic_id: val })}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="Select topic" />
                        </SelectTrigger>
                        <SelectContent>
                          {topics.map((topic) => (
                            <SelectItem key={topic.id} value={topic.id}>
                              {topic.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                  <Button type="submit" className="w-full md:w-auto">
                    <Plus className="w-4 h-4 mr-2" />
                    Add Word
                  </Button>
                </form>
              </CardContent>
            </Card>

            {/* Words List */}
            <Card>
              <CardHeader>
                <CardTitle>All Words ({words.length})</CardTitle>
                <CardDescription>
                  Manage your word collection, images, and audio
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {words.length === 0 ? (
                    <p className="text-center text-muted-foreground py-8">
                      No words yet. Add your first word above.
                    </p>
                  ) : (
                    words.map((word) => (
                      <div
                        key={word.id}
                        className="border rounded-lg overflow-hidden"
                      >
                        <div className="flex items-center justify-between p-4 hover:bg-muted/50 transition-colors">
                          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 flex-1">
                            <div>
                              <span className="text-xs text-muted-foreground">
                                EN:
                              </span>{' '}
                              <span className="font-medium">
                                {word.word_en || '—'}
                              </span>
                            </div>
                            <div>
                              <span className="text-xs text-muted-foreground">
                                RU:
                              </span>{' '}
                              <span className="font-medium">
                                {word.word_ru || '—'}
                              </span>
                            </div>
                            <div>
                              <span className="text-xs text-muted-foreground">
                                DE:
                              </span>{' '}
                              <span className="font-medium">
                                {word.word_de || '—'}
                              </span>
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            <Button
                              variant="ghost"
                              size="icon"
                              onClick={() =>
                                setExpandedWordId(
                                  expandedWordId === word.id ? null : word.id
                                )
                              }
                            >
                              {expandedWordId === word.id ? (
                                <ChevronUp className="w-4 h-4" />
                              ) : (
                                <ChevronDown className="w-4 h-4" />
                              )}
                            </Button>
                            {word.user_id && (
                              <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => handleDeleteWord(word.id)}
                              >
                                <Trash2 className="w-4 h-4 text-destructive" />
                              </Button>
                            )}
                          </div>
                        </div>

                        {expandedWordId === word.id && (
                          <div className="px-4 pb-4 bg-muted/30 space-y-6">
                            {/* Topic Selection */}
                            <div>
                              <p className="text-sm font-medium mb-3">Topic</p>
                              <Select
                                value={word.topic_id || ''}
                                onValueChange={(val) => handleUpdateWordTopic(word.id, val)}
                              >
                                <SelectTrigger className="w-[200px]">
                                  <SelectValue placeholder="Select topic" />
                                </SelectTrigger>
                                <SelectContent>
                                  {topics.map((topic) => (
                                    <SelectItem key={topic.id} value={topic.id}>
                                      {topic.name}
                                    </SelectItem>
                                  ))}
                                </SelectContent>
                              </Select>
                            </div>

                            {/* Image Section */}
                            <div>
                              <p className="text-sm font-medium mb-3">Image</p>
                              <ImageManager
                                wordId={word.id}
                                wordText={word.word_en || word.word_ru || word.word_de || ''}
                                currentImageUrl={getWordImageUrl(word)}
                                currentStyle={word.image_style || 'simple'}
                                isUserWord={!!word.user_id}
                                onImageUpdated={fetchData}
                              />
                            </div>

                            {/* Audio Section */}
                            <div>
                              <p className="text-sm font-medium mb-3">
                                Custom Audio Recordings
                              </p>
                              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                                <div>
                                  <p className="text-xs text-muted-foreground mb-2">
                                    English
                                  </p>
                                  <AudioRecorder
                                    wordId={word.id}
                                    language="en"
                                    existingAudioUrl={
                                      getCustomAudio(word.id, 'en')?.audio_url
                                    }
                                    onAudioUploaded={fetchData}
                                  />
                                </div>
                                <div>
                                  <p className="text-xs text-muted-foreground mb-2">
                                    Russian
                                  </p>
                                  <AudioRecorder
                                    wordId={word.id}
                                    language="ru"
                                    existingAudioUrl={
                                      getCustomAudio(word.id, 'ru')?.audio_url
                                    }
                                    onAudioUploaded={fetchData}
                                  />
                                </div>
                                <div>
                                  <p className="text-xs text-muted-foreground mb-2">
                                    German
                                  </p>
                                  <AudioRecorder
                                    wordId={word.id}
                                    language="de"
                                    existingAudioUrl={
                                      getCustomAudio(word.id, 'de')?.audio_url
                                    }
                                    onAudioUploaded={fetchData}
                                  />
                                </div>
                              </div>
                            </div>
                          </div>
                        )}
                      </div>
                    ))
                  )}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Settings Tab */}
          <TabsContent value="settings" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Language Settings</CardTitle>
                <CardDescription>
                  Choose which languages to display and speak
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="space-y-2">
                  <Label htmlFor="primary-lang">Primary Language</Label>
                  <Select
                    value={settings.primary_language}
                    onValueChange={(value: 'en' | 'ru' | 'de') =>
                      setSettings({ ...settings, primary_language: value })
                    }
                  >
                    <SelectTrigger id="primary-lang">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="en">English</SelectItem>
                      <SelectItem value="ru">Russian</SelectItem>
                      <SelectItem value="de">German</SelectItem>
                    </SelectContent>
                  </Select>
                  <p className="text-xs text-muted-foreground">
                    The main language shown in large text
                  </p>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="secondary-lang">Secondary Language</Label>
                  <Select
                    value={settings.secondary_language}
                    onValueChange={(value: 'en' | 'ru' | 'de') =>
                      setSettings({ ...settings, secondary_language: value })
                    }
                  >
                    <SelectTrigger id="secondary-lang">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="en">English</SelectItem>
                      <SelectItem value="ru">Russian</SelectItem>
                      <SelectItem value="de">German</SelectItem>
                    </SelectContent>
                  </Select>
                  <p className="text-xs text-muted-foreground">
                    The translation shown in smaller text
                  </p>
                </div>

                <Button onClick={handleSaveSettings}>Save Settings</Button>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
