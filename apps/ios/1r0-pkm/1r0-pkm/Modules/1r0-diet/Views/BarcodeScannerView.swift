//
//  BarcodeScannerView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Scan barcode nativo (ADR-0018): VisionKit `DataScannerViewController` per
//  EAN-8/13/UPC. Il codice letto viene passato al chiamante, che fa il
//  lookup (cache backend → OpenFoodFacts). Dove lo scanner non è disponibile
//  (simulatore, permessi negati) resta l'inserimento manuale del codice.
//

import SwiftUI
import VisionKit

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    /// Chiamato col codice a barre letto (o digitato). Il chiamante chiude.
    var onCode: (String) -> Void

    @State private var manual = ""

    @MainActor
    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Glass.ink.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("Scansiona codice").font(Glass.display(16, .semibold))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16).padding(.top, 8)

            if scannerAvailable {
                ScannerRepresentable { code in
                    onCode(code)
                    dismiss()
                }
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Glass.amber, lineWidth: 3)
                        .frame(width: 240, height: 150)
                }
                .overlay(alignment: .bottom) {
                    Text("Inquadra il codice a barre del prodotto")
                        .font(Glass.body(13)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.bottom, 40)
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 44)).foregroundStyle(Glass.ink.opacity(0.4))
                    Text("Fotocamera non disponibile")
                        .font(Glass.display(16, .semibold))
                    Text("Inserisci il codice a barre a mano.")
                        .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.5))
                    HStack(spacing: 10) {
                        TextField("", text: $manual,
                                  prompt: Text("es. 8001505005707").foregroundColor(Glass.ink.opacity(0.4)))
                            .keyboardType(.numberPad)
                            .font(Glass.body(16)).padding(14)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                            .accessibilityIdentifier("manualBarcode")
                        Button {
                            onCode(manual.filter(\.isNumber)); dismiss()
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(Glass.onCoral)
                                .frame(width: 48, height: 48)
                                .background(Glass.amber, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(manual.filter(\.isNumber).count < 6)
                        .accessibilityIdentifier("manualBarcodeGo")
                    }
                    .padding(.horizontal, 22)
                    Spacer(); Spacer()
                }
            }
        }
        .glassScreen(.warm)
    }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        try? vc.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var fired = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd added: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !fired else { return }
            for case let .barcode(b) in added {
                if let s = b.payloadStringValue, s.count >= 6 {
                    fired = true
                    scanner.stopScanning()
                    onCode(s)
                    return
                }
            }
        }
    }
}
