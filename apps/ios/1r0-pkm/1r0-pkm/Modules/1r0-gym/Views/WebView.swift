//
//  WebView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Wrapper minimale di `WKWebView` per mostrare in-app la dimostrazione di
//  un esercizio (`Exercise.videoURL`, ADR-0005/0013): pagina wger, embed
//  YouTube o mp4 diretto — `WKWebView` gestisce tutti e tre.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.isOpaque = false
        v.backgroundColor = .clear
        v.scrollView.backgroundColor = .clear
        return v
    }

    func updateUIView(_ v: WKWebView, context: Context) {
        if v.url != url { v.load(URLRequest(url: url)) }
    }
}
