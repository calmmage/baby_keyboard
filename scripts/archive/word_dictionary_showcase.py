"""Prototype: word dictionary showcase with annotations.

Usage:
  uv run python -m scripts.word_dictionary_showcase --lang en,ru --limit 20
  uv run python -m scripts.word_dictionary_showcase --lang en --pos noun,verb --limit 50
  uv run python -m scripts.word_dictionary_showcase --lang en --complexity common,medium
  uv run python -m scripts.word_dictionary_showcase --lang en --min-zipf 4.0 --limit 100
  uv run python -m scripts.word_dictionary_showcase --mode definition --lang en --limit 30 --format table
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from typing import Iterable, List, Optional, Sequence


@dataclass(frozen=True)
class WordRecord:
    language: str
    word: str
    pos: str
    zipf: float
    complexity: str
    definition: str
    definition_alt: str
    definition_source: str


POS_ALIASES = {
    "noun": "noun",
    "n": "noun",
    "verb": "verb",
    "v": "verb",
    "adj": "adj",
    "adjective": "adj",
    "a": "adj",
    "adv": "adv",
    "adverb": "adv",
    "r": "adv",
}

DEFAULT_STOPWORDS = {
    "en": {
        "a", "about", "above", "after", "again", "against", "all", "am", "an", "and", "any",
        "are", "aren't", "as", "at", "be", "because", "been", "before", "being", "below",
        "between", "both", "but", "by", "can", "can't", "cannot", "could", "couldn't", "did",
        "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during", "each", "few",
        "for", "from", "further", "had", "hadn't", "has", "hasn't", "have", "haven't",
        "having", "he", "he'd", "he'll", "he's", "her", "here", "here's", "hers", "herself",
        "him", "himself", "his", "how", "how's", "i", "i'd", "i'll", "i'm", "i've", "if",
        "in", "into", "is", "isn't", "it", "it's", "its", "itself", "let's", "me", "more",
        "most", "mustn't", "my", "myself", "no", "nor", "not", "of", "off", "on", "once",
        "only", "or", "other", "ought", "our", "ours", "ourselves", "out", "over", "own",
        "same", "she", "she'd", "she'll", "she's", "should", "shouldn't", "so", "some",
        "such", "than", "that", "that's", "the", "their", "theirs", "them", "themselves",
        "then", "there", "there's", "these", "they", "they'd", "they'll", "they're",
        "they've", "this", "those", "through", "to", "too", "under", "until", "up", "very",
        "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were", "weren't", "what",
        "what's", "when", "when's", "where", "where's", "which", "while", "who", "who's",
        "whom", "why", "why's", "with", "won't", "would", "wouldn't", "you", "you'd",
        "you'll", "you're", "you've", "your", "yours", "yourself", "yourselves", "one",
        "will", "shall", "may", "might", "must", "do", "does", "did", "have", "has", "had",
        "be", "been", "being", "am", "is", "are", "was", "were",
        "us", "now", "just", "even", "much",
    },
    "ru": {
        "и", "в", "во", "не", "что", "он", "на", "я", "с", "со", "как", "а", "то", "все",
        "она", "так", "его", "но", "да", "ты", "к", "у", "же", "вы", "за", "бы", "по", "только",
    },
}

AUXILIARY_VERBS = {
    "be", "am", "is", "are", "was", "were", "been", "being",
    "have", "has", "had",
    "do", "does", "did",
    "will", "would", "shall", "should", "can", "could", "may", "might", "must",
}

MODE_DICTIONARY = "dictionary"
MODE_DEFINITION = "definition"


def _normalize_list(value: str | None) -> List[str]:
    if not value:
        return []
    return [chunk.strip().lower() for chunk in value.split(",") if chunk.strip()]


def _complexity_from_zipf(zipf: float) -> str:
    if zipf >= 5.0:
        return "common"
    if zipf >= 3.5:
        return "medium"
    return "rare"


def _load_wordfreq():
    try:
        import wordfreq  # type: ignore
    except ModuleNotFoundError:
        return None
    return wordfreq


def _load_wordnet():
    try:
        import nltk  # type: ignore
        from nltk.corpus import wordnet as wn  # type: ignore
    except ModuleNotFoundError:
        return None
    try:
        _ = wn.synsets("test")
    except LookupError:
        return "missing-corpus"
    return wn


def _load_stopwords(lang: str) -> set[str]:
    try:
        from nltk.corpus import stopwords  # type: ignore
    except ModuleNotFoundError:
        return DEFAULT_STOPWORDS.get(lang, set())
    try:
        return set(stopwords.words(lang))
    except LookupError:
        return DEFAULT_STOPWORDS.get(lang, set())


def _load_pymorphy():
    try:
        import pymorphy3  # type: ignore
    except ModuleNotFoundError:
        return None
    return pymorphy3


def _wordnet_pos(pos: str) -> str:
    if pos in ("n", "noun"):
        return "noun"
    if pos in ("v", "verb"):
        return "verb"
    if pos in ("a", "s", "adj", "adjective"):
        return "adj"
    if pos in ("r", "adv", "adverb"):
        return "adv"
    return "unknown"


def _pos_from_wordnet(word: str, wn, allowed_pos: Sequence[str]) -> str:
    synsets = wn.synsets(word)
    if not synsets:
        return "unknown"
    if "verb" in allowed_pos and word.lower() in AUXILIARY_VERBS:
        return "verb"
    scores = {}
    for syn in synsets:
        pos = _wordnet_pos(syn.pos())
        lemma_score = sum(lemma.count() for lemma in syn.lemmas()) or 1
        scores[pos] = scores.get(pos, 0) + lemma_score
    if allowed_pos:
        filtered = {pos: score for pos, score in scores.items() if pos in allowed_pos}
        if filtered:
            best = max(filtered.items(), key=lambda item: item[1])
            return best[0]
    pos_priority = {"verb": 0, "noun": 1, "adj": 2, "adv": 3, "unknown": 9}
    best = max(scores.items(), key=lambda item: (item[1], -pos_priority.get(item[0], 9)))
    return best[0]


def _definition_from_wordnet(
    word: str,
    wn,
    allowed_pos: Sequence[str],
    preferred_pos: str,
) -> tuple[str, str, str]:
    synsets = wn.synsets(word)
    if not synsets:
        return "", "", ""
    if allowed_pos:
        synsets = [syn for syn in synsets if _wordnet_pos(syn.pos()) in allowed_pos]
        if not synsets:
            return "", "", ""
    if preferred_pos and preferred_pos != "unknown":
        preferred = [syn for syn in synsets if _wordnet_pos(syn.pos()) == preferred_pos]
        if preferred:
            synsets = preferred
    best_syn = max(synsets, key=lambda syn: sum(lemma.count() for lemma in syn.lemmas()) or 0)
    alt_definition = ""
    for syn in synsets:
        if syn == best_syn:
            continue
        alt_definition = syn.definition()
        break
    return best_syn.definition(), alt_definition, "wordnet"


def _pos_from_pymorphy(word: str, analyzer) -> str:
    parses = analyzer.parse(word)
    if not parses:
        return "unknown"
    tag = parses[0].tag.POS or ""
    if tag == "NOUN":
        return "noun"
    if tag == "VERB" or tag == "INFN":
        return "verb"
    if tag == "ADJF" or tag == "ADJS":
        return "adj"
    if tag == "ADVB":
        return "adv"
    return "unknown"


def _build_words(lang: str, pool_size: int) -> List[str]:
    wordfreq = _load_wordfreq()
    if wordfreq is None:
        raise SystemExit("missing dependency: wordfreq")
    return wordfreq.top_n_list(lang, pool_size)


def _record_for_word(
    lang: str,
    word: str,
    wordfreq,
    wn,
    pymorphy,
    allowed_pos: Sequence[str],
) -> WordRecord:
    zipf = 0.0
    definition = ""
    definition_alt = ""
    definition_source = ""
    pos = "unknown"

    if wordfreq is not None:
        zipf = float(wordfreq.zipf_frequency(word, lang))

    if lang == "en" and wn not in (None, "missing-corpus"):
        pos = _pos_from_wordnet(word, wn, allowed_pos)
        definition, definition_alt, definition_source = _definition_from_wordnet(
            word, wn, allowed_pos, pos
        )
    elif lang == "ru" and pymorphy is not None:
        analyzer = pymorphy.MorphAnalyzer()
        pos = _pos_from_pymorphy(word, analyzer)

    complexity = _complexity_from_zipf(zipf)
    return WordRecord(
        language=lang,
        word=word,
        pos=pos,
        zipf=zipf,
        complexity=complexity,
        definition=definition,
        definition_alt=definition_alt,
        definition_source=definition_source,
    )


def _passes_filters(
    record: WordRecord,
    allowed_pos: Sequence[str],
    allowed_complexity: Sequence[str],
    min_zipf: Optional[float],
    max_zipf: Optional[float],
) -> bool:
    if allowed_pos and record.pos not in allowed_pos:
        return False
    if record.pos == "adj" and "quantifier" in record.definition.lower():
        return False
    if allowed_complexity and record.complexity not in allowed_complexity:
        return False
    if min_zipf is not None and record.zipf < min_zipf:
        return False
    if max_zipf is not None and record.zipf > max_zipf:
        return False
    return True


def _format_record(record: WordRecord, fmt: str, mode: str) -> str:
    if mode == MODE_DEFINITION:
        payload = {
            "language": record.language,
            "word": record.word,
            "pos": record.pos,
            "definition": record.definition,
            "definition_alt": record.definition_alt,
            "definition_source": record.definition_source,
            "zipf": round(record.zipf, 2),
            "complexity": record.complexity,
        }
        if fmt == "jsonl":
            return json.dumps(payload, ensure_ascii=False)
        if fmt == "tsv":
            return "\t".join(
                [
                    payload["language"],
                    payload["word"],
                    payload["pos"],
                    payload["definition"],
                    payload["definition_alt"],
                    payload["definition_source"],
                    f"{record.zipf:.2f}",
                    payload["complexity"],
                ]
            )
        return ",".join(
            [
                payload["language"],
                payload["word"],
                payload["pos"],
                payload["definition"].replace(",", " "),
                payload["definition_alt"].replace(",", " "),
                payload["definition_source"],
                f"{record.zipf:.2f}",
                payload["complexity"],
            ]
        )

    if fmt == "jsonl":
        return json.dumps(record.__dict__, ensure_ascii=False)
    if fmt == "tsv":
        return "\t".join(
            [
                record.language,
                record.word,
                record.pos,
                f"{record.zipf:.2f}",
                record.complexity,
                record.definition,
                record.definition_alt,
                record.definition_source,
            ]
        )
    return ",".join(
        [
            record.language,
            record.word,
            record.pos,
            f"{record.zipf:.2f}",
            record.complexity,
            record.definition.replace(",", " "),
            record.definition_alt.replace(",", " "),
            record.definition_source,
        ]
    )


def _has_any_definition(record: WordRecord) -> bool:
    return bool(record.definition.strip() or record.definition_alt.strip())


def main() -> None:
    parser = argparse.ArgumentParser(description="Word dictionary showcase.")
    parser.add_argument("--lang", default="en", help="comma list: en,ru,de,fr")
    parser.add_argument(
        "--mode",
        choices=[MODE_DICTIONARY, MODE_DEFINITION],
        default=MODE_DICTIONARY,
        help="output mode",
    )
    parser.add_argument("--pos", help="comma list: noun,verb,adj,adv")
    parser.add_argument("--complexity", help="comma list: common,medium,rare")
    parser.add_argument("--min-zipf", type=float)
    parser.add_argument("--max-zipf", type=float)
    parser.add_argument("--pool-size", type=int, default=5000)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--format", choices=["csv", "tsv", "jsonl", "table"], default="csv")
    parser.add_argument(
        "--include-empty-definitions",
        action="store_true",
        help="only for --mode definition; include words with no definition",
    )
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--include-stopwords", action="store_true")
    parser.add_argument("--allow-numeric", action="store_true")
    args = parser.parse_args()

    langs = _normalize_list(args.lang) or ["en"]
    pos_filters = [POS_ALIASES.get(p, p) for p in _normalize_list(args.pos)]
    if not pos_filters:
        pos_filters = ["noun", "verb", "adj"]
    complexity_filters = _normalize_list(args.complexity)

    wordfreq = _load_wordfreq()
    wn = _load_wordnet()
    pymorphy = _load_pymorphy()

    if wordfreq is None:
        raise SystemExit("missing dependency: wordfreq (uv add wordfreq)")

    if wn == "missing-corpus":
        print("missing nltk wordnet corpus: uv run python -m nltk.downloader wordnet")
        wn = None

    if args.summary:
        for lang in langs:
            words = _build_words(lang, args.pool_size)
            print(f"lang={lang} pool={args.pool_size} words={len(words)}")
        return

    if args.format == "csv":
        if args.mode == MODE_DEFINITION:
            print("language,word,pos,definition,definition_alt,definition_source,zipf,complexity")
        else:
            print("language,word,pos,zipf,complexity,definition,definition_alt,definition_source")

    emitted = 0
    table = None
    if args.format == "table":
        try:
            from rich.table import Table
            from rich.console import Console
        except ModuleNotFoundError as exc:
            raise SystemExit("missing dependency: rich (uv add rich)") from exc
        table = Table(show_lines=False)
        table.add_column("lang", style="cyan", no_wrap=True)
        table.add_column("word", style="bold")
        table.add_column("pos")
        if args.mode == MODE_DEFINITION:
            table.add_column("definition")
            table.add_column("also")
            table.add_column("source")
            table.add_column("zipf", justify="right")
            table.add_column("complexity")
        else:
            table.add_column("zipf", justify="right")
            table.add_column("complexity")
            table.add_column("definition")
            table.add_column("also")
            table.add_column("source")
        console = Console()

    for lang in langs:
        words = _build_words(lang, args.pool_size)
        stopwords = set()
        if not args.include_stopwords:
            stopwords = _load_stopwords(lang)
        for word in words:
            if stopwords and word.lower() in stopwords:
                continue
            if not args.allow_numeric and any(ch.isdigit() for ch in word):
                continue
            record = _record_for_word(lang, word, wordfreq, wn, pymorphy, pos_filters)
            if not _passes_filters(
                record,
                pos_filters,
                complexity_filters,
                args.min_zipf,
                args.max_zipf,
            ):
                continue
            if args.mode == MODE_DEFINITION and not args.include_empty_definitions and not _has_any_definition(record):
                continue
            if table is not None:
                if args.mode == MODE_DEFINITION:
                    table.add_row(
                        record.language,
                        record.word,
                        record.pos,
                        record.definition,
                        record.definition_alt,
                        record.definition_source,
                        f"{record.zipf:.2f}",
                        record.complexity,
                    )
                else:
                    table.add_row(
                        record.language,
                        record.word,
                        record.pos,
                        f"{record.zipf:.2f}",
                        record.complexity,
                        record.definition,
                        record.definition_alt,
                        record.definition_source,
                    )
            else:
                print(_format_record(record, args.format, args.mode))
            emitted += 1
            if emitted >= args.limit:
                if table is not None:
                    console.print(table)
                return

    if table is not None:
        console.print(table)


if __name__ == "__main__":
    main()
