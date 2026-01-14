// FixieError.swift
// Created: 2025 Nov 04
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT

public enum FixieError: Error, CustomStringConvertible {
    case scriptNotFound(String)
    case unknownFunction(String)
    case commandFailed(String)
    case noStdin
    case shellFailed(Int32)
    
    public var description: String {
        switch self {
        case .scriptNotFound(let p): return "Script not found at \(p)"
        case .unknownFunction(let f): return "Unknown function: \(f)()"
        case .commandFailed(let c): return "Command Failed: \(c)"
        case .noStdin: return "Persistent shell stdin unavailable"
        case .shellFailed(let code): return "Shell exited with code \(code)"
        }
    }
    
}
