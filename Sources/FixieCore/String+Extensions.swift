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
        // removes suffix from "//" as long as it does not belong to `://`
        let commentSymbols = ["//"]
        
        for symbol in commentSymbols {
            let symbolRange: Range<_>! = self.firstRange(of: symbol)
            guard let commentStartIndex = symbolRange?.lowerBound else { continue }
            
            if self[self.index(before: commentStartIndex)..<symbolRange.upperBound] == "://" {
                continue
            }
            
            return self[..<commentStartIndex]
        }
        
        return Substring(self)
    }
    
}
