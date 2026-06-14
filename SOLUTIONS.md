## [2026-05-30 10:52] Non-Interactive Ollama Run Hung
- Problem: `ollama run gemma4:latest "Reply with one short sentence confirming you are running locally."` displayed only terminal spinner output and did not return a usable response in the non-interactive shell session.
- Root Cause: Unknown
- Solution: Stopped the hanging `ollama run` attempt and used Ollama's HTTP API at `127.0.0.1:11434` for scripted local Gemma access.
- Files Changed: `README.md`, `gemma.py`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Confirmed `curl -s http://127.0.0.1:11434/api/generate ...` returned `local gemma ok` from `gemma4:latest`.

## [2026-05-30 11:38] Gemma Script Run From Home Directory
- Problem: Running `python3 gemma.py` from `~` failed with `can't open file '~/gemma.py': [Errno 2] No such file or directory`.
- Root Cause: The terminal was in the home directory (`~`), but `gemma.py` is located in `<workspace>`.
- Solution: Use the script from its workspace directory or run it by absolute path.
- Files Changed: `SOLUTIONS.md`
- Status: Resolved
- Verification: Confirmed the workspace path containing `gemma.py` is `<workspace>`.

## [2026-05-30 11:41] Gemma Not Visible In Codex Desktop Model Picker
- Problem: `gemma4:latest` is available in local Ollama but does not appear in the Codex Desktop model picker for this thread; a first Codex CLI profile test also failed outside a Git repository, then failed because the Ollama profile required `OLLAMA_API_KEY`. After removing the key requirement, the Codex CLI profile loaded but the agent turn did not return promptly.
- Root Cause: The Codex Desktop model picker is populated from the OpenAI model list for the active `openai` provider. The local Ollama Codex profile also included `env_key = "OLLAMA_API_KEY"`, which made Codex require an unnecessary environment variable for local Ollama.
- Solution: Documented the Codex CLI launch commands for the local Ollama profile and removed the unnecessary `env_key` from `~/.codex/ollama-launch.config.toml`.
- Files Changed: `README.md`, `SOLUTIONS.md`, `~/.codex/ollama-launch.config.toml`
- Status: Open
- Verification: Re-ran Codex CLI with `--skip-git-repo-check -p ollama-launch`; the profile loaded `model: gemma4:latest` and `provider: ollama-local`, but the test turn was stopped after it produced no response within the test window.

## [2026-05-30 11:45] Invalid Interactive Codex Flag
- Problem: Running `codex --skip-git-repo-check -p ollama-launch -C <workspace>` failed with `error: unexpected argument '--skip-git-repo-check' found`.
- Root Cause: `--skip-git-repo-check` is accepted by `codex exec`, but not by the top-level interactive `codex` command.
- Solution: Updated the interactive Codex CLI command in `README.md` to remove `--skip-git-repo-check`; kept that flag only on the `codex exec` example.
- Files Changed: `README.md`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Checked `codex --help` and `codex exec --help`; only `codex exec` lists `--skip-git-repo-check`.

## [2026-05-30 11:49] Missing Codex Metadata For Gemma
- Problem: Starting an interactive Codex session with `gemma4:latest` showed `Model metadata for gemma4:latest not found. Defaulting to fallback metadata; this can degrade performance and cause issues.`
- Root Cause: Codex does not have built-in model metadata for the local Ollama model name `gemma4:latest`.
- Solution: Confirmed Codex CLI can still respond through `gemma4:latest` despite the warning; documented the warning as expected behavior for this local Ollama model.
- Files Changed: `README.md`, `SOLUTIONS.md`
- Status: Workaround
- Verification: User screenshot showed Codex CLI running `model: gemma4:latest` and responding `Hello! How can I help you today?` after the prompt `say hello in one sentence`.

## [2026-05-30 11:53] Gemma Ignored Codex Workspace Task
- Problem: In Codex CLI with `gemma4:latest`, the prompt `Read README.md and tell me what commands I should use to run local Gemma here.` returned a generic assistant greeting instead of reading the workspace file or answering the task.
- Root Cause: Unknown; likely local Gemma is not reliably following Codex's agent/tool-use instructions with the fallback model metadata.
- Solution: No fix applied yet. Recommended treating `gemma4:latest` as usable for local chat, while using OpenAI-hosted Codex models for reliable workspace-aware agent tasks.
- Files Changed: `SOLUTIONS.md`
- Status: Open
- Verification: User reproduced the generic response in the interactive `codex -p ollama-launch` session.

## [2026-05-30 11:55] User Does Not Want Terminal Gemma Workflow
- Problem: The confirmed local Gemma workflow required Terminal commands, but the user does not want to run Gemma in Terminal.
- Root Cause: Codex Desktop does not expose local Ollama models in its model picker, and the initial working Gemma interface was command-line only.
- Solution: Created a double-clickable local `Gemma Chat.app` bundle that starts a browser chat UI and proxies requests to Ollama on `127.0.0.1`.
- Files Changed: `outputs/Gemma Chat.app/Contents/Info.plist`, `outputs/Gemma Chat.app/Contents/MacOS/Gemma Chat`, `outputs/Gemma Chat.app/Contents/Resources/server.py`, `README.md`, `SOLUTIONS.md`
- Status: Workaround
- Verification: Confirmed the local server health endpoint returned `ok`, the browser UI loaded at `http://127.0.0.1:8765`, and a browser-submitted prompt returned `browser gemma works`.

## [2026-05-30 11:55] Gemma Chat App Verification Hiccups
- Problem: During verification, directly executing `outputs/Gemma Chat.app/Contents/Resources/server.py` failed with `permission denied`, and a browser test helper call failed because `locator.waitFor` required an explicit state.
- Root Cause: The server script had not yet been marked executable, and the browser verification used an incomplete wait call.
- Solution: Marked both the app launcher and server script executable, then verified the UI using a DOM snapshot polling check instead.
- Files Changed: `outputs/Gemma Chat.app/Contents/MacOS/Gemma Chat`, `outputs/Gemma Chat.app/Contents/Resources/server.py`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Confirmed `browser gemma works` appeared in the browser UI after submitting a prompt.

## [2026-05-30 11:59] Browser UI Is Not Desktop App
- Problem: The `Gemma Chat.app` workaround opened a browser page, but the user wants a desktop app instead of a browser.
- Root Cause: The first no-terminal workaround was implemented as a local web UI opened by a `.app` launcher.
- Solution: Created `outputs/Gemma Desktop.app`, a double-clickable macOS app using Tkinter that opens its own desktop window and talks directly to local Ollama.
- Files Changed: `outputs/Gemma Desktop.app/Contents/Info.plist`, `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`, `outputs/Gemma Desktop.app/Contents/Resources/gemma_desktop.py`, `README.md`, `SOLUTIONS.md`
- Status: Workaround
- Verification: Confirmed Tkinter is available, the app module imports with `MODEL = gemma4:latest`, Ollama returned `desktop gemma path works`, `open outputs/Gemma Desktop.app` exited successfully, and a `Gemma Desktop` process was running afterward.

## [2026-05-30 12:02] Gemma Desktop Opened Blank Window
- Problem: `Gemma Desktop.app` launched but displayed an almost entirely blank white window with only a scrollbar visible.
- Root Cause: The Tkinter-based app rendered poorly in the launched macOS app window, even after simplifying the Tk layout.
- Solution: Replaced the Tkinter app with a native SwiftUI macOS app compiled into `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`.
- Files Changed: `work/native-gemma/GemmaDesktop.swift`, `outputs/Gemma Desktop.app/Contents/Info.plist`, `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`, `outputs/Gemma Desktop.app/Contents/Resources/gemma_desktop.py`, `README.md`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Compiled the SwiftUI app to a Mach-O arm64 executable, relaunched `outputs/Gemma Desktop.app`, and confirmed a new `Gemma Desktop` process was running.

## [2026-05-30 12:05] SwiftUI Build Needed Parse-As-Library
- Problem: Building the SwiftUI app with `swiftc work/native-gemma/GemmaDesktop.swift -o ...` failed with `'main' attribute cannot be used in a module that contains top-level code`.
- Root Cause: The direct Swift compiler invocation needed `-parse-as-library` for the `@main` SwiftUI app entry point.
- Solution: Rebuilt with `swiftc -parse-as-library work/native-gemma/GemmaDesktop.swift -o outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`.
- Files Changed: `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`, `SOLUTIONS.md`
- Status: Resolved
- Verification: The rebuild completed successfully and `file outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop` reports a `Mach-O 64-bit executable arm64`.

## [2026-05-30 12:09] Gemma Desktop Request Timed Out
- Problem: In `Gemma Desktop.app`, asking `can you read a git repo if I paste the link here` displayed `The request timed out.`
- Root Cause: The SwiftUI app used the default URLSession timeout and did not bound Ollama response length, which can be too aggressive for local model generation.
- Solution: Set explicit 300-second request timeout, 600-second resource timeout, bounded Ollama generation with `num_predict = 512`, and added a clearer timeout error message.
- Files Changed: `work/native-gemma/GemmaDesktop.swift`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Rebuilt `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop` successfully as a Mach-O arm64 executable and relaunched the app.

## [2026-05-30 12:11] Gemma Desktop Could Not Read Pasted Repo Links
- Problem: `Gemma Desktop.app` could chat with local Gemma, but it had no way to read a GitHub repository from a pasted link.
- Root Cause: The app only sent plain user prompts to Ollama and did not clone, index, or provide repository file context to Gemma.
- Solution: Added a repo URL field, `Load Repo` button, shallow `git clone`, readable text/code file indexer, prompt-time snippet selection, and README usage instructions.
- Files Changed: `work/native-gemma/GemmaDesktop.swift`, `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`, `README.md`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Rebuilt the native app successfully as a Mach-O arm64 executable and verified `git clone --depth 1 https://github.com/octocat/Hello-World.git` works locally.

## [2026-05-30 12:18] Gemma Claimed It Was Remote
- Problem: In `Gemma Desktop.app`, Gemma answered that it was running on remote servers and could not access local files, which contradicted the local Ollama setup and confused the user.
- Root Cause: The app did not include an instruction clarifying that Gemma is running locally through Ollama while still lacking direct filesystem access unless the app provides file or repo snippets.
- Solution: Added a base instruction to every prompt explaining the local Ollama runtime and the actual file-access boundary; updated the app's initial message to match; added empty-response handling so the app shows a useful error if Gemma burns its token budget without visible text.
- Files Changed: `work/native-gemma/GemmaDesktop.swift`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Rebuilt the native app successfully as a Mach-O arm64 executable.

## [2026-05-30 12:20] Gemma Needed User-Granted Local Folder Access
- Problem: The user wanted to give Gemma permission to access local files, but the app only supported typed chat and GitHub repo loading.
- Root Cause: Local Gemma cannot directly browse the filesystem; the desktop app needed a user-approved folder picker and local file indexer path.
- Solution: Added a `Choose Folder` button using macOS `NSOpenPanel`, indexed readable text/code files from the selected folder, and included relevant snippets in future Gemma prompts.
- Files Changed: `work/native-gemma/GemmaDesktop.swift`, `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`, `README.md`, `SOLUTIONS.md`
- Status: Resolved
- Verification: Rebuilt `Gemma Desktop.app` successfully after adding the AppKit folder picker.

## [2026-05-30 12:23] Workspace Was Still Experiment-Shaped
- Problem: The chat had produced a working app, but the workspace was still organized as experiment artifacts: Swift source lived under `work/`, there was no build script, no project status file, and stale Tkinter resources remained in the app bundle.
- Root Cause: The app evolved through several prototypes before being promoted into a project.
- Solution: Promoted Swift source to `src/GemmaDesktop.swift`, added `scripts/build-desktop-app.sh`, added `PROJECT.md`, updated `README.md`, added `.gitignore`, and prepared to remove obsolete Tkinter bundle resources.
- Files Changed: `.gitignore`, `PROJECT.md`, `README.md`, `SOLUTIONS.md`, `scripts/build-desktop-app.sh`, `src/GemmaDesktop.swift`, `outputs/Gemma Desktop.app/Contents/Resources/gemma_desktop.py`, `outputs/Gemma Desktop.app/Contents/Resources/__pycache__/gemma_desktop.cpython-311.pyc`
- Status: Resolved
- Verification: Removed the stale Tkinter bundle resources and confirmed `./scripts/build-desktop-app.sh` successfully rebuilds `outputs/Gemma Desktop.app`.

## [2026-05-30 12:24] Project Needed Git History
- Problem: The project files and logs existed in the workspace, but the folder was not initialized as a Git repository.
- Root Cause: The work started as a projectless Codex chat and had not yet been promoted to version control.
- Solution: Initialize a Git repository, stage source/docs/logs/app files, and create an initial commit.
- Files Changed: `.git/`, `SOLUTIONS.md`
- Status: Resolved
- Verification: `git init` succeeded and `git status --short` showed the project files staged, including `SOLUTIONS.md`.

## [2026-05-30 12:25] Git Used Auto-Detected Committer Identity
- Problem: The initial commit succeeded, but Git warned that the committer identity was auto-detected from the local machine.
- Root Cause: Git user name/email were not explicitly configured for this repository before the first commit.
- Solution: Logged the warning. No identity change was applied because the commit succeeded and the user did not specify a preferred Git identity.
- Files Changed: `SOLUTIONS.md`
- Status: Open
- Verification: The warning appeared during `git commit -m "Initial Gemma Desktop project"`.

## [2026-05-30 12:28] Connected Repo To GitHub Account
- Problem: The local Git repo was not connected to the user's GitHub account and had no remote.
- Root Cause: The repository had just been initialized locally and had not yet been associated with a GitHub remote.
- Solution: Confirmed GitHub CLI authentication, configured local Git identity with a GitHub-provided commit email, created a private GitHub repo, added it as `origin`, and pushed `main`.
- Files Changed: `.git/config`, `SOLUTIONS.md`
- Status: Resolved
- Verification: `git remote -v` showed `origin` set to the GitHub repo, and `git status --short --branch` showed `main...origin/main`.

## [2026-05-30 12:32] User Could Not See GitHub Repo
- Problem: The user reported not seeing the newly created GitHub repository.
- Root Cause: The repository existed but was private; the user may have been viewing a different GitHub account or filtering to public repositories.
- Solution: Verified the repository with GitHub CLI and confirmed the direct URL, private visibility, and admin permission for the authenticated account.
- Files Changed: `SOLUTIONS.md`
- Status: Open
- Verification: `gh repo view ... --json nameWithOwner,visibility,url,viewerPermission,isPrivate` returned private visibility and admin permission for the authenticated account.

## [2026-05-30 12:36] Public Repo Readiness Issues
- Problem: A public-readiness review found machine-specific paths in docs/logs and a compiled app binary tracked in Git.
- Root Cause: The repository was created from an active local experiment, so it included generated artifacts and detailed troubleshooting logs.
- Solution: Replaced local absolute paths and hostname-derived details with generic placeholders, moved the app plist to `packaging/GemmaDesktop-Info.plist`, updated the build script to generate the app bundle, ignored `outputs/`, and removed the built app bundle from Git tracking.
- Files Changed: `.gitignore`, `PROJECT.md`, `README.md`, `SOLUTIONS.md`, `packaging/GemmaDesktop-Info.plist`, `scripts/build-desktop-app.sh`, `outputs/Gemma Desktop.app/Contents/Info.plist`, `outputs/Gemma Desktop.app/Contents/MacOS/Gemma Desktop`
- Status: Resolved
- Verification: `./scripts/build-desktop-app.sh` rebuilt the ignored app bundle successfully; tracked-file scan no longer shows raw local absolute paths or tokens in the current tree.

## [2026-05-30 12:37] Public Exposure Remains In Git History
- Problem: Even after cleaning the current tree, earlier private commits still contain the previously tracked app binary and unsanitized local troubleshooting details.
- Root Cause: The cleanup happened after the initial commits and push, so sensitive or noisy details remain reachable through Git history until history is rewritten.
- Solution: No history rewrite applied yet; recommendation is to keep the repository private unless/until the history is squashed or rewritten to a clean public baseline.
- Files Changed: `SOLUTIONS.md`
- Status: Open
- Verification: Reviewed the current commit history and confirmed earlier commits predate the public-readiness cleanup.

## [2026-05-30 15:30] Public Baseline Commit Needed
- Problem: The repo was ready in the current working tree, but the pushed history still contained old experiment commits with generated artifacts and noisier setup details.
- Root Cause: The repository was originally pushed before the public-readiness cleanup.
- Solution: Prepare a single clean baseline commit from the sanitized current tree, then force-push `main` so the public repo history starts from that baseline.
- Files Changed: `SOLUTIONS.md`, Git history
- Status: Resolved
- Verification: Clean tracked-file scan passed before the rewrite; final verification is `git log --oneline` showing one baseline commit after force push.

## [2026-05-30 15:32] First Public Baseline Rewrite Attempt Was Not Orphaned
- Problem: The first history rewrite command hit Git's local-change checkout guard before switching to an orphan branch, then created and pushed a normal commit on top of the existing history.
- Root Cause: `SOLUTIONS.md` had uncommitted changes when `git switch --orphan public-baseline` was attempted, and the following commands continued in the existing `main` branch.
- Solution: Logged the failed attempt and retried from a clean tree using an orphan branch.
- Files Changed: `SOLUTIONS.md`, Git history
- Status: Resolved
- Verification: `git log --oneline` still showed the earlier commits after the first attempt, confirming the history had not yet been rewritten.

## [2026-05-30 15:33] Orphan Branch Retry Cleared Index
- Problem: The orphan-branch retry left the repository with tracked files marked as deleted instead of creating the intended baseline commit.
- Root Cause: The orphan branch/index state did not contain the expected tracked paths after the cached index was cleared.
- Solution: Restored the tracked files from `HEAD` and switched to a safer root-commit rewrite using `git commit-tree`.
- Files Changed: Git index
- Status: Resolved
- Verification: `git checkout HEAD -- ...` restored the tracked project files and `git ls-files` again listed the expected source, docs, packaging, and script files.

## [2026-05-30 15:35] Made GitHub Repo Public
- Problem: The repository was still private after being cleaned and rewritten to a public-ready baseline.
- Root Cause: It was initially created as private for safety during setup.
- Solution: Changed the GitHub repository visibility to public using GitHub CLI with the required visibility-change acknowledgement flag.
- Files Changed: GitHub repository settings, `SOLUTIONS.md`
- Status: Resolved
- Verification: `gh repo view --json nameWithOwner,visibility,url,isPrivate` returned `visibility: PUBLIC` and `isPrivate: false`.

## [2026-05-31 10:38] Codex Project Registry Was Cached
- Problem: Creating a new project-scoped Codex thread for the Gemma Desktop workspace failed with `Unknown projectId`, even though the workspace is trusted in Codex config.
- Root Cause: The folder was not in Codex Desktop's saved workspace roots, and after adding it to the saved workspace state, the running Codex app tool still used a cached project list.
- Solution: Added the workspace to Codex Desktop's saved workspace roots as `Gemma Desktop`, renamed this thread to `Gemma Desktop Project`, and pinned it as the project home thread. A Codex app refresh/restart may be required before the app tool recognizes the newly saved project for project-scoped thread creation.
- Files Changed: `~/.codex/.codex-global-state.json`, `SOLUTIONS.md`
- Status: Workaround
- Verification: The saved-state update printed `saved ... as Gemma Desktop`; this thread was renamed and pinned successfully, but `create_thread` still reported the old cached project list.

## [2026-05-31 10:42] Codex CLI Opened Workspace But Did Not Save Project
- Problem: Running `codex app <workspace>` opened the Gemma Desktop workspace but still did not make it appear in Codex Desktop's saved Projects list.
- Root Cause: The public CLI supports opening a workspace path, but no supported CLI/app-server API was found for saving a workspace root into the Desktop Projects sidebar. Direct edits to `.codex-global-state.json` are overwritten by the running app state.
- Solution: Treat project registration as a Desktop UI action: use Codex Desktop's Add/Open Project flow and choose the Gemma Desktop workspace folder. Keep this pinned thread as the project home until the UI registration is complete.
- Files Changed: `SOLUTIONS.md`
- Status: Open
- Verification: `codex app <workspace>` printed `Opening workspace ...`, but `electron-saved-workspace-roots` still did not include the workspace afterward; app-server schema search did not reveal a saved-project registration method.

## [2026-05-31 11:10] Codex Could Not Communicate With Gemma Desktop App
- Problem: Codex could talk to Ollama directly, but not to the running `Gemma Desktop.app` UI/state.
- Root Cause: The desktop app had no bridge, transcript file, or automation endpoint.
- Solution: Added a local file bridge under `~/Library/Application Support/Gemma Desktop/Bridge` with `inbox.json` for prompts, `messages.json` for transcript export, and `status.json` for app status.
- Files Changed: `README.md`, `PROJECT.md`, `SOLUTIONS.md`, `src/GemmaDesktop.swift`
- Status: Resolved
- Verification: Rebuilt and launched `Gemma Desktop.app`; writing `{"prompt":"Reply exactly: appear bridge works"}` to `inbox.json` produced a user message and a Gemma reply of `appear bridge works` in `messages.json`.

## [2026-05-31 11:18] Bridge Polling Did Not Start From Model Initializer
- Problem: The first bridge implementation wrote `status.json` and `messages.json`, but did not consume `inbox.json`.
- Root Cause: Polling started from the model initializer with `Timer`/SwiftUI task approaches that did not reliably fire in the packaged app lifecycle.
- Solution: Started bridge polling from the visible SwiftUI view's `onAppear` using a retained `DispatchSourceTimer` on the main queue.
- Files Changed: `src/GemmaDesktop.swift`, `SOLUTIONS.md`
- Status: Resolved
- Verification: After rebuilding, the app consumed `inbox.json`, updated `status.json` to `Gemma is thinking`, and wrote the Gemma response to `messages.json`.

## [2026-05-31 11:18] App Relaunch Hit LaunchServices Timing Error
- Problem: Immediately after killing the old app process, `open outputs/Gemma Desktop.app` returned `_LSOpenURLsWithCompletionHandler() failed with error -600`.
- Root Cause: LaunchServices was not ready to reopen the app immediately after process termination.
- Solution: Relaunched with `open -n outputs/Gemma Desktop.app` after rebuilding.
- Files Changed: `SOLUTIONS.md`
- Status: Workaround
- Verification: `open -n` launched the app and bridge files appeared under `~/Library/Application Support/Gemma Desktop/Bridge`.

## [2026-05-31 11:20] Bridge Prompts Were Labeled As You
- Problem: Prompts sent by Codex through the file bridge appeared in the app transcript as `You`, making them hard to distinguish from prompts typed by the user directly in the app.
- Root Cause: The app used the same `sendPrompt` path and hard-coded `speaker: "You"` for all user-side prompts.
- Solution: Added a `speaker` parameter to `sendPrompt`; direct app prompts remain labeled `You`, while bridge prompts are labeled `Codex`.
- Files Changed: `README.md`, `SOLUTIONS.md`, `src/GemmaDesktop.swift`
- Status: Resolved
- Verification: Rebuilt and relaunched the app; a bridge prompt appeared in `messages.json` with `speaker: "Codex"` and Gemma replied `codex label works`.

## [2026-05-31 11:24] App Needed Terminal/Codex Visual Design
- Problem: The native app worked but looked plain and did not reflect the requested terminal/Codex mashup aesthetic.
- Root Cause: The original SwiftUI layout used default light system styling and simple message cards.
- Solution: Added a dark terminal-inspired theme, Codex-like status chrome, monospace accents, distinct `Codex`/`You`/`Gemma` message treatments, styled source controls, and a darker composer surface.
- Files Changed: `SOLUTIONS.md`, `src/GemmaDesktop.swift`
- Status: Resolved
- Verification: `./scripts/build-desktop-app.sh` completed successfully and a bridge smoke test returned `restyle bridge ok`.

## [2026-05-31 11:25] Native Window Chrome Did Not Match App Interior
- Problem: The app's native macOS titlebar/toolbar still looked like default system chrome while the internal app UI used a dark terminal/Codex theme.
- Root Cause: The SwiftUI content was styled, but the containing `NSWindow` titlebar and background were left at default system styling.
- Solution: Added an AppKit app delegate that hides the title text, makes the titlebar transparent, uses compact unified toolbar chrome, sets a dark window background, enables dragging by background, and extends content into the titlebar.
- Files Changed: `SOLUTIONS.md`, `src/GemmaDesktop.swift`
- Status: Resolved
- Verification: Rebuilt and relaunched `Gemma Desktop.app`; a bridge smoke test returned `toolbar style ok`.

## [2026-05-31 11:30] App Icon Still Used Default Placeholder
- Problem: The Dock/app switcher icon still showed the default macOS app placeholder instead of matching the terminal/Codex internal style.
- Root Cause: The app bundle did not define `CFBundleIconFile` or include a generated `.icns` icon.
- Solution: Added a Swift/AppKit icon generator, wired the build script to create `GemmaDesktop.icns`, and set `CFBundleIconFile` in the app plist template.
- Files Changed: `SOLUTIONS.md`, `packaging/GemmaDesktop-Info.plist`, `scripts/build-desktop-app.sh`, `scripts/generate-app-icon.swift`
- Status: Resolved
- Verification: Rebuilt the app; `GemmaDesktop.icns` was generated in `Contents/Resources`, `CFBundleIconFile` resolves to `GemmaDesktop`, and the app relaunched successfully.

## [2026-06-01 09:09] Repo Size Question Returned Opaque Ollama Error
- Problem: After loading `https://github.com/anntropea-oss/fantasybaseball`, asking `how big is this repo` showed only `Ollama returned HTTP 500.` in `Gemma Desktop.app`.
- Root Cause: The app sent simple source-metadata questions through the local model instead of answering from the cloned repo data it already had, and the Ollama HTTP error handler discarded the response body that could explain failures.
- Solution: Added cached source metadata for local disk size and Git-tracked file count, short-circuited repo size/file-count questions with a local answer, included source metadata in model prompts, and surfaced Ollama error details when HTTP errors occur.
- Files Changed: `README.md`, `PROJECT.md`, `SOLUTIONS.md`, `src/GemmaDesktop.swift`
- Status: Resolved
- Verification: Rebuilt `outputs/Gemma Desktop.app` successfully and relaunched it; a bridge smoke test returned `patched app alive`.

## [2026-06-01 09:42] Hardening Review Found Operational Risks
- Problem: A review of `Gemma Desktop.app` found likely future usability and reliability risks: bridge prompts use a single `inbox.json` and can be overwritten while Gemma is busy; long Ollama requests cannot be canceled; cloned repos accumulate in the temporary cache; repo/folder indexing silently skips large files, many files, unsupported extensions, and later chunks; the UI does not show which files/snippets Gemma actually saw; local folder size scanning can traverse large dependency directories; and the model name/Ollama URL are hard-coded.
- Root Cause: The app was built as a focused local prototype with minimal state, a single active request, simple keyword retrieval, fixed model configuration, and no explicit context-management UI.
- Solution: No code fix applied yet. Recommended next work is to add a real request queue, stop/cancel support, source cache cleanup, visible indexed-file/snippet panels, better chunking/retrieval, configurable model/Ollama settings, and safer folder indexing limits.
- Files Changed: `SOLUTIONS.md`
- Status: Open
- Verification: Static review of `src/GemmaDesktop.swift`, `README.md`, `PROJECT.md`, build script, and packaging files.

## [2026-06-01 09:58] Hardening Pass Implemented
- Problem: The review risks made the app fragile for day-to-day use: no queued bridge, no stop button, hidden context selection, hard-coded Ollama settings, temporary repo buildup, and all app logic concentrated in one Swift file.
- Root Cause: The first desktop app was optimized for quickly proving local Gemma could work, not for sustained repo-analysis workflows.
- Solution: Split the Swift app into focused components, added streaming generation with Stop support, added configurable Ollama/model settings loaded from `/api/tags`, replaced the bridge with queued request/response files while keeping legacy `inbox.json`, added context visibility for indexed files and selected snippets, added source clear/cache cleanup, added branch/tag repo loading, improved chunked source retrieval, and documented the new workflow.
- Files Changed: `README.md`, `PROJECT.md`, `SOLUTIONS.md`, `scripts/build-desktop-app.sh`, `src/AppTheme.swift`, `src/ChatModel.swift`, `src/ContentView.swift`, `src/FileBridge.swift`, `src/GemmaDesktopApp.swift`, `src/Models.swift`, `src/OllamaClient.swift`, `src/SourceIndexer.swift`, `src/GemmaDesktop.swift`, `tests/SourceIndexerSmokeTests.swift`, `tests/run-unit-tests.sh`
- Status: Resolved
- Verification: `./scripts/build-desktop-app.sh` completed successfully; queued bridge smoke test returned `queued bridge streaming ok`.

## [2026-06-01 09:58] Source Indexer Test Exposed Path Normalization Bug
- Problem: The new source-indexer smoke test failed because `README.md` was not found under the expected relative path.
- Root Cause: macOS temporary paths can appear as both `/var/...` and `/private/var/...`; the indexer used plain string replacement against the original root path, so relative paths could retain unexpected absolute path pieces.
- Solution: Normalized both root and file URLs with `resolvingSymlinksInPath()` before computing relative source paths.
- Files Changed: `SOLUTIONS.md`, `src/SourceIndexer.swift`, `tests/SourceIndexerSmokeTests.swift`, `tests/run-unit-tests.sh`
- Status: Resolved
- Verification: `./tests/run-unit-tests.sh` passed and `./scripts/build-desktop-app.sh` completed successfully afterward.

## [2026-06-01 09:59] Minimum macOS Version Was Too Low For Streaming
- Problem: The app package still advertised macOS 10.15 support even after adding streaming generation through modern `URLSession` async APIs.
- Root Cause: The plist version metadata was left over from the initial app bundle and was not updated when the networking implementation changed.
- Solution: Raised `LSMinimumSystemVersion` to `12.0`.
- Files Changed: `SOLUTIONS.md`, `packaging/GemmaDesktop-Info.plist`
- Status: Resolved
- Verification: Rebuilt the app after the plist update.

## [2026-06-01 10:02] Bridge Queue Needed More Forgiving Request Handling
- Problem: Queued bridge requests originally required `id` and `createdAt`, and malformed request JSON could remain in the queue and repeatedly produce bridge errors. A shell verification command also failed to find a successful response because it did not handle the space in `Application Support`.
- Root Cause: The first queued bridge schema was stricter than the legacy `inbox.json` format, and the verification command used path-unsafe `xargs`.
- Solution: Made queued bridge request IDs and timestamps optional with generated defaults, removed malformed queue files after reporting the decode error, and reran verification with null-delimited path handling.
- Files Changed: `SOLUTIONS.md`, `src/FileBridge.swift`, `src/Models.swift`
- Status: Resolved
- Verification: Rebuilt and relaunched the app; a prompt-only queued request returned `prompt only bridge ok` in `responses/*.json`.

## [2026-06-04 09:30] Bridge Requests Not Processed From Codex
- Problem: Codex wrote both queued `requests/*.json` and documented `inbox.json` bridge prompts while `Gemma Desktop.app` and Ollama were running, but no matching response file or `messages.json` transcript update appeared within 20 seconds.
- Root Cause: The running app/source state was inconsistent: bridge requests were not being consumed, source inspection found unresolved conflict markers around `BridgeRequest` in `src/Models.swift`, and the build script had drifted away from the current multi-file Swift layout.
- Solution: Restored the tracked Swift bridge source layout, removed unresolved conflict markers from `src/Models.swift`, repaired the build script to compile `src/*.swift`, rebuilt `outputs/Gemma Desktop.app`, relaunched the app, and retested the queued request bridge.
- Files Changed: `SOLUTIONS.md`, `src/Models.swift`, `src/ChatModel.swift`, `src/ContentView.swift`, `src/FileBridge.swift`, `src/OllamaClient.swift`, `src/SourceIndexer.swift`, `scripts/build-desktop-app.sh`, `outputs/Gemma Desktop.app`
- Status: Resolved
- Verification: `scripts/build-desktop-app.sh` built successfully; relaunched `Gemma Desktop.app`; writing `requests/codex-ping-1780580349.json` produced `responses/codex-ping-1780580349.json` with `ok: true` and `text: "hello codex bridge ok"`; `messages.json` showed the prompt labeled `Codex` and Gemma's reply.

## [2026-06-04 09:47] Dirty Docs Regressed Hardened App Documentation
- Problem: Uncommitted changes in `README.md`, `PROJECT.md`, `SOLUTIONS.md`, and `packaging/GemmaDesktop-Info.plist` partially rolled the repository documentation and package metadata back to the pre-hardening app shape: single `src/GemmaDesktop.swift`, legacy `inbox.json` bridge only, no streaming/settings/context panel/test docs, removed hardening log entries, and macOS minimum lowered from `12.0` to `10.15`.
- Root Cause: Unknown. The source files matched the hardened multi-file app layout, but the dirty docs/plist edits did not match that source state.
- Solution: Restored `README.md`, `PROJECT.md`, `packaging/GemmaDesktop-Info.plist`, and the prior `SOLUTIONS.md` hardening entries from the last good commit, then re-added the June 4 bridge incident as a separate log entry.
- Files Changed: `README.md`, `PROJECT.md`, `SOLUTIONS.md`, `packaging/GemmaDesktop-Info.plist`
- Status: Resolved
- Verification: `git diff -- README.md PROJECT.md packaging/GemmaDesktop-Info.plist` is empty; `find src -maxdepth 1 -type f` shows the hardened multi-file Swift layout is present.

## [2026-06-14 10:54] Gemma Returned Empty Or Tiny Code Reviews
- Problem: Code-review prompts sent through the Gemma Desktop bridge mechanically worked, but Gemma returned unusable review content: an empty response, `This`, or a refusal-like answer asking for source even when snippets were provided. A direct Ollama reproduction with a tiny JavaScript review prompt also returned an empty response with `done_reason: "length"` after consuming the full token budget.
- Root Cause: `gemma4:latest` can spend the full response budget without emitting visible text on review-style prompts unless prompted to produce final-answer output; the app also accepted very short review responses as successful and defaulted to a smaller response budget.
- Solution: Added `think: false` to Ollama generation requests, set deterministic review-friendly generation options, raised the default response token budget to 1024, strengthened the base prompt to ask for final-answer output and concrete review findings, and added one automatic retry for review/code prompts that return empty or too-short text.
- Files Changed: `README.md`, `PROJECT.md`, `SOLUTIONS.md`, `src/ChatModel.swift`, `src/Models.swift`, `src/OllamaClient.swift`
- Status: Resolved
- Verification: Direct Ollama tests confirmed `think: false`/final-answer prompting returns useful bullets; `./tests/run-unit-tests.sh` passed; `./scripts/build-desktop-app.sh` passed; after relaunching `Gemma Desktop.app`, a queued bridge review prompt for the unavailable-add filter returned three concrete review points in `responses/review-smoke-1781448759.json`.
