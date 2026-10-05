#!/usr/bin/env node

const fs = require("fs");
const fsp = require("fs/promises");
const path = require("path");

try {
  require("dotenv").config({ path: path.join(process.cwd(), ".env.local") });
} catch {}

function parseArgs(argv) {
  const args = {
    manifest: path.resolve(process.cwd(), "../dev/artifacts/flashcard-assets-manifest.json"),
    provider:
      (process.env.MEDIA_STORAGE_PROVIDER || (process.env.AWS_S3_BUCKET ? "s3" : "local")).trim().toLowerCase(),
    publicDir: path.resolve(process.cwd(), "public"),
    bucket: (process.env.AWS_S3_BUCKET || "").trim(),
    region: (process.env.AWS_REGION || "us-east-1").trim(),
    prefix: (process.env.AWS_S3_PREFIX || "").trim().replace(/^\/+|\/+$/g, ""),
    baseUrl: (process.env.MEDIA_STORAGE_BASE_URL || "").trim(),
    dryRun: false,
    limit: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--help" || value === "-h") {
      args.help = true;
    } else if (value === "--manifest") {
      args.manifest = path.resolve(process.cwd(), argv[index + 1]);
      index += 1;
    } else if (value === "--provider") {
      args.provider = String(argv[index + 1] || "").trim().toLowerCase();
      index += 1;
    } else if (value === "--public-dir") {
      args.publicDir = path.resolve(process.cwd(), argv[index + 1]);
      index += 1;
    } else if (value === "--bucket") {
      args.bucket = String(argv[index + 1] || "").trim();
      index += 1;
    } else if (value === "--region") {
      args.region = String(argv[index + 1] || "").trim();
      index += 1;
    } else if (value === "--prefix") {
      args.prefix = String(argv[index + 1] || "").trim().replace(/^\/+|\/+$/g, "");
      index += 1;
    } else if (value === "--base-url") {
      args.baseUrl = String(argv[index + 1] || "").trim();
      index += 1;
    } else if (value === "--limit") {
      args.limit = Number.parseInt(argv[index + 1], 10);
      index += 1;
    } else if (value === "--dry-run") {
      args.dryRun = true;
    }
  }

  return args;
}

function usage() {
  console.log(`Usage:
  node scripts/upload-flashcard-assets.js [options]

Options:
  --manifest <path>     Manifest JSON from scripts.prepare_flashcard_assets
  --provider <local|s3> Storage backend (default from env)
  --public-dir <path>   Local public output dir when provider=local
  --bucket <name>       S3 bucket name when provider=s3
  --region <region>     S3 region when provider=s3
  --prefix <prefix>     Optional S3 key prefix
  --base-url <url>      Optional public base URL override
  --limit <n>           Upload only first N items
  --dry-run             Print planned uploads without writing
  --help                Show this message
`);
}

function cleanSegment(value) {
  return value.replaceAll("\\", "/").replace(/^\/+/, "").replace(/\/+/g, "/");
}

function joinObjectKey(prefix, objectKey) {
  const normalizedObjectKey = cleanSegment(objectKey);
  if (!prefix) {
    return normalizedObjectKey;
  }
  if (normalizedObjectKey === prefix || normalizedObjectKey.startsWith(`${prefix}/`)) {
    return normalizedObjectKey;
  }
  return `${prefix}/${normalizedObjectKey}`;
}

function contentTypeForFile(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  if (extension === ".png") return "image/png";
  if (extension === ".webp") return "image/webp";
  if (extension === ".jpg" || extension === ".jpeg") return "image/jpeg";
  if (extension === ".svg") return "image/svg+xml";
  return "application/octet-stream";
}

async function loadManifest(manifestPath) {
  const raw = await fsp.readFile(manifestPath, "utf8");
  const parsed = JSON.parse(raw);
  if (!parsed || !Array.isArray(parsed.items)) {
    throw new Error(`Invalid manifest: ${manifestPath}`);
  }
  return parsed;
}

async function uploadLocal(item, args) {
  const outputPath = path.join(args.publicDir, cleanSegment(item.objectKey));
  await fsp.mkdir(path.dirname(outputPath), { recursive: true });
  if (!args.dryRun) {
    await fsp.copyFile(item.localPath, outputPath);
  }
  return {
    provider: "local",
    objectKey: cleanSegment(item.objectKey),
    publicUrl: args.baseUrl
      ? `${args.baseUrl.replace(/\/+$/, "")}/${cleanSegment(item.objectKey)}`
      : `/${cleanSegment(item.objectKey)}`,
  };
}

async function uploadS3(item, args) {
  if (!args.bucket) {
    throw new Error("AWS_S3_BUCKET or --bucket is required for provider=s3");
  }
  const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
  const client = new S3Client({ region: args.region });
  const objectKey = joinObjectKey(args.prefix, item.objectKey);
  if (!args.dryRun) {
    await client.send(
      new PutObjectCommand({
        Bucket: args.bucket,
        Key: objectKey,
        Body: fs.createReadStream(item.localPath),
        ContentType: contentTypeForFile(item.localPath),
        CacheControl: "public,max-age=31536000,immutable",
      }),
    );
  }
  const publicBase =
    args.baseUrl || `https://${args.bucket}.s3.${args.region}.amazonaws.com`;
  return {
    provider: "s3",
    objectKey,
    publicUrl: `${publicBase.replace(/\/+$/, "")}/${objectKey}`,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    usage();
    return;
  }

  const manifest = await loadManifest(args.manifest);
  const items = args.limit ? manifest.items.slice(0, args.limit) : manifest.items;

  if (args.provider !== "local" && args.provider !== "s3") {
    throw new Error(`Unsupported provider: ${args.provider}`);
  }

  let uploaded = 0;
  for (const item of items) {
    const result =
      args.provider === "s3"
        ? await uploadS3(item, args)
        : await uploadLocal(item, args);
    uploaded += 1;
    console.log(
      JSON.stringify(
        {
          index: uploaded,
          provider: result.provider,
          objectKey: result.objectKey,
          publicUrl: result.publicUrl,
          localPath: item.localPath,
        },
        null,
        2,
      ),
    );
  }

  console.log(
    JSON.stringify(
      {
        manifest: args.manifest,
        uploaded,
        provider: args.provider,
        dryRun: args.dryRun,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
