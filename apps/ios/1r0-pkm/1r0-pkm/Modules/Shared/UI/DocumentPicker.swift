//
//  DocumentPicker.swift
//  1r0-pkm · Modules/Shared/UI
//
//  Wrapper minimale di `UIDocumentPickerViewController` per scegliere un file
//  e leggerne il contenuto testuale. Usato dall'import CSV (1r0-gym) e, in
//  futuro, dall'acquisizione documenti (1r0-documenti, ADR-0027 step 6).
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var contentTypes: [UTType] = [.commaSeparatedText, .plainText, .text, .data]
    /// Riceve il testo del file scelto, o un errore di lettura.
    var onPick: (Result<String, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        vc.allowsMultipleSelection = false
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Result<String, Error>) -> Void
        init(onPick: @escaping (Result<String, Error>) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
                    ?? ""
                onPick(.success(text))
            } catch {
                onPick(.failure(error))
            }
        }
    }
}
