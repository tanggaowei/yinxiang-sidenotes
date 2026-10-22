import Foundation

enum SyncError: LocalizedError {
    case tokenMissing
    case nodeNotFound
    case workerNotFound
    case executionFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .tokenMissing:
            return "请先在设置中填写印象笔记 Developer Token"
        case .nodeNotFound:
            return "未找到系统 Node.js 运行环境"
        case .workerNotFound:
            return "同步核心组件缺失"
        case .executionFailed(let msg):
            return msg
        case .invalidResponse:
            return "解析云端返回数据失败"
        }
    }
}

class YinxiangSyncEngine {
    static let shared = YinxiangSyncEngine()

    private init() {}

    // Find node executable on macOS
    private func findNodePath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/node",
            "/opt/homebrew/bin/node",
            "/usr/bin/node",
            "\(NSHomeDirectory())/.local/share/fnm/current/bin/node",
            "/Users/tanggaowei/.local/share/fnm/node-versions/v24.3.0/installation/bin/node"
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try 'which node'
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["node"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !output.isEmpty && FileManager.default.isExecutableFile(atPath: output) {
            return output
        }

        return nil
    }

    // Locate sync_worker.js
    private func findWorkerScriptPath() -> String? {
        // Check bundle resources
        if let bundlePath = Bundle.main.path(forResource: "sync_worker", ofType: "js", inDirectory: "worker") {
            return bundlePath
        }
        if let bundlePath = Bundle.main.path(forResource: "sync_worker", ofType: "js") {
            return bundlePath
        }

        // Check relative project path in development
        let currentDir = FileManager.default.currentDirectoryPath
        let devPath = (currentDir as NSString).appendingPathComponent("worker/sync_worker.js")
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        // Check hardcoded known project path
        let hardcoded = "/Users/tanggaowei/myspace/github/yinxiang-sidenotes/worker/sync_worker.js"
        if FileManager.default.fileExists(atPath: hardcoded) {
            return hardcoded
        }

        return nil
    }

    // Run Node worker subprocess
    private func executeWorker(action: String, payload: [String: Any]) async throws -> [String: Any] {
        guard let nodePath = findNodePath() else {
            throw SyncError.nodeNotFound
        }
        guard let workerPath = findWorkerScriptPath() else {
            throw SyncError.workerNotFound
        }

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw SyncError.invalidResponse
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: nodePath)
                process.arguments = [workerPath, action, jsonString]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let outString = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if let parsed = try? JSONSerialization.jsonObject(with: outData, options: []) as? [String: Any] {
                        if let success = parsed["success"] as? Bool, success {
                            continuation.resume(returning: parsed)
                        } else {
                            let errorMsg = parsed["error"] as? String ?? "未知同步错误"
                            continuation.resume(throwing: SyncError.executionFailed(errorMsg))
                        }
                    } else {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let errString = String(data: errData, encoding: .utf8) ?? outString
                        continuation.resume(throwing: SyncError.executionFailed(errString.isEmpty ? "同步进程异常退出" : errString))
                    }
                } catch {
                    continuation.resume(throwing: SyncError.executionFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - API Methods

    func testConnection(token: String, china: Bool) async throws -> String {
        let res = try await executeWorker(action: "test-connection", payload: [
            "token": token,
            "china": china
        ])
        if let user = res["user"] as? [String: Any],
           let name = user["name"] as? String ?? user["username"] as? String {
            return name
        }
        return "印象笔记用户"
    }

    func listNotebooks(token: String, china: Bool) async throws -> [Notebook] {
        let res = try await executeWorker(action: "list-notebooks", payload: [
            "token": token,
            "china": china
        ])
        guard let list = res["notebooks"] as? [[String: Any]] else {
            return []
        }

        return list.compactMap { item in
            guard let guid = item["guid"] as? String,
                  let name = item["name"] as? String else { return nil }
            let isDef = item["defaultNotebook"] as? Bool ?? false
            return Notebook(guid: guid, name: name, isDefault: isDef)
        }
    }

    func getOrCreateDefaultNotebook(token: String, china: Bool, name: String = "SideNotes") async throws -> Notebook {
        let res = try await executeWorker(action: "get-or-create-default", payload: [
            "token": token,
            "china": china,
            "name": name
        ])
        guard let nbData = res["notebook"] as? [String: Any],
              let guid = nbData["guid"] as? String,
              let nbName = nbData["name"] as? String else {
            throw SyncError.invalidResponse
        }
        let isDef = nbData["defaultNotebook"] as? Bool ?? false
        return Notebook(guid: guid, name: nbName, isDefault: isDef)
    }

    func createNotebook(token: String, china: Bool, name: String) async throws -> Notebook {
        let res = try await executeWorker(action: "create-notebook", payload: [
            "token": token,
            "china": china,
            "name": name
        ])
        guard let nbData = res["notebook"] as? [String: Any],
              let guid = nbData["guid"] as? String,
              let nbName = nbData["name"] as? String else {
            throw SyncError.invalidResponse
        }
        return Notebook(guid: guid, name: nbName, isDefault: false)
    }

    func fetchNotes(token: String, china: Bool, notebookGuid: String) async throws -> [Note] {
        let res = try await executeWorker(action: "fetch-notes", payload: [
            "token": token,
            "china": china,
            "notebookGuid": notebookGuid
        ])
        guard let notesData = res["notes"] as? [[String: Any]] else {
            return []
        }

        return notesData.compactMap { item in
            guard let guid = item["guid"] as? String,
                  let title = item["title"] as? String else { return nil }
            let content = item["content"] as? String ?? ""
            let updatedMillis = item["updated"] as? Double ?? Date().timeIntervalSince1970 * 1000
            let updatedDate = Date(timeIntervalSince1970: updatedMillis / 1000.0)

            return Note(
                guid: guid,
                title: title,
                content: content,
                notebookGuid: notebookGuid,
                updatedAt: updatedDate,
                color: .gray,
                isPinned: false,
                isDirty: false
            )
        }
    }

    func saveNote(token: String, china: Bool, note: Note) async throws -> (guid: String, updated: Date) {
        let payload: [String: Any] = [
            "token": token,
            "china": china,
            "guid": note.guid,
            "notebookGuid": note.notebookGuid,
            "title": note.title,
            "content": note.content
        ]
        let res = try await executeWorker(action: "save-note", payload: payload)
        guard let saved = res["note"] as? [String: Any],
              let guid = saved["guid"] as? String else {
            throw SyncError.invalidResponse
        }
        let updatedMillis = saved["updated"] as? Double ?? Date().timeIntervalSince1970 * 1000
        return (guid, Date(timeIntervalSince1970: updatedMillis / 1000.0))
    }

    func deleteNote(token: String, china: Bool, guid: String) async throws {
        _ = try await executeWorker(action: "delete-note", payload: [
            "token": token,
            "china": china,
            "guid": guid
        ])
    }
}
