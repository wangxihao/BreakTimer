import Foundation

/// 诊断日志：写入 ~/Library/Logs/BreakTimer-diag.log（仅状态流转，量极小）。
/// 用于排查浮层点击与阶段流转；点击测试结果也写在这里。
enum Diag {
    static var enabled = true

    static var logURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Logs/BreakTimer-diag.log")
    }

    static func log(_ message: String) {
        guard enabled else { return }
        let line = "\(Date()) \(message)\n"
        let path = logURL.path
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            handle.closeFile()
        } else {
            try? FileManager.default.createDirectory(atPath: logURL.deletingLastPathComponent().path,
                                                     withIntermediateDirectories: true)
            try? Data(line.utf8).write(to: logURL)
        }
    }
}
