#!/usr/bin/env python3

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import error, request


API_BASE_URLS = {
    "beijing": "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/customization",
    "singapore": "https://dashscope-intl.aliyuncs.com/api/v1/services/audio/asr/customization",
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Manage DashScope ASR hotword vocabularies from a local JSON file."
    )
    parser.add_argument(
        "action",
        choices=["validate", "sync", "create", "update", "list", "query", "delete"],
        help="Operation to execute.",
    )
    parser.add_argument(
        "config",
        nargs="?",
        default="config/hotwords/voicevibe.fun-asr.json",
        help="Path to the hotword config JSON file.",
    )
    parser.add_argument(
        "--vocabulary-id",
        help="Override the vocabulary ID from local state.",
    )
    parser.add_argument(
        "--page-size",
        type=int,
        default=100,
        help="Page size when listing remote vocabularies.",
    )
    parser.add_argument(
        "--page-index",
        type=int,
        default=0,
        help="Page index when listing remote vocabularies.",
    )
    parser.add_argument(
        "--clear-state",
        action="store_true",
        help="Clear local state after a successful delete.",
    )
    args = parser.parse_args()

    config_path = Path(args.config).resolve()
    config = load_config(config_path)
    state_path = local_state_path(config_path)
    state = load_json_if_exists(state_path)

    if args.action == "validate":
        print(
            json.dumps(
                {
                    "config": str(config_path),
                    "state": str(state_path),
                    "entry_count": len(config["entries"]),
                    "prefix": config["prefix"],
                    "target_model": config["target_model"],
                    "region": config["region"],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    api_key = os.environ.get("DASHSCOPE_API_KEY")
    if not api_key:
        raise SystemExit("DASHSCOPE_API_KEY is not set in the environment.")

    region = config["region"]
    base_url = API_BASE_URLS[region]

    if args.action == "sync":
        vocabulary_id = resolve_vocabulary_id(args.vocabulary_id, state)
        if vocabulary_id:
            response = call_api(
                api_key,
                base_url,
                {
                    "model": "speech-biasing",
                    "input": {
                        "action": "update_vocabulary",
                        "vocabulary_id": vocabulary_id,
                        "vocabulary": config["entries"],
                    },
                },
            )
            save_state(
                state_path,
                config,
                vocabulary_id,
                len(config["entries"]),
            )
            print_summary("updated", vocabulary_id, config, response, state_path)
            return 0

        response = call_api(
            api_key,
            base_url,
            {
                "model": "speech-biasing",
                "input": {
                    "action": "create_vocabulary",
                    "target_model": config["target_model"],
                    "prefix": config["prefix"],
                    "vocabulary": config["entries"],
                },
            },
        )
        vocabulary_id = find_vocabulary_id(response)
        if not vocabulary_id:
            raise SystemExit(f"Create succeeded but no vocabulary_id was found: {json.dumps(response, ensure_ascii=False)}")
        save_state(
            state_path,
            config,
            vocabulary_id,
            len(config["entries"]),
        )
        print_summary("created", vocabulary_id, config, response, state_path)
        return 0

    if args.action == "create":
        response = call_api(
            api_key,
            base_url,
            {
                "model": "speech-biasing",
                "input": {
                    "action": "create_vocabulary",
                    "target_model": config["target_model"],
                    "prefix": config["prefix"],
                    "vocabulary": config["entries"],
                },
            },
        )
        vocabulary_id = find_vocabulary_id(response)
        if not vocabulary_id:
            raise SystemExit(f"Create succeeded but no vocabulary_id was found: {json.dumps(response, ensure_ascii=False)}")
        save_state(
            state_path,
            config,
            vocabulary_id,
            len(config["entries"]),
        )
        print_summary("created", vocabulary_id, config, response, state_path)
        return 0

    if args.action == "update":
        vocabulary_id = require_vocabulary_id(args.vocabulary_id, state)
        response = call_api(
            api_key,
            base_url,
            {
                "model": "speech-biasing",
                "input": {
                    "action": "update_vocabulary",
                    "vocabulary_id": vocabulary_id,
                    "vocabulary": config["entries"],
                },
            },
        )
        save_state(
            state_path,
            config,
            vocabulary_id,
            len(config["entries"]),
        )
        print_summary("updated", vocabulary_id, config, response, state_path)
        return 0

    if args.action == "list":
        response = call_api(
            api_key,
            base_url,
            {
                "model": "speech-biasing",
                "input": {
                    "action": "list_vocabulary",
                    "prefix": config["prefix"],
                    "page_index": args.page_index,
                    "page_size": args.page_size,
                },
            },
        )
        print(json.dumps(response, ensure_ascii=False, indent=2))
        return 0

    if args.action == "query":
        vocabulary_id = require_vocabulary_id(args.vocabulary_id, state)
        response = call_api(
            api_key,
            base_url,
            {
                "model": "speech-biasing",
                "input": {
                    "action": "query_vocabulary",
                    "vocabulary_id": vocabulary_id,
                },
            },
        )
        print(json.dumps(response, ensure_ascii=False, indent=2))
        return 0

    if args.action == "delete":
        vocabulary_id = require_vocabulary_id(args.vocabulary_id, state)
        response = call_api(
            api_key,
            base_url,
            {
                "model": "speech-biasing",
                "input": {
                    "action": "delete_vocabulary",
                    "vocabulary_id": vocabulary_id,
                },
            },
        )
        if args.clear_state:
            clear_state(state_path)
        print_summary("deleted", vocabulary_id, config, response, state_path)
        return 0

    raise SystemExit(f"Unsupported action: {args.action}")


def load_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"Config file not found: {path}")

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc

    prefix = str(data.get("prefix", "")).strip()
    if not prefix:
        raise SystemExit("Config must define a non-empty 'prefix'.")

    target_model = str(data.get("target_model", "")).strip()
    if not target_model:
        raise SystemExit("Config must define a non-empty 'target_model'.")

    region = str(data.get("region", "beijing")).strip().lower()
    if region not in API_BASE_URLS:
        raise SystemExit(f"Unsupported region '{region}'. Expected one of: {', '.join(sorted(API_BASE_URLS))}")

    raw_entries = data.get("entries")
    if not isinstance(raw_entries, list) or not raw_entries:
        raise SystemExit("Config must define a non-empty 'entries' array.")

    entries: list[dict[str, Any]] = []
    seen: set[tuple[str, str | None]] = set()
    for index, raw_entry in enumerate(raw_entries):
        if not isinstance(raw_entry, dict):
            raise SystemExit(f"Entry #{index + 1} must be an object.")

        text = str(raw_entry.get("text", "")).strip()
        if not text:
            raise SystemExit(f"Entry #{index + 1} must define a non-empty 'text'.")

        weight = raw_entry.get("weight", 4)
        if not isinstance(weight, int):
            raise SystemExit(f"Entry #{index + 1} has non-integer 'weight'.")

        lang_value = raw_entry.get("lang")
        lang = str(lang_value).strip() if lang_value is not None else None

        dedupe_key = (text, lang)
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)

        entry = {"text": text, "weight": weight}
        if lang:
            entry["lang"] = lang
        entries.append(entry)

    return {
        "prefix": prefix,
        "target_model": target_model,
        "region": region,
        "entries": entries,
    }


def local_state_path(config_path: Path) -> Path:
    return config_path.parent.parent.parent / ".hotwords" / f"{config_path.stem}.state.json"


def load_json_if_exists(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in state file {path}: {exc}") from exc


def save_state(path: Path, config: dict[str, Any], vocabulary_id: str, entry_count: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "vocabulary_id": vocabulary_id,
        "prefix": config["prefix"],
        "target_model": config["target_model"],
        "region": config["region"],
        "entry_count": entry_count,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def clear_state(path: Path) -> None:
    if path.exists():
        path.unlink()


def resolve_vocabulary_id(cli_value: str | None, state: dict[str, Any] | None) -> str | None:
    if cli_value:
        return cli_value.strip()
    if state and isinstance(state.get("vocabulary_id"), str):
        return state["vocabulary_id"].strip()
    return None


def require_vocabulary_id(cli_value: str | None, state: dict[str, Any] | None) -> str:
    vocabulary_id = resolve_vocabulary_id(cli_value, state)
    if not vocabulary_id:
        raise SystemExit(
            "No vocabulary_id available. Pass --vocabulary-id or run 'sync'/'create' first to create local state."
        )
    return vocabulary_id


def call_api(api_key: str, url: str, payload: dict[str, Any]) -> Any:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = request.Request(
        url=url,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with request.urlopen(req) as response:
            raw_body = response.read().decode("utf-8")
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"DashScope API error {exc.code}: {body}") from exc
    except error.URLError as exc:
        raise SystemExit(f"DashScope API connection failed: {exc.reason}") from exc

    if not raw_body.strip():
        return {}
    try:
        return json.loads(raw_body)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"DashScope API returned non-JSON response: {raw_body}") from exc


def find_vocabulary_id(payload: Any) -> str | None:
    if isinstance(payload, dict):
        vocabulary_id = payload.get("vocabulary_id")
        if isinstance(vocabulary_id, str) and vocabulary_id.strip():
            return vocabulary_id.strip()
        for value in payload.values():
            nested = find_vocabulary_id(value)
            if nested:
                return nested
    elif isinstance(payload, list):
        for item in payload:
            nested = find_vocabulary_id(item)
            if nested:
                return nested
    return None


def print_summary(
    action: str,
    vocabulary_id: str,
    config: dict[str, Any],
    response: Any,
    state_path: Path,
) -> None:
    print(
        json.dumps(
            {
                "action": action,
                "vocabulary_id": vocabulary_id,
                "prefix": config["prefix"],
                "target_model": config["target_model"],
                "region": config["region"],
                "entry_count": len(config["entries"]),
                "state_file": str(state_path),
                "response": response,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    sys.exit(main())
