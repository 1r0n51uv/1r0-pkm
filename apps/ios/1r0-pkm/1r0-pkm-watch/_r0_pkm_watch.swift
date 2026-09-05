//
//  _r0_pkm_watch.swift
//  1r0-pkm-watch
//
//  Created by 1r0n51uv on 05/09/26.
//

import AppIntents

struct _r0_pkm_watch: AppIntent {
    static var title: LocalizedStringResource = "1r0-pkm-watch"
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
