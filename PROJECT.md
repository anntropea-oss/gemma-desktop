# Gemma Desktop Project

## Goal

Build a local-first macOS desktop app for chatting with `gemma4:latest` through Ollama, with optional user-approved context from GitHub repositories or local folders.

## Current Status

- Local Gemma model: `gemma4:latest`
- Local runtime: Ollama at `http://127.0.0.1:11434`
- Main deliverable: `outputs/Gemma Desktop.app`
- Source: `src/GemmaDesktop.swift`
- Build script: `scripts/build-desktop-app.sh`
- App metadata template: `packaging/GemmaDesktop-Info.plist`

## Features

- Native SwiftUI macOS desktop window
- Local Ollama chat through `/api/generate`
- Longer local-model timeout
- Empty-response error handling
- GitHub repo loading via shallow `git clone`
- Local folder loading via macOS folder picker
- Readable text/code indexing with ignored build/dependency directories
- Local source metadata for repo size and Git-tracked file counts
- Prompt-time snippet selection for relevant repo/folder context
- Detailed Ollama HTTP error messages
- Local file bridge for external tools such as Codex

## Known Boundaries

- Gemma runs locally, but it does not directly browse the filesystem.
- The app reads only a GitHub repo it clones or a local folder the user selects.
- Repo/folder context is snippet-based, not a full semantic index.
- Codex Desktop's model picker does not currently list local Ollama models.

## Next Improvements

- Add visible list of indexed files.
- Add a clear/unload source button.
- Add progress reporting while indexing larger folders.
- Persist recent repo and folder choices.
- Improve retrieval with chunking and better scoring.
- Add app icon and packaging polish.
- Add a richer bridge API or signed localhost endpoint.
