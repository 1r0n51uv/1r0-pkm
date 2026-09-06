//
//  Secrets.example.swift
//  1r0-pkm
//
//  Template. On a fresh checkout:
//      cp "1r0-pkm/Secrets.example.swift" "1r0-pkm/Secrets.swift"
//  then fill in the real values. Secrets.swift is gitignored (ADR-0022:
//  URL + static API key stay out of version control).
//

import Foundation

enum Secrets {
    /// Base URL of the custom backend (ADR-0022), e.g. https://api.example.com
    static let apiBaseURL = URL(string: "http://REPLACE_ME")!
    /// The single static bearer token the backend expects.
    static let apiKey = "REPLACE_ME"
}
