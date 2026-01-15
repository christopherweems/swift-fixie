// String+Extensions.swift
// Created: 2025 Nov 04
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT

extension StringProtocol {
    /// Displays multi-line fragments inline, replacing newlines with a visible marker.
    @_spi(FixieInternal)
    public var trimmedReplacingNewlinesWithVisible: String {
        self
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ↩ ")
            .replacingOccurrences(of: "\r", with: " ↩ ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    public var trimmingTrailingNewlines: String {
        var s = String(self)
        while s.hasSuffix("\n") || s.hasSuffix("\r") {
            s.removeLast()
        }
        return s
    }
    
}

extension String {
    public var removingTrailingCodeComment: Substring {
        // removes tail from "//" (as long as it does not belong to `://`)
        let commentSymbols = ["//"]
        
        for symbol in commentSymbols {
            guard let symbolRange = self.firstRange(of: symbol) else { continue }
            guard self.firstRange(of: "://")?.upperBound != symbolRange.upperBound else{
                continue
            }
            
            return self[..<symbolRange.lowerBound]
        }
        
        return Substring(self)
    }
    
}
