import Foundation

public enum LogLevel: Int, Comparable, Codable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }

    public var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct LoggerConfig {
    public var minimumLevel: LogLevel
    public var enableConsole: Bool
    public var enableFile: Bool
    public var filePath: String

    public init(
        minimumLevel: LogLevel = .debug,
        enableConsole: Bool = true,
        enableFile: Bool = true,
        filePath: String? = nil
    ) {
        self.minimumLevel = minimumLevel
        self.enableConsole = enableConsole
        self.enableFile = enableFile
        self.filePath = filePath ?? Logger.defaultLogPath
    }
}

public final class Logger {
    public static let shared = Logger()

    private var config: LoggerConfig
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.location-automation.logger", qos: .utility)
    private var fileHandle: FileHandle?

    public static var defaultLogPath: String {
        #if os(iOS)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "."
        return "\(documentsPath)/app.log"
        #else
        return "app.log"
        #endif
    }

    public init(config: LoggerConfig = LoggerConfig()) {
        self.config = config
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        setupFileLogging()
    }

    deinit {
        fileHandle?.closeFile()
    }

    public func configure(_ config: LoggerConfig) {
        queue.sync {
            self.config = config
            setupFileLogging()
        }
    }

    public func setMinimumLevel(_ level: LogLevel) {
        queue.sync { config.minimumLevel = level }
    }

    public func setEnableConsole(_ enabled: Bool) {
        queue.sync { config.enableConsole = enabled }
    }

    public func setEnableFile(_ enabled: Bool) {
        queue.sync { config.enableFile = enabled }
    }

    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }

    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }

    private func setupFileLogging() {
        fileHandle?.closeFile()
        fileHandle = nil
        guard config.enableFile else { return }

        let path = config.filePath
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
        }

        do {
            fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            fileHandle?.seekToEndOfFile()
        } catch {}
    }

    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard level >= self.config.minimumLevel else { return }

            let timestamp = self.dateFormatter.string(from: Date())
            let filename = (file as NSString).lastPathComponent
            let logEntry = "[\(timestamp)] [\(level.label)] [\(filename):\(line)] \(function): \(message)\n"

            if self.config.enableConsole {
                print("[\(timestamp)] \(level.emoji) [\(level.label)] \(message)")
            }

            if self.config.enableFile, let fileHandle = self.fileHandle {
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
            }
        }
    }

    public func getLogContents() -> String? {
        let path = config.filePath
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    public func clearLog() {
        queue.sync {
            fileHandle?.closeFile()
            fileHandle = nil

            let path = config.filePath
            if FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.removeItem(atPath: path)
            }
            FileManager.default.createFile(atPath: path, contents: nil, attributes: nil)
            setupFileLogging()
        }
    }
}

public extension Logger {
    func debugJSON(_ dictionary: [String: Any], file: String = #file, function: String = #function, line: Int = #line) {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            debug("Failed to serialize dictionary", file: file, function: function, line: line)
            return
        }
        debug(string, file: file, function: function, line: line)
    }

    func debugObject<T: Encodable>(_ object: T, file: String = #file, function: String = #function, line: Int = #line) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(object),
              let string = String(data: data, encoding: .utf8) else {
            debug("Failed to encode object", file: file, function: function, line: line)
            return
        }
        debug(string, file: file, function: function, line: line)
    }
}