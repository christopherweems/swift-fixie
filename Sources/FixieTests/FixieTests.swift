// FixieTests.swift
// Created: 2025 Nov 04
// URL: https://github.com/christopherweems/swift-fixie
// Copyright (c) 2025 Christopher Weems
// SPDX-License-Identifier: MIT

import FixieCore
import Testing

@Test
func testShell() async throws {
    let shell = try Shell(failFast: true)
    
    let _result = try shell.run("echo s3://123")
    
    var result = ""
    
    for try await r in _result {
        result.append(String(data: r, encoding: .utf8)!)
    }
    
    #expect(result.hasPrefix("s3://123"))
    
}
