#!/usr/bin/env python3
import argparse
import json
import sys
import urllib.error
import urllib.request


OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
DEFAULT_MODEL = "gemma4:latest"


def generate(prompt: str, model: str) -> str:
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
    }
    request = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise SystemExit(
            "Could not reach Ollama at 127.0.0.1:11434. "
            "Start Ollama, then try again."
        ) from exc

    if "error" in body:
        raise SystemExit(f"Ollama error: {body['error']}")

    return body.get("response", "")


def interactive(model: str) -> None:
    print(f"Using {model}. Press Ctrl-D to exit.")
    while True:
        try:
            prompt = input("\nYou> ").strip()
        except EOFError:
            print()
            return

        if not prompt:
            continue

        print("\nGemma>", generate(prompt, model).strip())


def main() -> None:
    parser = argparse.ArgumentParser(description="Ask local Gemma through Ollama.")
    parser.add_argument("prompt", nargs="*", help="Prompt to send to Gemma.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Ollama model name.")
    args = parser.parse_args()

    if args.prompt:
        print(generate(" ".join(args.prompt), args.model).strip())
    else:
        interactive(args.model)


if __name__ == "__main__":
    main()
