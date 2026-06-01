# Gemma Desktop Project

## Goal

Build a local-first macOS desktop app for chatting with `gemma4:latest` through Ollama, with optional user-approved context from GitHub repositories or local folders.

## Current Status

- Default local Gemma model: `gemma4:latest`
- Local runtime: Ollama at `http://127.0.0.1:11434`
- Main deliverable: `outputs/Gemma Desktop.app`
- Source: `src/*.swift`
- Build script: `scripts/build-desktop-app.sh`
- App metadata template: `packaging/GemmaDesktop-Info.plist`

## Features

- Native SwiftUI macOS desktop window
- Streaming local Ollama chat through `/api/generate`
- Configurable model, Ollama URL, timeout, and token limit
- Stop/cancel support for long local generations
- Empty-response error handling
- GitHub repo loading via shallow `git clone`
- Branch/tag/ref loading and private repo support through local Git credentials
- Local folder loading via macOS folder picker
- Readable text/code indexing with chunking and ignored build/dependency directories
- Local source metadata for repo size and Git-tracked file counts
- Prompt-time snippet selection for relevant repo/folder context
- Visible context panel for indexed files and selected snippets
- Detailed Ollama HTTP error messages
- Queued local file bridge for external tools such as Codex
- Source indexer smoke tests

## Known Boundaries

- Gemma runs locally, but it does not directly browse the filesystem.
- The app reads only a GitHub repo it clones or a local folder the user selects.
- Repo/folder context is chunked keyword retrieval, not a full semantic index.
- Codex Desktop's model picker does not currently list local Ollama models.

## Next Improvements

- Add progress reporting while indexing larger folders.
- Persist recent repo and folder choices.
- Improve retrieval with embeddings or a proper semantic index.
- Add a signed localhost endpoint for richer app automation.
- Add app notarization/package export.
