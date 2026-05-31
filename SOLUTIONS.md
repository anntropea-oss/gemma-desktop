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
