//
//  ShareSheet.swift
//  Finlogue
//
//  Thin wrapper around UIActivityViewController for sharing/saving files
//  (e.g. an exported backup) via the system share sheet.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
