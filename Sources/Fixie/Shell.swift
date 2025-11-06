// Shell.swift
// Created: 2025 Nov 04
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT

import Subprocess
import Foundation
import RegexBuilder

final class Shell {
    private let process = Process()
    private let inPipe = Pipe()
    private let outPipe = Pipe()
    private let errPipe = Pipe()
    
    init(failFast: Bool) throws {
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l"]
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        // Stream output to our stdout/stderr
        outPipe.fileHandleForReading.readabilityHandler = { fh in
            guard let s = String(data: fh.availableData, encoding: .utf8), !s.isEmpty else { return }
            FileHandle.standardOutput.write(Data(s.utf8))
        }
        
        errPipe.fileHandleForReading.readabilityHandler = { fh in
            guard let s = String(data: fh.availableData, encoding: .utf8), !s.isEmpty else { return }
            FileHandle.standardError.write(Data(("‼︎ " + s).utf8))
        }
        
        try process.run()
        
        if failFast {
            try write("set -e")
            try write("trap 'echo >&2 \"❌ Aborted in $CURRENT_FUNC (exit $?)\"' ERR")
        }
    }
    
}

extension Shell {
    func run(_ command: some StringProtocol) throws -> some AsyncSequence<Data, any Error> {
        let token = sentinelToken(for: UUID())
        
        var fragment = command.trimmingTrailingNewlines
        
        // Ensure the fragment ends cleanly before we append echo
        if !fragment.hasSuffix(";") &&
           !fragment.hasSuffix("&") &&
           !fragment.hasSuffix("|") {
            fragment.append(";")
        }
        
        try write(fragment + " echo \(token)\n")
        
        return outputChunks(sentinelToken: Data(token.utf8))
    }
    
    fileprivate func outputChunks(sentinelToken: Data) -> some AsyncSequence<Data, any Error> {
        let process = self.process
        
        return AsyncThrowingStream { continuation in
            let handle = outPipe.fileHandleForReading
            nonisolated(unsafe) var tail = Data() // small sliding window, not the full output
            
            handle.readabilityHandler = { h in
                let chunk = h.availableData
                
                if chunk.isEmpty {
                    if process.isRunning {
                        return
                    } else {
                        continuation.finish(throwing: FixieError.shellFailed(process.terminationStatus))
                        return
                    }
                }
                
                // Yield the raw chunk immediately.
                continuation.yield(chunk)
                
                // Check for token across boundary.
                var searchArea = tail
                searchArea.append(chunk)
                
                if let _ = searchArea.range(of: sentinelToken) {
                    continuation.finish()
                    handle.readabilityHandler = nil
                    return
                }
                
                // Keep only the trailing window needed for boundary checks.
                let newTailLength = sentinelToken.count - 1
                tail = searchArea.suffix(newTailLength)
            }
        }
    }
    
}

extension Shell {
    private static let fixieDonePrefix = "__FIXIE_DONE__"
    
    private func sentinelToken(for id: UUID) -> String {
        "\(Self.fixieDonePrefix)\(id.uuidString)"
    }
    
    private func sentinelTokenMatch(from chunk: String) -> Regex<(Substring, Substring)>.Match? {
        let fullExpression = Regex {
            Self.fixieDonePrefix
            Capture(#/[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/#)
        }
        
        return chunk.firstMatch(of: fullExpression)
    }
    
    func prefixTrimmingSentinelToken(from chunk: String) -> (Substring, containsToken: Bool) {
        guard let match = sentinelTokenMatch(from: chunk) else { return ("", false) }
        return (chunk.prefix(upTo: match.output.0.startIndex), true)
    }
    
    func chunkContainsSentinelToken(_ chunk: String) -> Bool {
        sentinelTokenMatch(from: chunk) != nil
    }
    
}


extension Shell {
    func finish() throws {
        try write("exit")
        
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw FixieError.shellFailed(process.terminationStatus)
        }
        
        // stop streaming
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        
    }
    
}

extension Shell {
    fileprivate func write(_ line: String) throws {
        let d = (line + "\n").data(using: .utf8)!
        try inPipe.fileHandleForWriting.write(contentsOf: d)
    }
    
}
