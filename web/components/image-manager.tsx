"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Sparkles, Upload, Trash2, Loader2 } from 'lucide-react';
import { Card, CardContent } from "@/components/ui/card";

type ImageManagerProps = {
  wordId: string;
  wordText: string;
  currentImageUrl: string | null;
  currentStyle?: string;
  isUserWord: boolean;
  onImageUpdated: () => void;
};

const IMAGE_STYLES = {
  crayon: "Children's crayon drawing, bold outlines, bright colors, waxy texture",
  doodle: "Simple hand-drawn doodle, clean black lines, minimal shading, high contrast",
  pencil: "Soft pencil sketch, light shading, gentle graphite texture, minimal color",
  simple: "Simple cool image of the requested object",
  watercolor: "Playful watercolor wash, soft gradients, organic textures, storybook vibe",
} as const;

type ImageStyle = keyof typeof IMAGE_STYLES;

export default function ImageManager({
  wordId,
  wordText,
  currentImageUrl,
  currentStyle = 'simple',
  isUserWord,
  onImageUpdated,
}: ImageManagerProps) {
  const [isGenerating, setIsGenerating] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [selectedStyle, setSelectedStyle] = useState<ImageStyle>(currentStyle as ImageStyle);

  const handleGenerateImage = async () => {
    setIsGenerating(true);
    try {
      const res = await fetch('/api/generate-image', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          word_id: wordId, 
          word_text: wordText,
          style: selectedStyle 
        }),
      });

      if (res.ok) {
        onImageUpdated();
        alert('Image generated successfully!');
      } else {
        const error = await res.json();
        alert(`Failed to generate image: ${error.error}`);
      }
    } catch (error) {
      console.error('Error generating image:', error);
      alert('Error generating image');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
    }
  };

  const handleUploadImage = async () => {
    if (!selectedFile) return;

    setIsUploading(true);
    try {
      const formData = new FormData();
      formData.append('image', selectedFile);
      formData.append('word_id', wordId);
      formData.append('style', selectedStyle);

      console.log('[v0] Uploading image:', { wordId, style: selectedStyle, fileSize: selectedFile.size });

      const res = await fetch('/api/custom-images', {
        method: 'POST',
        body: formData,
      });

      const contentType = res.headers.get('content-type');
      
      if (res.ok) {
        setSelectedFile(null);
        onImageUpdated();
        alert('Image uploaded successfully!');
      } else {
        let errorMessage = `Upload failed with status ${res.status}`;
        
        if (contentType?.includes('application/json')) {
          try {
            const errorData = await res.json();
            errorMessage = errorData.error || errorData.details || errorMessage;
          } catch (e) {
            console.error('[v0] Failed to parse error JSON:', e);
          }
        } else {
          const errorText = await res.text();
          errorMessage = errorText.substring(0, 200);
          console.error('[v0] Non-JSON error response:', errorText);
        }
        
        alert(`Failed to upload image: ${errorMessage}`);
      }
    } catch (error: any) {
      console.error('[v0] Error uploading image:', error);
      alert(`Error uploading image: ${error.message || 'Network or client error'}`);
    } finally {
      setIsUploading(false);
    }
  };

  const handleDeleteCustomImage = async () => {
    try {
      const res = await fetch(`/api/custom-images?word_id=${wordId}`, {
        method: 'DELETE',
      });

      if (res.ok) {
        onImageUpdated();
        alert('Custom image deleted!');
      } else {
        alert('Failed to delete image');
      }
    } catch (error) {
      console.error('Error deleting image:', error);
      alert('Error deleting image');
    }
  };

  return (
    <Card>
      <CardContent className="pt-6 space-y-4">
        {currentImageUrl && (
          <div className="relative aspect-square w-full max-w-xs mx-auto rounded-lg overflow-hidden border">
            <img
              src={currentImageUrl || "/placeholder.svg"}
              alt={wordText}
              className="w-full h-full object-cover"
            />
          </div>
        )}

        {isUserWord && (
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="image-style">Image Style</Label>
              <Select
                value={selectedStyle}
                onValueChange={(value: ImageStyle) => setSelectedStyle(value)}
              >
                <SelectTrigger id="image-style">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="simple">Simple</SelectItem>
                  <SelectItem value="crayon">Crayon Drawing</SelectItem>
                  <SelectItem value="doodle">Doodle</SelectItem>
                  <SelectItem value="pencil">Pencil Sketch</SelectItem>
                  <SelectItem value="watercolor">Watercolor</SelectItem>
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">
                {IMAGE_STYLES[selectedStyle]}
              </p>
            </div>

            <Button
              onClick={handleGenerateImage}
              disabled={isGenerating}
              variant="outline"
              className="w-full"
              size="sm"
            >
              {isGenerating ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Generating...
                </>
              ) : (
                <>
                  <Sparkles className="w-4 h-4 mr-2" />
                  Generate AI Image
                </>
              )}
            </Button>
          </div>
        )}

        <div className="space-y-2">
          <Input
            type="file"
            accept="image/*"
            onChange={handleFileSelect}
            className="text-sm"
          />
          {selectedFile && (
            <Button
              onClick={handleUploadImage}
              disabled={isUploading}
              size="sm"
              className="w-full"
            >
              {isUploading ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Uploading...
                </>
              ) : (
                <>
                  <Upload className="w-4 h-4 mr-2" />
                  Upload Custom Image
                </>
              )}
            </Button>
          )}
        </div>

        {currentImageUrl && isUserWord && (
          <Button
            onClick={handleDeleteCustomImage}
            variant="ghost"
            size="sm"
            className="w-full text-destructive"
          >
            <Trash2 className="w-4 h-4 mr-2" />
            Remove Image
          </Button>
        )}
      </CardContent>
    </Card>
  );
}
