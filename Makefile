.PHONY: generate-images download-openimages help

PYTHON := .venv/bin/python3
.DEFAULT_GOAL := help
.PHONY: test-openimage run-openimage test-gemini run-gemini
.PHONY: list-words dictionary-showcase
.PHONY: deploy update clean archive export install
.PHONY: s3-bucket-setup s3-media-sync
.PHONY: web-install web-dev web-build web-start

AWS_REGION ?= us-east-1
S3_BUCKET ?=
S3_PREFIX ?= baby-keyboard
WEB_DIR ?= web
WEB_PM ?= npm
WEB_PORT ?= 3000
WEB_INSTALL_ARGS ?=

# Compose shared flag helpers
WORDS_FLAG := $(if $(strip $(WORDS)),--words $(WORDS),)
WORDS_FILE_FLAG := $(if $(strip $(WORDS_FILE)),--words-file $(WORDS_FILE),)
OUTPUT_FLAG := $(if $(strip $(OUTPUT)),--output $(OUTPUT),)
MODEL_FLAG := $(if $(strip $(MODEL)),--model $(MODEL),)
SIZE_FLAG := $(if $(strip $(SIZE)),--size $(SIZE),)
MAX_CONCURRENT_FLAG := $(if $(strip $(MAX_CONCURRENT)),--max-concurrent $(MAX_CONCURRENT),)
SAMPLE_SIZE_FLAG := $(if $(strip $(SAMPLE_SIZE)),--sample-size $(SAMPLE_SIZE),)
SEED_FLAG := $(if $(strip $(SEED)),--seed $(SEED),)
ALL_DEFAULTS_FLAG := $(if $(strip $(ALL_DEFAULTS)),--all-defaults,)

# Image generator specific flags
STYLE_FLAG := $(if $(strip $(STYLE)),--style $(STYLE),)
STYLE_PROMPT_FLAG := $(if $(strip $(STYLE_PROMPT)),--style-prompt "$(STYLE_PROMPT)",)

# Open Images specific flags
LIMIT_FLAG := $(if $(strip $(LIMIT)),--limit $(LIMIT),)
MAX_SAMPLES_FLAG := $(if $(strip $(MAX_SAMPLES)),--max-samples $(MAX_SAMPLES),)

generate-images:
	$(PYTHON) scripts/generate_images.py \
		$(WORDS_FLAG) \
		$(WORDS_FILE_FLAG) \
		$(SAMPLE_SIZE_FLAG) \
		$(SEED_FLAG) \
		$(ALL_DEFAULTS_FLAG) \
		$(STYLE_FLAG) \
		$(STYLE_PROMPT_FLAG) \
		$(OUTPUT_FLAG) \
		$(MODEL_FLAG) \
		$(SIZE_FLAG) \
		$(MAX_CONCURRENT_FLAG) \
		$(ARGS)

download-openimages:
	$(PYTHON) scripts/download_openimages.py \
		$(WORDS_FLAG) \
		$(WORDS_FILE_FLAG) \
		$(OUTPUT_FLAG) \
		$(SAMPLE_SIZE_FLAG) \
		$(SEED_FLAG) \
		$(ALL_DEFAULTS_FLAG) \
		$(LIMIT_FLAG) \
		$(MAX_SAMPLES_FLAG) \
		$(ARGS)

test-openimage:
	$(MAKE) --no-print-directory download-openimages SAMPLE_SIZE=2 LIMIT=2 MAX_SAMPLES=40 ARGS="--yes"

run-openimage: download-openimages

test-gemini:
	printf 'yes\n' | $(MAKE) --no-print-directory generate-images SAMPLE_SIZE=2 MAX_CONCURRENT=2

run-gemini: generate-images

list-words:
	uv run python -m scripts.list_words

dictionary-showcase:
	uv run python -m scripts.word_dictionary_showcase --lang en --summary $(ARGS)

web-install:
	@cd $(WEB_DIR) && $(WEB_PM) install $(WEB_INSTALL_ARGS)

web-dev:
	@cd $(WEB_DIR) && PORT=$(WEB_PORT) $(WEB_PM) run dev

web-build:
	@cd $(WEB_DIR) && $(WEB_PM) run build

web-start:
	@cd $(WEB_DIR) && PORT=$(WEB_PORT) $(WEB_PM) run start

s3-bucket-setup:
	@test -n "$(S3_BUCKET)" || (echo "Set S3_BUCKET=<bucket-name>" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "AWS CLI is required" && exit 1)
	@if [ "$(AWS_REGION)" = "us-east-1" ]; then \
		aws s3api create-bucket --bucket "$(S3_BUCKET)" --region "$(AWS_REGION)" >/dev/null 2>&1 || true; \
	else \
		aws s3api create-bucket --bucket "$(S3_BUCKET)" --region "$(AWS_REGION)" --create-bucket-configuration LocationConstraint="$(AWS_REGION)" >/dev/null 2>&1 || true; \
	fi
	@aws s3api put-public-access-block --bucket "$(S3_BUCKET)" --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
	@aws s3api put-bucket-policy --bucket "$(S3_BUCKET)" --policy "$$(printf '{"Version":"2012-10-17","Statement":[{"Sid":"PublicReadGetObject","Effect":"Allow","Principal":"*","Action":["s3:GetObject"],"Resource":["arn:aws:s3:::%s/*"]}]}' "$(S3_BUCKET)")"
	@echo "Set MEDIA_STORAGE_PROVIDER=s3 AWS_S3_BUCKET=$(S3_BUCKET) AWS_REGION=$(AWS_REGION) AWS_S3_PREFIX=$(S3_PREFIX)"

s3-media-sync:
	@test -n "$(S3_BUCKET)" || (echo "Set S3_BUCKET=<bucket-name>" && exit 1)
	@command -v aws >/dev/null 2>&1 || (echo "AWS CLI is required" && exit 1)
	@aws s3 sync web/public/generated-media "s3://$(S3_BUCKET)/$(S3_PREFIX)/generated-media" --delete
	@aws s3 sync web/public/generated-audio/presynth "s3://$(S3_BUCKET)/$(S3_PREFIX)/generated-audio/presynth" --delete
	@echo "Synced generated-media + generated-audio/presynth to s3://$(S3_BUCKET)/$(S3_PREFIX)"

# Main target - build and deploy the app
deploy: archive export install
	@echo "✅ BabyKeyboardLock deployed successfully to /Applications/"


# Alias for deploy - update the installed app
update: deploy

# Clean build artifacts
clean:
	@./scripts/clean.sh

# Build archive
archive: clean
	@./scripts/archive.sh

# Export archive
export:
	@./scripts/export.sh

# Install to Applications folder
install:
	@./scripts/install.sh

help:
	@printf "make deploy\n"
	@printf "make update\n"
	@printf "make generate-images\n"
	@printf "make download-openimages\n"
	@printf "make dictionary-showcase\n"
	@printf "make web-install\n"
	@printf "make web-dev [WEB_PORT=3000]\n"
	@printf "make web-build\n"
	@printf "make web-start [WEB_PORT=3000]\n"
	@printf "make s3-bucket-setup S3_BUCKET=<bucket> [AWS_REGION=us-east-1] [S3_PREFIX=baby-keyboard]\n"
	@printf "make s3-media-sync S3_BUCKET=<bucket> [S3_PREFIX=baby-keyboard]\n"
