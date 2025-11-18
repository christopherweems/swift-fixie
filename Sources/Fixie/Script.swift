// Script.swift
// Created: 2025 Nov 04
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT

import SystemPackage
import Foundation

struct Script {
    fileprivate let rawContent: String
    
    init?(_ filePath: FilePath) {
        guard let data = FileManager.default.contents(atPath: filePath.string),
              let content = String(data: data, encoding: .utf8)
        else { return nil }
        
        self.rawContent = content
        
    }
    
    //@_spi(FixieInternal)
    init(rawContent: String) {
        self.rawContent = rawContent
        
    }
    
}


// MARK: - Script Components

extension Script {
    struct FunctionDecl {
        public let name: String
        public let body: String
        
        var bodyLines: [String] {
            body.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        
    }
    
    var allFunctions: some Sequence<FunctionDecl> {
        parseFunctions(from: rawContent)
    }
    
    subscript(function name: String, namespace namespace: String?) -> FunctionDecl? {
        // TODO: Refactor to not compute entire script tree
        allFunctions.first { if let namespace { $0.name == "\(namespace)::\(name)" } else { $0.name == name } }
    }
    
}


// MARK: - Script Parsing

extension Script {
    private func parseFunctions(from source: String) -> [FunctionDecl] {
        var results: [FunctionDecl] = []
        
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        
        var currentName: String?
        var currentBodyLines: [Substring] = []
        var braceDepth = 0
        var isInFunction = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if !isInFunction {
                // Detect: func <word>() {
                if let name = parseFunctionHeader(trimmed) {
                    currentName = name
                    isInFunction = true
                    braceDepth = 1   // we've just seen the opening `{`
                    currentBodyLines = []
                    continue
                }
                
            } else {
                // Track braces to find function boundaries
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count
                
                if braceDepth == 0 {
                    // Function end
                    if let name = currentName {
                        let body = currentBodyLines.joined(separator: "\n")
                        results.append(FunctionDecl(name: name, body: body))
                    }
                    isInFunction = false
                    currentName = nil
                    continue
                }
                
                currentBodyLines.append(line)
            }
            
        }
        
        return results
    }
    
    private func parseFunctionHeader(_ line: String) -> String? {
        // Accept things like: `func foo() {`
        guard let prefixMatch = line.prefixMatch(of: #/\s*func\ /#) else { return nil }   // `func ` prefix preceeding spaces
        guard let suffixMatch = line.firstMatch(of: /{\s*$/) else { return nil }          // `{` suffix allowing whitespace
        
        // Remove leading `func ` and trailing `{`
        let inner = line
            .dropFirst(prefixMatch.output.count)
            .dropLast(suffixMatch.output.count)
            .trimmingCharacters(in: .whitespaces)
        
        guard inner.hasSuffix("()") else { return nil }
        
        return String(inner.dropLast(2))
    }
    
}
