// Script.swift
// Created: 2025 Nov 17
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT


struct OperatorInput {
    enum Flag {
        case list
        case edit
        
    }
    
    let flag: Flag?
    let functionNames: [(namespace: String?, functionName: String)]
    let shouldFailFast: Bool
    
    init() {
        let args = CommandLine.arguments.dropFirst() // first is `fixie`
        let functionNameArguments = args.filter { !$0.hasPrefix("-") }
        
        flag = if args.contains("--edit") {
            .edit
        } else if args.contains("--list") || args.contains("--help") {
            .list
        } else {
            nil
        }
        
        shouldFailFast = args.contains("-e")
        
        var currentNamespace: String? = nil
        var functionNames = [(String?, String)]()
        
        for var functionName in functionNameArguments {
            switch functionName.firstRange(of: "::") {
            case let range?:
                currentNamespace = if range.lowerBound == functionName.startIndex { nil }
                                   else { String(functionName.prefix(upTo: range.lowerBound)) }
                
                functionName = String(functionName.suffix(from: range.upperBound))
                fallthrough
                
            case nil:
                functionNames.append((currentNamespace, functionName))
            }
        }
        
        self.functionNames = functionNames
        
    }
    
}
