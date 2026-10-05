import { NextResponse } from "next/server";

import { uploadMedia } from "@/lib/media-storage";

type GenerateImageRequest = {
  wordId?: string;
  spelling?: string;
  style?: string;
};

const STYLE_GUIDES: Record<string, { gradient: string; accent: string }> = {
  simple: { gradient: "#f8fafc,#e2e8f0", accent: "#0f172a" },
  crayon: { gradient: "#fee2e2,#fecaca", accent: "#be123c" },
  doodle: { gradient: "#fef9c3,#fde68a", accent: "#92400e" },
  watercolor: { gradient: "#dbeafe,#c7d2fe", accent: "#1d4ed8" },
  pencil: { gradient: "#f1f5f9,#cbd5e1", accent: "#334155" },
};

function escapeXML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function buildFallbackSVG(word: string, style: string): string {
  const styleSpec = STYLE_GUIDES[style] ?? STYLE_GUIDES.simple;
  const [fromColor, toColor] = styleSpec.gradient.split(",");
  const safeWord = escapeXML(word);

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="${safeWord}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${fromColor}" />
      <stop offset="100%" stop-color="${toColor}" />
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="1024" height="1024" fill="url(#g)" rx="72" />
  <circle cx="220" cy="230" r="130" fill="${styleSpec.accent}" opacity="0.12" />
  <circle cx="790" cy="760" r="170" fill="${styleSpec.accent}" opacity="0.14" />
  <rect x="150" y="350" width="724" height="324" rx="50" fill="white" opacity="0.86" />
  <text x="512" y="535" text-anchor="middle" fill="${styleSpec.accent}" font-size="112" font-weight="700" font-family="Verdana, sans-serif">${safeWord}</text>
  <text x="512" y="620" text-anchor="middle" fill="${styleSpec.accent}" font-size="38" opacity="0.7" font-family="Verdana, sans-serif">${escapeXML(style)}</text>
</svg>`;
}

async function generateWithGemini(prompt: string, apiKey: string): Promise<string | undefined> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
      }),
    },
  );

  if (!response.ok) {
    return undefined;
  }

  const payload = (await response.json()) as {
    candidates?: Array<{
      content?: { parts?: Array<{ inlineData?: { data?: string } }> };
    }>;
  };

  const parts = payload.candidates?.[0]?.content?.parts ?? [];
  const imagePart = parts.find((part) => part.inlineData?.data);
  if (!imagePart?.inlineData?.data) {
    return undefined;
  }
  return `data:image/png;base64,${imagePart.inlineData.data}`;
}

function safeSegment(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9_-]+/g, "-");
}

function objectKeyForGeneratedImage(wordId: string, style: string, extension: string): string {
  const safeWord = encodeURIComponent(wordId.trim().toLowerCase());
  const safeStyle = safeSegment(style || "simple");
  return `generated-media/images/${safeWord}/${safeStyle}-${Date.now()}.${extension}`;
}

function parseDataURL(dataURL: string): { mimeType: string; data: Buffer } {
  const match = dataURL.match(/^data:([^;]+);base64,(.+)$/);
  if (!match) {
    throw new Error("Invalid data URL payload");
  }
  return {
    mimeType: match[1],
    data: Buffer.from(match[2], "base64"),
  };
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as GenerateImageRequest;
    const wordId = body.wordId?.trim();
    const spelling = body.spelling?.trim();
    const style = (body.style?.trim().toLowerCase() || "simple").replace(/[^a-z]/g, "");

    if (!wordId || !spelling) {
      return NextResponse.json(
        { error: "wordId and spelling are required" },
        { status: 400 },
      );
    }

    const prompt = [
      "Children's flashcard illustration.",
      `Subject: ${spelling}.`,
      `Style: ${style || "simple"}.`,
      "Centered object, no text labels, plain background, high contrast.",
    ].join(" ");

    const apiKey = process.env.GOOGLE_GENERATIVE_AI_API_KEY || process.env.GEMINI_API_KEY;
    if (apiKey) {
      const generated = await generateWithGemini(prompt, apiKey);
      if (generated) {
        const parsed = parseDataURL(generated);
        const uploaded = await uploadMedia({
          objectKey: objectKeyForGeneratedImage(wordId, style || "simple", "png"),
          data: parsed.data,
          contentType: parsed.mimeType || "image/png",
        });
        return NextResponse.json({
          wordId,
          style: style || "simple",
          provider: "gemini",
          imageUrl: uploaded.publicUrl,
          objectKey: uploaded.objectKey,
          storageProvider: uploaded.provider,
        });
      }
    }

    const svg = buildFallbackSVG(spelling, style || "simple");
    const uploaded = await uploadMedia({
      objectKey: objectKeyForGeneratedImage(wordId, style || "simple", "svg"),
      data: Buffer.from(svg),
      contentType: "image/svg+xml",
      cacheControl: "public,max-age=86400",
    });

    return NextResponse.json({
      wordId,
      style: style || "simple",
      provider: "fallback-svg",
      imageUrl: uploaded.publicUrl,
      objectKey: uploaded.objectKey,
      storageProvider: uploaded.provider,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Failed to generate image" },
      { status: 500 },
    );
  }
}
