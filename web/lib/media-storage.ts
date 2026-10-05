import "server-only";

import { access, mkdir, readdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";

import {
  DeleteObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";

type MediaStorageProvider = "local" | "s3";

type UploadMediaParams = {
  objectKey: string;
  data: Buffer | Uint8Array;
  contentType: string;
  cacheControl?: string;
};

type UploadedMedia = {
  provider: MediaStorageProvider;
  objectKey: string;
  publicUrl: string;
};

const LOCAL_PUBLIC_DIR = path.join(process.cwd(), "public");

function cleanSegment(value: string): string {
  return value.replaceAll("\\", "/").replace(/^\/+/, "").replace(/\/+/g, "/");
}

function trimSlashes(value: string): string {
  return value.replace(/^\/+/, "").replace(/\/+$/, "");
}

function getProvider(): MediaStorageProvider {
  const explicit = process.env.MEDIA_STORAGE_PROVIDER?.trim().toLowerCase();
  if (explicit === "s3") {
    return "s3";
  }
  if (explicit === "local") {
    return "local";
  }
  return process.env.AWS_S3_BUCKET ? "s3" : "local";
}

function getS3Bucket(): string {
  const bucket = process.env.AWS_S3_BUCKET?.trim();
  if (!bucket) {
    throw new Error("AWS_S3_BUCKET is required when MEDIA_STORAGE_PROVIDER=s3");
  }
  return bucket;
}

function getS3Region(): string {
  return process.env.AWS_REGION?.trim() || "us-east-1";
}

function getS3Prefix(): string {
  return trimSlashes(process.env.AWS_S3_PREFIX?.trim() || "");
}

function toS3ObjectKey(objectKey: string): string {
  const normalized = cleanSegment(objectKey);
  const prefix = getS3Prefix();
  if (prefix && (normalized === prefix || normalized.startsWith(`${prefix}/`))) {
    return normalized;
  }
  return prefix ? `${prefix}/${normalized}` : normalized;
}

function getS3PublicBaseURL(): string {
  const base = process.env.MEDIA_STORAGE_BASE_URL?.trim();
  if (base) {
    return trimSlashes(base);
  }
  const bucket = getS3Bucket();
  const region = getS3Region();
  return `https://${bucket}.s3.${region}.amazonaws.com`;
}

function toPublicUrl(provider: MediaStorageProvider, objectKey: string): string {
  if (provider === "s3") {
    return `${getS3PublicBaseURL()}/${objectKey}`;
  }
  return `/${cleanSegment(objectKey)}`;
}

let s3ClientSingleton: S3Client | null = null;

function getS3Client(): S3Client {
  if (!s3ClientSingleton) {
    s3ClientSingleton = new S3Client({ region: getS3Region() });
  }
  return s3ClientSingleton;
}

export async function uploadMedia(params: UploadMediaParams): Promise<UploadedMedia> {
  const provider = getProvider();
  const objectKey = cleanSegment(params.objectKey);

  if (provider === "s3") {
    const bucket = getS3Bucket();
    const s3Key = toS3ObjectKey(objectKey);
    await getS3Client().send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: s3Key,
        Body: params.data,
        ContentType: params.contentType,
        CacheControl: params.cacheControl || "public,max-age=31536000,immutable",
      }),
    );
    return {
      provider,
      objectKey: s3Key,
      publicUrl: toPublicUrl(provider, s3Key),
    };
  }

  const outputPath = path.join(LOCAL_PUBLIC_DIR, objectKey);
  await mkdir(path.dirname(outputPath), { recursive: true });
  await writeFile(outputPath, Buffer.from(params.data));
  return {
    provider,
    objectKey,
    publicUrl: toPublicUrl(provider, objectKey),
  };
}

export async function deleteMediaObject(objectKey: string): Promise<void> {
  const provider = getProvider();
  const normalized = cleanSegment(objectKey);

  if (provider === "s3") {
    await getS3Client().send(
      new DeleteObjectCommand({
        Bucket: getS3Bucket(),
        Key: toS3ObjectKey(normalized),
      }),
    );
    return;
  }

  await rm(path.join(LOCAL_PUBLIC_DIR, normalized), { force: true });
}

export async function listMediaObjectsByPrefix(prefix: string): Promise<string[]> {
  const provider = getProvider();
  const normalizedPrefix = cleanSegment(prefix);

  if (provider === "s3") {
    const fullPrefix = toS3ObjectKey(normalizedPrefix);
    const response = await getS3Client().send(
      new ListObjectsV2Command({
        Bucket: getS3Bucket(),
        Prefix: fullPrefix,
        MaxKeys: 100,
      }),
    );
    return (response.Contents || [])
      .map((item) => item.Key || "")
      .filter((item) => item.length > 0);
  }

  const dir = path.join(LOCAL_PUBLIC_DIR, path.posix.dirname(normalizedPrefix));
  const filenamePrefix = path.posix.basename(normalizedPrefix);
  const entries = await readdir(dir).catch(() => []);
  return entries
    .filter((entry) => entry.startsWith(filenamePrefix))
    .map((entry) => {
      const parent = path.posix.dirname(normalizedPrefix);
      return parent === "." ? entry : `${parent}/${entry}`;
    });
}

export async function mediaObjectExists(objectKey: string): Promise<boolean> {
  const provider = getProvider();
  const normalized = cleanSegment(objectKey);
  if (provider === "s3") {
    const items = await listMediaObjectsByPrefix(normalized);
    return items.includes(toS3ObjectKey(normalized));
  }
  return access(path.join(LOCAL_PUBLIC_DIR, normalized))
    .then(() => true)
    .catch(() => false);
}

export function publicUrlForObjectKey(objectKey: string): string {
  const provider = getProvider();
  const normalized = cleanSegment(objectKey);
  if (provider === "s3") {
    const fullKey = toS3ObjectKey(normalized);
    return toPublicUrl("s3", fullKey);
  }
  return toPublicUrl("local", normalized);
}
