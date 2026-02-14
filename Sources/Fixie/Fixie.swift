// Fixie.swift
// Created: 2025 Nov 04
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT

import Subprocess
import SystemPackage
import Foundation
@_spi(FixieInternal) import FixieCore

extension Fixie {
    static func main() async throws {
        let scriptPaths = Self.scriptPaths
        
        let input = OperatorInput()
        
        do {
            let runner = try Fixie(scriptPaths: scriptPaths, failFast: input.shouldFailFast)
            
            switch input.flag {
            case .list:
                try runner.listFunctions(in: scriptPaths)
                return
                
            case .edit:
                #if os(macOS)
                try await runner.run(.init(name: "edit-main-list-macOS", body: """
                cd ~/.fixie
                // ˅ TODO: Check if any other lists are defined in this directory and skip creating the default one
                // (allow renaming `list` as `main`, `functions`, `help`, etc.)
                touch list
                xed list
                """), failFast: true)
                return
                
                #else
                print("Missing `--edit` implementation")
                return
                
                #endif
                
            case nil:
                break
            }
            
            if input.functionNames.isEmpty || input.functionNames.contains(where: { $0.1.hasPrefix("-") }) {
                print("Usage: fixie <func1> <func2> ...")
                return
            }
            
            for (namespace, functionName) in input.functionNames {
                guard let funcDecl = runner.script[function: functionName, namespace: namespace] else {
                    if input.shouldFailFast {
                        throw FixieError.unknownFunction(functionName)
                        
                    } else {
                        print("⚠️  Unknown function: \(functionName)()")
                        continue
                    }
                }
                
                //
                printFunctionHeader(name: functionName, namespace: namespace)
                try await runner.run(funcDecl, failFast: input.shouldFailFast)
                printFunctionHeader(name: functionName, namespace: namespace, endVerb: "completed")
                
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
    
    init(scriptPaths: [FilePath], failFast: Bool) throws {
        self.shell = try .init(failFast: failFast)
        try shell.createDefaultFixieList() // if doesn't exist
        
        let loadedScripts = scriptPaths.compactMap { Script($0) }
        
        if loadedScripts.isEmpty {
            // construct error based on directory if available, else first path
            let notFoundTarget = scriptPaths.first?.string ?? FilePath("").string
            throw FixieError.scriptNotFound(notFoundTarget)
        }
        
        self.script = Script(merging: loadedScripts)
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
    
    fileprivate func listFunctions(in scriptPaths: [FilePath]) throws {
        let scripts = scriptPaths.compactMap { path -> (FilePath, Script)? in
            guard let s = Script(path) else { return nil }
            return (path, s)
        }
        if scripts.isEmpty {
            throw FixieError.scriptNotFound(FilePath("").string)
        }
        print("""
        ────────────────────────────────────────
         🗺️  Functions:
        ────────────────────────────────────────    
        """)
        for (path, s) in scripts {
            let filename = path.lastComponent?.string ?? path.string
            if !(s.allFunctions.contains { _ in true }) {
                print("[\(filename)]")
            }
            for f in s.allFunctions {
                print(" - \(f.name)()")
            }
            
            #if PRINT_FIRST_LIST_ONLY
            break
            #endif
        }
        print("")
    }
    
}

extension Fixie {
    fileprivate static func printFunctionHeader(
        name functionName: String,
        namespace: String?,
        endVerb: String? = nil,
        error: (any Error)? = nil,
    ) {
        let functionName = if let namespace { "\(namespace)::\(functionName)" } else { functionName }
        
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

extension Fixie {
    fileprivate static var scriptPaths : [FilePath] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        let fixieDir = FilePath(home.path).appending(".fixie")
        let fm = FileManager.default
        let dirURL = URL(fileURLWithPath: fixieDir.string, isDirectory: true)
        let fileURLs = (try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []
        
        return {
            var paths: [FilePath] = fileURLs.compactMap { url in
                // only include regular files directly under ~/.fixie
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true ? FilePath(url.path) : nil
            }
            
            // move `list` to beginning of script
            if let listPathIndex = paths.firstIndex(where: { $0.string.hasSuffix("/list") }) {
                let primaryList = paths[listPathIndex]
                paths.remove(at: listPathIndex)
                paths.insert(primaryList, at: 0)
            }
            
            return paths
        }()
    }
}
