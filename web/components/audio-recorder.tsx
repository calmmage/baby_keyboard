"use client";

import { useState, useRef, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Mic, Square, Play, Trash2, Upload } from 'lucide-react';
import { Card, CardContent } from "@/components/ui/card";

type AudioRecorderProps = {
  wordId: string;
  language: 'en' | 'ru' | 'de';
  existingAudioUrl?: string;
  onAudioUploaded: () => void;
};

export default function AudioRecorder({
  wordId,
  language,
  existingAudioUrl,
  onAudioUploaded,
}: AudioRecorderProps) {
  const [isRecording, setIsRecording] = useState(false);
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null);
  const [audioUrl, setAudioUrl] = useState<string | null>(existingAudioUrl || null);
  const [isUploading, setIsUploading] = useState(false);
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);

  useEffect(() => {
    setAudioUrl(existingAudioUrl || null);
  }, [existingAudioUrl]);

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      audioChunksRef.current = [];

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(audioChunksRef.current, { type: 'audio/webm' });
        setAudioBlob(blob);
        const url = URL.createObjectURL(blob);
        setAudioUrl(url);
        
        // Stop all tracks
        stream.getTracks().forEach(track => track.stop());
      };

      mediaRecorder.start();
      setIsRecording(true);
    } catch (error) {
      console.error('Error accessing microphone:', error);
      alert('Could not access microphone. Please check permissions.');
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
    }
  };

  const handleUpload = async () => {
    if (!audioBlob) return;

    setIsUploading(true);
    try {
      // Create FormData
      const formData = new FormData();
      formData.append('audio', audioBlob, `${wordId}_${language}.webm`);
      formData.append('word_id', wordId);
      formData.append('language', language);

      const res = await fetch('/api/custom-audio', {
        method: 'POST',
        body: formData,
      });

      if (res.ok) {
        setAudioBlob(null);
        onAudioUploaded();
        alert('Audio uploaded successfully!');
      } else {
        alert('Failed to upload audio');
      }
    } catch (error) {
      console.error('Error uploading audio:', error);
      alert('Error uploading audio');
    } finally {
      setIsUploading(false);
    }
  };

  const handleDelete = async () => {
    try {
      const res = await fetch(`/api/custom-audio?word_id=${wordId}&language=${language}`, {
        method: 'DELETE',
      });

      if (res.ok) {
        setAudioUrl(null);
        setAudioBlob(null);
        onAudioUploaded();
        alert('Audio deleted successfully!');
      } else {
        alert('Failed to delete audio');
      }
    } catch (error) {
      console.error('Error deleting audio:', error);
      alert('Error deleting audio');
    }
  };

  const playAudio = () => {
    if (audioUrl) {
      const audio = new Audio(audioUrl);
      audio.play();
    }
  };

  return (
    <Card>
      <CardContent className="pt-6">
        <div className="flex flex-col gap-3">
          <div className="flex items-center gap-2">
            {!isRecording && !audioBlob && !existingAudioUrl && (
              <Button onClick={startRecording} variant="outline" size="sm">
                <Mic className="w-4 h-4 mr-2" />
                Record
              </Button>
            )}
            
            {isRecording && (
              <Button onClick={stopRecording} variant="destructive" size="sm">
                <Square className="w-4 h-4 mr-2" />
                Stop
              </Button>
            )}

            {audioUrl && (
              <>
                <Button onClick={playAudio} variant="outline" size="sm">
                  <Play className="w-4 h-4 mr-2" />
                  Play
                </Button>
                <Button onClick={handleDelete} variant="ghost" size="sm">
                  <Trash2 className="w-4 h-4" />
                </Button>
              </>
            )}
          </div>

          {audioBlob && !existingAudioUrl && (
            <Button
              onClick={handleUpload}
              disabled={isUploading}
              size="sm"
              className="w-full"
            >
              <Upload className="w-4 h-4 mr-2" />
              {isUploading ? 'Uploading...' : 'Upload Audio'}
            </Button>
          )}

          {existingAudioUrl && (
            <p className="text-xs text-muted-foreground">
              Custom audio uploaded
            </p>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
