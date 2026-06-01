import Foundation

@main
struct SourceIndexerSmokeTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GemmaDesktopSourceIndexerTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules", isDirectory: true), withIntermediateDirectories: true)

        let readme = String(repeating: "Gemma Desktop source indexing test.\n", count: 260)
        try readme.write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "print('hello')\n".write(to: root.appendingPathComponent("app.py"), atomically: true, encoding: .utf8)
        try "ignored\n".write(to: root.appendingPathComponent("node_modules/ignored.js"), atomically: true, encoding: .utf8)
        try "unsupported\n".write(to: root.appendingPathComponent("image.bin"), atomically: true, encoding: .utf8)

        let context = try SourceIndexer.indexLocalFolder(root)

        check(context.files.contains { $0.path == "README.md" }, "README.md should be indexed")
        check(context.files.contains { $0.path == "app.py" }, "app.py should be indexed")
        check(!context.files.contains { $0.path.contains("node_modules") }, "node_modules should be skipped")
        check(context.chunks.count >= 2, "long README should be chunked")
        check(context.skipped.unsupported >= 1, "unsupported extension should be counted")
        check(context.diskSizeBytes > 0, "source size should be measured")

        print("SourceIndexer smoke tests passed")
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            FileHandle.standardError.write(Data("Assertion failed: \(message)\n".utf8))
            exit(1)
        }
    }
}
