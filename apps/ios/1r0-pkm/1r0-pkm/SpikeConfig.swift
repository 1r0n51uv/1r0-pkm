//
//  SpikeConfig.swift
//  1r0-pkm
//
//  Created by 1r0n51uv on 05/09/26.
//

import Foundation

/// SPIKE ONLY (issue #6). The real app keeps the base URL + API key in an
/// un-committed Config.xcconfig / Secrets.swift (ADR-0022). Hard-coded here
/// because this is a throwaway end-to-end proof against a spike backend.
enum SpikeConfig {
    static let apiBaseURL = URL(string: "http://100.31.154.129")!
    static let apiKey = "ac8e0162d0b175f7a41a998e724c1471241a828a1fdb90bfb6eeb686a386d833"
}
