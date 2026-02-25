import Foundation
import os

internal enum MarkdownLogger {
    private static let subsystem = "com.jcfontecha.markdown-editor"
    
    static let commandBar = Logger(subsystem: subsystem, category: "command-bar")
    static let command = Logger(subsystem: subsystem, category: "command")
    static let editor = Logger(subsystem: subsystem, category: "editor")
    static let plugin = Logger(subsystem: subsystem, category: "plugin")
    
    @inline(__always)
    private static func isEnabled(
        _ config: LoggingConfiguration?,
        at level: LoggingConfiguration.LogLevel
    ) -> Bool {
        guard let config else { return true }
        return config.isEnabled && config.level >= level
    }
    
    @inline(__always)
    private static func log(
        _ message: String,
        level: LoggingConfiguration.LogLevel,
        config: LoggingConfiguration?,
        to logger: Logger
    ) {
        guard isEnabled(config, at: level) else { return }
        
        switch level {
        case .error:
            logger.error("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .debug, .verbose:
            logger.debug("\(message, privacy: .public)")
        case .none:
            break
        }
    }
    
    static func commandBar(
        _ message: String,
        level: LoggingConfiguration.LogLevel,
        config: LoggingConfiguration? = nil
    ) {
        log(message, level: level, config: config, to: MarkdownLogger.commandBar)
    }
    
    static func command(
        _ message: String,
        level: LoggingConfiguration.LogLevel,
        config: LoggingConfiguration? = nil
    ) {
        log(message, level: level, config: config, to: MarkdownLogger.command)
    }
    
    static func editor(
        _ message: String,
        level: LoggingConfiguration.LogLevel,
        config: LoggingConfiguration? = nil
    ) {
        log(message, level: level, config: config, to: MarkdownLogger.editor)
    }
    
    static func plugin(
        _ message: String,
        level: LoggingConfiguration.LogLevel = .error
    ) {
        log(message, level: level, config: nil, to: MarkdownLogger.plugin)
    }
}

