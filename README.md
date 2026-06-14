# Gemma Desktop

This project builds a local-first macOS desktop app for using local Ollama models such as `gemma4:latest`. It supports streaming chat, GitHub repo loading, user-approved local folder loading, visible source context, and a file bridge for Codex.

## Quick Start

Double-click the desktop app:

```text
outputs/Gemma Desktop.app
```

Or use the browser-based fallback:

```text
outputs/Gemma Chat.app
```

Build the desktop app from source:

```sh
./scripts/build-desktop-app.sh
```

Run an interactive prompt:

```sh
python3 gemma.py
```

Ask one question:

```sh
python3 gemma.py "Write a three-line haiku about local models."
```

Use Ollama directly:

```sh
ollama run gemma4:latest
```

Start a Codex CLI session using local Gemma:

```sh
codex -p ollama-launch -C /path/to/gemma-desktop
```

Run a one-off Codex CLI task using local Gemma:

```sh
codex exec --skip-git-repo-check -p ollama-launch -C /path/to/gemma-desktop "Reply with one sentence."
```

## Current Local Model

The local Ollama model currently available here is:

```text
gemma4:latest
```

It is served by Ollama at:

```text
http://127.0.0.1:11434
```

## Project Structure

```text
src/*.swift                     Native SwiftUI app source
scripts/build-desktop-app.sh    Build script for the desktop app
outputs/Gemma Desktop.app       Built macOS app
gemma.py                        Small terminal fallback
tests/run-unit-tests.sh         Source indexer smoke tests
PROJECT.md                      Project goals, status, and next work
SOLUTIONS.md                    Issue and fix log
```

## Useful Commands

List local models:

```sh
ollama list
```

Pull or refresh Gemma:

```sh
ollama pull gemma4:latest
```

Check that Ollama is responding:

```sh
curl -s http://127.0.0.1:11434/api/tags
```

Run the smoke tests:

```sh
./tests/run-unit-tests.sh
```

## Codex Model Picker

The Codex Desktop model picker lists OpenAI-hosted Codex models from your Codex account. Local Ollama models can be used from the Codex CLI with the `ollama-launch` profile, but they do not currently appear in this Desktop thread's OpenAI model list.

When Codex CLI starts with `gemma4:latest`, it may show:

```text
Model metadata for `gemma4:latest` not found. Defaulting to fallback metadata.
```

That warning is expected for this local Ollama model. A simple interactive prompt has been verified to return a response through Gemma.

For a non-terminal experience, use `outputs/Gemma Desktop.app`. It is a native SwiftUI macOS app. The browser-based fallback is `outputs/Gemma Chat.app`.

## Loading A GitHub Repo

In `Gemma Desktop.app`:

1. Paste a public GitHub repo URL into the repo field.
2. Click `Load Repo`.
3. Ask questions about the repo in the chat box.

The app performs a shallow local `git clone`, indexes readable text/code files, and sends the most relevant snippets to local Gemma with each question. It also keeps basic local metadata, so questions like `how big is this repo?` and `how many files are in it?` can be answered directly from the cloned repo.

The optional `branch/tag` field lets you load a specific branch, tag, or ref. Private repos can work when your local Git installation already has credentials for that remote.

## Loading Local Files

In `Gemma Desktop.app`:

1. Click `Choose Folder`.
2. Pick a local folder or repo you want the app to read.
3. Ask questions about that folder in the chat box.

Gemma does not directly browse your Mac. The desktop app reads only the folder you choose, indexes readable text/code files, chunks larger text files, and sends relevant snippets to local Gemma. The context panel shows indexed files and the snippets selected for the last prompt.

## Settings

Open `Settings` in the app to:

- Refresh local Ollama models from `/api/tags`
- Pick the model
- Change the Ollama base URL
- Adjust timeout and response token limits

The prompt button changes to `STOP` while Gemma is streaming, so long local requests can be canceled.

Code-review prompts get a little extra guardrail: the app asks Ollama for final-answer output instead of hidden reasoning, uses a larger default response budget, and retries once when a review response is empty or too short to be useful.

## Codex Bridge

When `Gemma Desktop.app` is running, it creates a local file bridge at:

```text
~/Library/Application Support/Gemma Desktop/Bridge
```

Bridge files:

```text
requests/*.json    Queue prompts into the app
responses/*.json   Read per-request bridge responses
inbox.json         Legacy single-prompt input, still supported
messages.json      Read the current app transcript
status.json        Read app/model/source status
```

Send a prompt through the bridge:

```sh
mkdir -p "$HOME/Library/Application Support/Gemma Desktop/Bridge"
bridge="$HOME/Library/Application Support/Gemma Desktop/Bridge"
mkdir -p "$bridge/requests"
id="request-$(date +%s)"
created="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '{"id":"%s","prompt":"Say hello from the bridge.","createdAt":"%s"}\n' "$id" "$created" > "$bridge/requests/$id.json"
```

Prompts sent through the bridge appear in the app transcript as `Codex`. Prompts typed directly in the app appear as `You`.

Read the response or transcript:

```sh
cat "$HOME/Library/Application Support/Gemma Desktop/Bridge/responses/$id.json"
cat "$HOME/Library/Application Support/Gemma Desktop/Bridge/messages.json"
```
