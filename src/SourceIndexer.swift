import Foundation

enum SourceIndexer {
    private static let maxIndexedFiles = 500
    private static let maxFileBytes = 1_000_000
    private static let chunkSize = 4_500
    private static let chunkOverlap = 500

    static func cloneAndIndexRepo(_ rawURL: String, ref: String?) throws -> RepoContext {
        let cloneURL = normalizedGitURL(rawURL)
        let repoName = repoName(from: cloneURL)
        let base = repoCacheDirectory()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let target = base.appendingPathComponent("\(repoName)-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        var args = ["clone", "--depth", "1"]
        let cleanRef = ref?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanRef.isEmpty {
            args += ["--branch", cleanRef, "--single-branch"]
        }
        args += [cloneURL, target.path]
        try runGit(args: args)

        let indexed = try indexFiles(at: target)
        if indexed.files.isEmpty {
            throw NSError(domain: "GemmaDesktop", code: 3, userInfo: [NSLocalizedDescriptionKey: "The repo was cloned, but no readable text files were found."])
        }

        return RepoContext(
            name: repoName,
            root: target,
            files: indexed.files,
            chunks: indexed.chunks,
            diskSizeBytes: directorySizeBytes(at: target),
            trackedFileCount: gitTrackedFileCount(at: target),
            skipped: indexed.skipped,
            isTemporaryClone: true
        )
    }

    static func indexLocalFolder(_ folder: URL) throws -> RepoContext {
        let indexed = try indexFiles(at: folder)
        if indexed.files.isEmpty {
            throw NSError(domain: "GemmaDesktop", code: 5, userInfo: [NSLocalizedDescriptionKey: "No readable text/code files were found in the selected folder."])
        }
        return RepoContext(
            name: folder.lastPathComponent,
            root: folder,
            files: indexed.files,
            chunks: indexed.chunks,
            diskSizeBytes: directorySizeBytes(at: folder),
            trackedFileCount: gitTrackedFileCount(at: folder),
            skipped: indexed.skipped,
            isTemporaryClone: false
        )
    }

    static func removeTemporarySource(_ context: RepoContext?) {
        guard let context, context.isTemporaryClone else { return }
        try? FileManager.default.removeItem(at: context.root)
    }

    static func cleanOldRepoCaches(keeping root: URL?) {
        let base = repoCacheDirectory()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let keepPath = root?.path
        let sorted = urls
            .filter { $0.path != keepPath }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }

        for old in sorted.dropFirst(4) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    private static func repoCacheDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("GemmaDesktopRepos", isDirectory: true)
    }

    private static func normalizedGitURL(_ rawURL: String) -> String {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("https://github.com/") && !trimmed.hasSuffix(".git") {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + ".git"
        }
        return trimmed
    }

    private static func repoName(from cloneURL: String) -> String {
        let clean = cloneURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: ".git", with: "")
        let last = clean.split(separator: "/").last.map(String.init) ?? "repo"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(last.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }

    private static func runGit(args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args

        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "git failed"
            throw NSError(domain: "GemmaDesktop", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func runGitCapture(args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "git failed"
            throw NSError(domain: "GemmaDesktop", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func gitTrackedFileCount(at root: URL) -> Int? {
        guard let output = try? runGitCapture(args: ["-C", root.path, "ls-files"]) else {
            return nil
        }
        return output.split(whereSeparator: \.isNewline).count
    }

    private static func directorySizeBytes(at root: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let relativePath = relativePath(for: url, root: root)
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true, shouldSkipDirectory(relativePath) {
                enumerator.skipDescendants()
                continue
            }
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private static func indexFiles(at root: URL) throws -> (files: [RepoFile], chunks: [RepoChunk], skipped: SourceSkipSummary) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ([], [], SourceSkipSummary())
        }

        var files: [RepoFile] = []
        var chunks: [RepoChunk] = []
        var skipped = SourceSkipSummary()

        for case let url as URL in enumerator {
            let relativePath = relativePath(for: url, root: root)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])

            if values.isDirectory == true, shouldSkipDirectory(relativePath) {
                enumerator.skipDescendants()
                continue
            }

            guard values.isRegularFile == true else { continue }
            guard files.count < maxIndexedFiles else {
                skipped.overFileLimit += 1
                continue
            }
            guard isReadableTextPath(relativePath) else {
                skipped.unsupported += 1
                continue
            }

            let fileSize = values.fileSize ?? 0
            guard fileSize <= maxFileBytes else {
                skipped.tooLarge += 1
                continue
            }

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                skipped.unreadable += 1
                continue
            }

            guard let text = String(data: data, encoding: .utf8) else {
                skipped.unreadable += 1
                continue
            }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skipped.empty += 1
                continue
            }

            files.append(RepoFile(path: relativePath, text: text, sizeBytes: fileSize))
            chunks += chunkText(text, path: relativePath)
        }

        return (files, chunks, skipped)
    }

    private static func chunkText(_ text: String, path: String) -> [RepoChunk] {
        var result: [RepoChunk] = []
        var start = text.startIndex
        var index = 0

        while start < text.endIndex {
            let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            result.append(RepoChunk(path: path, index: index, text: String(text[start..<end])))
            if end == text.endIndex { break }
            start = text.index(end, offsetBy: -min(chunkOverlap, text.distance(from: start, to: end)))
            index += 1
        }

        return result
    }

    private static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.resolvingSymlinksInPath().path
        let urlPath = url.resolvingSymlinksInPath().path
        if urlPath.hasPrefix(rootPath + "/") {
            return String(urlPath.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }

    private static func shouldSkipDirectory(_ path: String) -> Bool {
        let normalized = path.hasSuffix("/") ? path : path + "/"
        let blocked = [
            ".git/", "node_modules/", "dist/", "build/", ".next/", ".venv/",
            "vendor/", "target/", "coverage/", ".cache/", "__pycache__/",
            "DerivedData/", ".swiftpm/"
        ]
        return blocked.contains { normalized.contains($0) }
    }

    private static func isReadableTextPath(_ path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        if ["readme", "readme.md", "license", "dockerfile", "makefile"].contains(fileName) {
            return true
        }

        let allowedExtensions: Set<String> = [
            "c", "cc", "cpp", "cs", "css", "go", "h", "hpp", "html", "java",
            "js", "json", "jsx", "kt", "m", "md", "mm", "php", "plist", "py",
            "rb", "rs", "scss", "sh", "sql", "swift", "toml", "ts", "tsx",
            "txt", "xml", "yaml", "yml"
        ]
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return allowedExtensions.contains(ext)
    }
}
