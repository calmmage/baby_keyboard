"""Vocabulary manager with pluggable LLM backends and single/batch modes.

Usage examples:
  uv run python -m scripts.vocabulary_manager single --spelling laugh --tasks meaning_keys
  uv run python -m scripts.vocabulary_manager single --spelling laugh --meaning-key laugh --tasks translations,definitions
  uv run python -m scripts.vocabulary_manager batch --items-file /tmp/words.json --tasks part_of_speech,translations
"""

from __future__ import annotations

import argparse
import json
import os
from abc import ABC, abstractmethod
from enum import StrEnum
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, Field, ValidationError, field_validator


class VocabularyMode(StrEnum):
    single = "single"
    batch = "batch"


class BackendKind(StrEnum):
    local = "local"
    cloud = "cloud"


class AugmentationTask(StrEnum):
    meaning_keys = "meaning_keys"
    part_of_speech = "part_of_speech"
    translations = "translations"
    definitions = "definitions"


SUPPORTED_POS = {"noun", "verb", "adjective", "adverb", "phrase", "other"}
DEFAULT_LANGUAGES = ["en", "ru", "de", "fr", "es", "it", "ja", "zh"]
TASKS_REQUIRING_MEANING_KEY = {AugmentationTask.translations, AugmentationTask.definitions}


class WordRequest(BaseModel):
    request_id: str | None = None
    spelling: str
    meaning_key: str | None = None
    source_language: str = "en"

    @field_validator("spelling")
    @classmethod
    def _validate_spelling(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("spelling cannot be empty")
        return cleaned

    @field_validator("meaning_key")
    @classmethod
    def _normalize_meaning_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None

    @field_validator("source_language")
    @classmethod
    def _normalize_language(cls, value: str) -> str:
        cleaned = value.strip().lower()
        if not cleaned:
            raise ValueError("source_language cannot be empty")
        return cleaned.split("-", 1)[0]


class MeaningKeySuggestion(BaseModel):
    meaning_key: str
    gloss: str
    confidence: float | None = None


class TranslationItem(BaseModel):
    language: str
    text: str


class DefinitionItem(BaseModel):
    language: str
    text: str


class WordAugmentation(BaseModel):
    request_id: str | None = None
    spelling: str
    meaning_key: str | None = None
    part_of_speech: Literal["noun", "verb", "adjective", "adverb", "phrase", "other"] | None = None
    meaning_key_suggestions: list[MeaningKeySuggestion] = Field(default_factory=list)
    translations: list[TranslationItem] = Field(default_factory=list)
    definitions: list[DefinitionItem] = Field(default_factory=list)


class BatchAugmentationResponse(BaseModel):
    items: list[WordAugmentation]


class LLMBackend(ABC):
    @abstractmethod
    def generate_json(self, *, system_prompt: str, user_prompt: str) -> dict[str, Any]:
        raise NotImplementedError


class LiteLLMBackend(LLMBackend):
    """Thin wrapper over litellm completion API.

    Works with local backends (e.g. ollama/*) and cloud models (OpenAI, Gemini, etc.)
    depending on the model name / credentials you pass in.
    """

    def __init__(
        self,
        *,
        model: str,
        temperature: float = 0.0,
        api_base: str | None = None,
        api_key: str | None = None,
        max_tokens: int | None = None,
    ) -> None:
        self.model = model
        self.temperature = temperature
        self.api_base = api_base
        self.api_key = api_key
        self.max_tokens = max_tokens

    def generate_json(self, *, system_prompt: str, user_prompt: str) -> dict[str, Any]:
        try:
            from litellm import completion  # type: ignore
        except ModuleNotFoundError as exc:
            raise RuntimeError("Missing dependency: litellm. Install with `uv add litellm`.") from exc

        kwargs: dict[str, Any] = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": self.temperature,
        }
        if self.api_base:
            kwargs["base_url"] = self.api_base
        if self.api_key:
            kwargs["api_key"] = self.api_key
        if self.max_tokens is not None:
            kwargs["max_tokens"] = self.max_tokens

        response = completion(**kwargs)
        content = self._extract_text(response)
        return _parse_json_object(content)

    def _extract_text(self, response: Any) -> str:
        choices = getattr(response, "choices", None)
        if choices is None and isinstance(response, dict):
            choices = response.get("choices")
        if not choices:
            raise RuntimeError("LLM response does not contain choices")

        message = getattr(choices[0], "message", None)
        if message is None and isinstance(choices[0], dict):
            message = choices[0].get("message")
        if message is None:
            raise RuntimeError("LLM response choice does not contain message")

        content = getattr(message, "content", None)
        if content is None and isinstance(message, dict):
            content = message.get("content")

        if isinstance(content, str):
            return content
        if isinstance(content, list):
            parts: list[str] = []
            for item in content:
                if isinstance(item, dict):
                    text = item.get("text")
                    if isinstance(text, str):
                        parts.append(text)
            merged = "\n".join(parts).strip()
            if merged:
                return merged
        raise RuntimeError("Unable to extract text content from LLM response")


class VocabularyManager:
    def __init__(self, backend: LLMBackend) -> None:
        self.backend = backend

    def suggest_meaning_keys(
        self,
        *,
        spelling: str,
        source_language: str = "en",
        max_suggestions: int = 5,
    ) -> list[MeaningKeySuggestion]:
        request = WordRequest(spelling=spelling, source_language=source_language)
        result = self.augment_single(
            request=request,
            tasks={AugmentationTask.meaning_keys},
            languages=[source_language],
            max_meaning_suggestions=max_suggestions,
        )
        return result.meaning_key_suggestions

    def infer_part_of_speech(
        self,
        *,
        spelling: str,
        meaning_key: str | None = None,
        source_language: str = "en",
    ) -> str | None:
        request = WordRequest(
            spelling=spelling,
            meaning_key=meaning_key,
            source_language=source_language,
        )
        result = self.augment_single(
            request=request,
            tasks={AugmentationTask.part_of_speech},
            languages=[source_language],
        )
        return result.part_of_speech

    def populate_translations(
        self,
        *,
        spelling: str,
        meaning_key: str,
        source_language: str = "en",
        languages: list[str] | None = None,
    ) -> list[TranslationItem]:
        request = WordRequest(
            spelling=spelling,
            meaning_key=meaning_key,
            source_language=source_language,
        )
        result = self.augment_single(
            request=request,
            tasks={AugmentationTask.translations},
            languages=_normalized_languages(languages or DEFAULT_LANGUAGES),
        )
        return result.translations

    def populate_definitions(
        self,
        *,
        spelling: str,
        meaning_key: str,
        source_language: str = "en",
        languages: list[str] | None = None,
    ) -> list[DefinitionItem]:
        request = WordRequest(
            spelling=spelling,
            meaning_key=meaning_key,
            source_language=source_language,
        )
        result = self.augment_single(
            request=request,
            tasks={AugmentationTask.definitions},
            languages=_normalized_languages(languages or DEFAULT_LANGUAGES),
        )
        return result.definitions

    def augment_single(
        self,
        *,
        request: WordRequest,
        tasks: set[AugmentationTask],
        languages: list[str],
        max_meaning_suggestions: int = 5,
    ) -> WordAugmentation:
        items = self.augment_batch(
            requests=[request],
            tasks=tasks,
            languages=languages,
            max_meaning_suggestions=max_meaning_suggestions,
        )
        return items[0]

    def augment_batch(
        self,
        *,
        requests: list[WordRequest],
        tasks: set[AugmentationTask],
        languages: list[str],
        max_meaning_suggestions: int = 5,
    ) -> list[WordAugmentation]:
        if not requests:
            raise ValueError("requests cannot be empty")
        if not tasks:
            raise ValueError("tasks cannot be empty")

        languages = _normalized_languages(languages)
        self._validate_meaning_key_requirements(requests=requests, tasks=tasks)

        payload = {
            "tasks": sorted(task.value for task in tasks),
            "languages": languages,
            "max_meaning_suggestions": max(1, max_meaning_suggestions),
            "words": [request.model_dump() for request in requests],
        }
        system_prompt = self._build_system_prompt()
        user_prompt = self._build_user_prompt(payload)
        raw = self.backend.generate_json(system_prompt=system_prompt, user_prompt=user_prompt)

        try:
            parsed = BatchAugmentationResponse.model_validate(raw)
        except ValidationError as exc:
            raise RuntimeError(f"LLM response validation failed: {exc}") from exc

        if len(parsed.items) != len(requests):
            raise RuntimeError(
                f"Expected {len(requests)} result items, got {len(parsed.items)}"
            )

        self._validate_output_shape(parsed.items, tasks=tasks, languages=languages)
        return parsed.items

    def _validate_meaning_key_requirements(
        self,
        *,
        requests: list[WordRequest],
        tasks: set[AugmentationTask],
    ) -> None:
        if not (tasks & TASKS_REQUIRING_MEANING_KEY):
            return
        missing: list[str] = []
        for request in requests:
            if request.meaning_key:
                continue
            label = request.request_id or request.spelling
            missing.append(label)
        if missing:
            raise ValueError(
                "meaning_key is required for translations/definitions. Missing for: "
                + ", ".join(missing)
            )

    def _validate_output_shape(
        self,
        items: list[WordAugmentation],
        *,
        tasks: set[AugmentationTask],
        languages: list[str],
    ) -> None:
        required_languages = set(languages)

        for item in items:
            if AugmentationTask.part_of_speech in tasks and item.part_of_speech is None:
                raise RuntimeError(f"Missing part_of_speech for '{item.spelling}'")
            if item.part_of_speech and item.part_of_speech not in SUPPORTED_POS:
                raise RuntimeError(
                    f"Invalid part_of_speech='{item.part_of_speech}' for '{item.spelling}'"
                )
            if AugmentationTask.meaning_keys in tasks and not item.meaning_key_suggestions:
                raise RuntimeError(f"Missing meaning_key_suggestions for '{item.spelling}'")
            if AugmentationTask.translations in tasks:
                got = {entry.language.lower() for entry in item.translations}
                missing = required_languages - got
                if missing:
                    raise RuntimeError(
                        f"Missing translation languages for '{item.spelling}': {sorted(missing)}"
                    )
            if AugmentationTask.definitions in tasks:
                got = {entry.language.lower() for entry in item.definitions}
                missing = required_languages - got
                if missing:
                    raise RuntimeError(
                        f"Missing definition languages for '{item.spelling}': {sorted(missing)}"
                    )

    def _build_system_prompt(self) -> str:
        return (
            "You are a multilingual vocabulary augmentation engine for a child-focused app.\n"
            "Return one JSON object only (no markdown, no extra text).\n"
            "Top-level shape: {\"items\": [...]}.\n"
            "Each item must include:\n"
            "- request_id (copy from input; can be null)\n"
            "- spelling\n"
            "- meaning_key (copy input if provided)\n"
            "- part_of_speech: one of noun|verb|adjective|adverb|phrase|other (or null if not requested)\n"
            "- meaning_key_suggestions: list (empty if not requested)\n"
            "- translations: list of {language,text} (empty if not requested)\n"
            "- definitions: list of {language,text} (empty if not requested)\n"
            "Rules:\n"
            "- Keep item order identical to input order.\n"
            "- If translations are requested, include every requested language exactly once.\n"
            "- If definitions are requested, include every requested language exactly once.\n"
            "- For nouns in de/fr/es/it, include definite article directly in translation text.\n"
            "- meaning_key_suggestions must be concise snake_case english keys with a short gloss.\n"
            "- Definitions must be natural, child-friendly, one sentence per language, not template placeholders.\n"
        )

    def _build_user_prompt(self, payload: dict[str, Any]) -> str:
        pretty = json.dumps(payload, ensure_ascii=False, indent=2)
        return (
            "Produce vocabulary augmentation for this request payload.\n"
            "If translations/definitions are requested, respect meaning_key exactly.\n"
            "Payload:\n"
            f"{pretty}"
        )


class CLIOutput(BaseModel):
    mode: VocabularyMode
    backend: BackendKind
    model: str
    tasks: list[str]
    languages: list[str]
    items: list[WordAugmentation]


def _normalize_task_token(raw: str) -> str:
    token = raw.strip().lower().replace("-", "_")
    alias_map = {
        "pos": "part_of_speech",
        "partofspeech": "part_of_speech",
        "meaning_key": "meaning_keys",
        "meaningkeys": "meaning_keys",
        "translation": "translations",
        "definition": "definitions",
    }
    return alias_map.get(token, token)


def _parse_tasks(raw: str) -> set[AugmentationTask]:
    tokens = [_normalize_task_token(token) for token in raw.split(",") if token.strip()]
    if not tokens:
        raise ValueError("tasks cannot be empty")
    if "all" in tokens:
        return {
            AugmentationTask.meaning_keys,
            AugmentationTask.part_of_speech,
            AugmentationTask.translations,
            AugmentationTask.definitions,
        }
    parsed: set[AugmentationTask] = set()
    for token in tokens:
        parsed.add(AugmentationTask(token))
    return parsed


def _normalized_languages(languages: list[str]) -> list[str]:
    normalized: list[str] = []
    seen: set[str] = set()
    for raw in languages:
        code = raw.strip().lower()
        if not code:
            continue
        code = code.split("-", 1)[0]
        if code in seen:
            continue
        normalized.append(code)
        seen.add(code)
    if not normalized:
        raise ValueError("languages cannot be empty")
    return normalized


def _parse_languages(raw: str) -> list[str]:
    return _normalized_languages(raw.split(","))


def _parse_json_object(raw: str) -> dict[str, Any]:
    text = raw.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        lines = lines[1:]
        if lines and lines[-1].strip().startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")
        if start == -1 or end == -1 or end <= start:
            raise RuntimeError("LLM response is not valid JSON object")
        parsed = json.loads(text[start : end + 1])

    if not isinstance(parsed, dict):
        raise RuntimeError("LLM response root must be a JSON object")
    return parsed


def _load_word_requests(path: Path) -> list[WordRequest]:
    raw = path.read_text(encoding="utf-8").strip()
    if not raw:
        raise ValueError(f"items file is empty: {path}")

    parsed_requests: list[WordRequest] = []

    if raw.startswith("["):
        payload = json.loads(raw)
        if not isinstance(payload, list):
            raise ValueError("batch file must be a JSON array or JSONL")
        for item in payload:
            if not isinstance(item, dict):
                raise ValueError("batch JSON array must contain objects")
            parsed_requests.append(WordRequest.model_validate(item))
        return parsed_requests

    for line_number, line in enumerate(raw.splitlines(), start=1):
        stripped = line.strip()
        if not stripped:
            continue
        obj = json.loads(stripped)
        if not isinstance(obj, dict):
            raise ValueError(f"line {line_number}: expected JSON object")
        parsed_requests.append(WordRequest.model_validate(obj))

    if not parsed_requests:
        raise ValueError(f"no requests found in {path}")
    return parsed_requests


def _build_backend(
    *,
    kind: BackendKind,
    model: str | None,
    api_base: str | None,
    api_key_env: str | None,
    temperature: float,
    max_tokens: int | None,
) -> tuple[LLMBackend, str]:
    default_model = {
        BackendKind.local: "ollama/qwen2.5:14b",
        BackendKind.cloud: "gpt-4o-mini",
    }[kind]
    chosen_model = (model or "").strip() or default_model

    api_key = None
    if api_key_env:
        api_key = os.getenv(api_key_env)
        if not api_key:
            raise RuntimeError(f"Environment variable '{api_key_env}' is not set")

    backend = LiteLLMBackend(
        model=chosen_model,
        temperature=temperature,
        api_base=(api_base or "").strip() or None,
        api_key=api_key,
        max_tokens=max_tokens,
    )
    return backend, chosen_model


def _write_output(out_path: Path | None, payload: dict[str, Any]) -> None:
    rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if out_path is None:
        print(rendered, end="")
        return
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(rendered, encoding="utf-8")
    print(f"wrote: {out_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Vocabulary manager (single + batch modes).")
    parser.add_argument(
        "--backend",
        choices=[item.value for item in BackendKind],
        default=BackendKind.cloud.value,
        help="Backend type. local=local LLM endpoint, cloud=hosted API model.",
    )
    parser.add_argument(
        "--model",
        default="",
        help="Model name passed to litellm (e.g. gpt-4o-mini, gemini/gemini-2.5-flash, ollama/qwen2.5:14b).",
    )
    parser.add_argument("--api-base", default="", help="Optional API base URL for backend.")
    parser.add_argument("--api-key-env", default="", help="Optional env var name containing API key.")
    parser.add_argument("--temperature", type=float, default=0.0, help="Sampling temperature.")
    parser.add_argument("--max-tokens", type=int, default=0, help="Optional max output tokens.")

    subparsers = parser.add_subparsers(dest="mode", required=True)

    single_parser = subparsers.add_parser("single", help="Single-word mode.")
    single_parser.add_argument("--spelling", required=True)
    single_parser.add_argument("--meaning-key", default="")
    single_parser.add_argument("--source-language", default="en")
    single_parser.add_argument(
        "--tasks",
        default="meaning_keys",
        help="Comma-separated: meaning_keys,part_of_speech,translations,definitions,all",
    )
    single_parser.add_argument(
        "--languages",
        default=",".join(DEFAULT_LANGUAGES),
        help="Comma-separated language codes for translations/definitions.",
    )
    single_parser.add_argument("--max-meaning-suggestions", type=int, default=5)
    single_parser.add_argument("--out", type=Path, default=None)

    batch_parser = subparsers.add_parser("batch", help="Multi-word batch mode.")
    batch_parser.add_argument(
        "--items-file",
        required=True,
        type=Path,
        help="JSON array or JSONL file with objects: {request_id?, spelling, meaning_key?, source_language?}.",
    )
    batch_parser.add_argument(
        "--tasks",
        default="part_of_speech,translations,definitions",
        help="Comma-separated: meaning_keys,part_of_speech,translations,definitions,all",
    )
    batch_parser.add_argument(
        "--languages",
        default=",".join(DEFAULT_LANGUAGES),
        help="Comma-separated language codes for translations/definitions.",
    )
    batch_parser.add_argument("--max-meaning-suggestions", type=int, default=5)
    batch_parser.add_argument("--out", type=Path, default=None)

    args = parser.parse_args()

    backend_kind = BackendKind(args.backend)
    backend, resolved_model = _build_backend(
        kind=backend_kind,
        model=args.model,
        api_base=args.api_base,
        api_key_env=(args.api_key_env or "").strip() or None,
        temperature=args.temperature,
        max_tokens=(args.max_tokens if args.max_tokens > 0 else None),
    )
    manager = VocabularyManager(backend=backend)

    if args.mode == VocabularyMode.single.value:
        request = WordRequest(
            spelling=args.spelling,
            meaning_key=(args.meaning_key.strip() or None),
            source_language=args.source_language,
        )
        tasks = _parse_tasks(args.tasks)
        languages = _parse_languages(args.languages)
        item = manager.augment_single(
            request=request,
            tasks=tasks,
            languages=languages,
            max_meaning_suggestions=args.max_meaning_suggestions,
        )
        output = CLIOutput(
            mode=VocabularyMode.single,
            backend=backend_kind,
            model=resolved_model,
            tasks=sorted(task.value for task in tasks),
            languages=languages,
            items=[item],
        )
        _write_output(args.out, output.model_dump())
        return 0

    if args.mode == VocabularyMode.batch.value:
        requests = _load_word_requests(args.items_file)
        tasks = _parse_tasks(args.tasks)
        languages = _parse_languages(args.languages)
        items = manager.augment_batch(
            requests=requests,
            tasks=tasks,
            languages=languages,
            max_meaning_suggestions=args.max_meaning_suggestions,
        )
        output = CLIOutput(
            mode=VocabularyMode.batch,
            backend=backend_kind,
            model=resolved_model,
            tasks=sorted(task.value for task in tasks),
            languages=languages,
            items=items,
        )
        _write_output(args.out, output.model_dump())
        return 0

    raise RuntimeError(f"Unsupported mode: {args.mode}")


if __name__ == "__main__":
    raise SystemExit(main())
