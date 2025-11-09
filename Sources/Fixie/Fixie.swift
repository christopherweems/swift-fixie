// Fixie.swift
// Created: 2025 Nov 04
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT

import Subprocess
import SystemPackage
import Foundation

extension Fixie {
    static func main() async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let scriptPath = FilePath(home.path).appending(".fixie/list")
        
        do {
            let args = CommandLine.arguments.dropFirst()
            let failFast = args.contains("-e")
            let functionNameArguments = args.filter { !$0.hasPrefix("-") }
            
            let runner = try Fixie(scriptPath: scriptPath, failFast: failFast)
            
            if args.contains("--list") {
                try runner.listFunctions(in: scriptPath)
                return
            }
            
            if functionNameArguments.isEmpty || functionNameArguments.contains(where: { $0.hasPrefix("-") }) {
                print("Usage: fixie <func1> <func2> ...")
                return
            }
            
            for functionName in functionNameArguments {
                guard let funcDecl = runner.script[function: functionName] else {
                    if failFast {
                        throw FixieError.unknownFunction(functionName)
                        
                    } else {
                        print("⚠️  Unknown function: \(functionName)()")
                        continue
                    }
                }
                
                //
                printFunctionHeader(name: functionName)
                try await runner.run(funcDecl, failFast: failFast)
                printFunctionHeader(name: functionName, endVerb: "completed")
                
            }
            
        } catch {
            // TODO: consider using `printFunctionHeader(.., error: error)`
            print(" ❌ Error: \(error)")
            
        }
    }
    
}


// MARK: - Fixie

@main
struct Fixie {
    let script: Script
    let shell: Shell
    let failFast: Bool
    
    init(scriptPath: FilePath, failFast: Bool) throws {
        self.shell = try .init(failFast: failFast)
        try shell.createDefaultFixieList() // if doesn't exist
        
        guard let script = Script(scriptPath) else {
            throw FixieError.scriptNotFound(scriptPath.string)
        }
        
        self.script = script
        self.failFast = failFast
        
    }
    
}

extension Fixie {
    func run(_ f: Script.FunctionDecl, failFast: Bool) async throws {
        var fragment = ""
        
        for rawLine in f.bodyLines {
            var command = rawLine.removingTrailingCodeComment
            while command.hasSuffix(";") { command.removeLast() }
            guard !command.isEmpty else { continue }
            
            fragment += command + "\n"
            
            guard await Shell.isCompleteFragment(fragment) else { continue }
            
            print(" • \(fragment.trimmedReplacingNewlinesWithVisible)")
            try await runFragment(fragment)
            fragment = ""
        }
    }
    
    fileprivate func runFragment(_ commandFragment: String) async throws {
        do {
            let output = try shell.run(commandFragment)
            var hasWrittenContent = false
            
            for try await bytes in output {
                guard let chunk = String(bytes: bytes, encoding: .utf8) else { continue }
                let (prefix, chunkContainsToken) = shell.prefixTrimmingSentinelToken(from: chunk)
                
                if !hasWrittenContent && !prefix.isEmpty {
                    hasWrittenContent = true
                }
                
                if !prefix.isEmpty { print(prefix, terminator: "") }
                else if !chunkContainsToken && !chunk.isEmpty { print(chunk, terminator: "") }
                else if !chunkContainsToken && prefix.isEmpty { throw FixieError.commandFailed(String(commandFragment)) }
            }
            
            // print a new line after any written output
            if hasWrittenContent { print() }
            
        } catch {
            if failFast {
                print("❌ Command failed (\(error.localizedDescription))")
                throw FixieError.commandFailed(String(commandFragment))
                
            } else {
                print("‼︎ non-zero exit, continuing…")
            }
        }
    }
    
    fileprivate func listFunctions(in scriptPath: FilePath) throws {
        guard let script = Script(scriptPath) else {
            throw FixieError.scriptNotFound(scriptPath.string)
        }
        
        print("""
        ────────────────────────────────────────
         🗺️  Functions:
        ────────────────────────────────────────    
        """)
        
        for f in script.allFunctions {
            print(" - \(f.name)()")
        }
        
        print("")
        
        return
    }
    
}

extension Fixie {
    fileprivate static func printFunctionHeader(name functionName: String, endVerb: String? = nil, error: (any Error)? = nil) {
        switch endVerb {
        case nil: // start
            print("""
            ────────────────────────────────────────
             🚴 \(functionName)()
            ────────────────────────────────────────  
            """)
            
        case let endVerb?:
            let emoji = if let _ = error { "❌" } else { "🏁" }
            let divider = "────────────────────────────────────────"
            
            print(divider)
            print(" \(emoji) \(functionName)() \(endVerb).")
            if let error { print("Error: \(error.localizedDescription)") }
            print(divider)
            
        }
    }
    
}


// MARK: - Errors

enum FixieError: Error, CustomStringConvertible {
    case scriptNotFound(String)
    case unknownFunction(String)
    case commandFailed(String)
    case noStdin
    case shellFailed(Int32)

    var description: String {
        switch self {
        case .scriptNotFound(let p): return "Script not found at \(p)"
        case .unknownFunction(let f): return "Unknown function: \(f)()"
        case .commandFailed(let c): return "Command Failed: \(c)"
        case .noStdin: return "Persistent shell stdin unavailable"
        case .shellFailed(let code): return "Shell exited with code \(code)"
        }
    }
    
}


// MARK: - Helper Extensions

extension String {
    fileprivate var removingTrailingCodeComment: Substring {
        // TODO: Write a parser or escape sequence, we've tried adding a space to miss `https://...`
        let commentSymbols = ["//"]
        
        for symbol in commentSymbols {
            guard let commentStartIndex = self.firstRange(of: symbol)?.lowerBound else { continue }
            return self[..<commentStartIndex]
        }
        
        return Substring(self)
    }
    
}

extension Shell {
    fileprivate static func isCompleteFragment(_ text: String) async -> Bool {
        let result = try? await Subprocess.run(
            .path("/bin/bash"),
            arguments: ["-n", "-c", text],
            output: .discarded,
        )
        return result?.terminationStatus == .exited(0)
    }
    
}

extension StringProtocol {
    /// Displays multi-line fragments inline, replacing newlines with a visible marker.
    fileprivate var trimmedReplacingNewlinesWithVisible: String {
        self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ↩ ")
            .replacingOccurrences(of: "\r", with: " ↩ ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    internal var trimmingTrailingNewlines: String {
        var s = String(self)
        while s.hasSuffix("\n") || s.hasSuffix("\r") {
            s.removeLast()
        }
        return s
    }
}

extension Shell {
    // TODO: Avoid creating `~/.fixie/list` if operator has other named sheets (it may have been intentionally deleted)
    fileprivate func createDefaultFixieList() throws {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".fixie", isDirectory: true)
        
        try? fm.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: Int16(0o700))],
        )
        
        let listURL = dir.appendingPathComponent("list")
        
        if !fm.fileExists(atPath: listURL.path) {
            let template = """
            // Opens project README in fixie pager
            func quickstart() {
              if command -v less >/dev/null; then
                curl -fsSL https://raw.githubusercontent.com/christopherweems/swift-fixie/main/README.md | less
              else
                curl -fsSL https://raw.githubusercontent.com/christopherweems/swift-fixie/main/README.md
              fi
            }
            
            func editList() {
                cd ~/.fixie
                open -a Xcode list
            }
            
            """
            try template.write(to: listURL, atomically: true, encoding: .utf8)
            
            try? fm.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))],
                ofItemAtPath: listURL.path,
            )
        }
    }
    
}
