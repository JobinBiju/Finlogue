//
//  WatchSyncEngine.swift
//  FinWatch Watch App (watch target only)
//
//  Watch side of the sync: applies snapshots from the phone into the local
//  store and sends locally added transactions back.
//

import Foundation
import SwiftData
import WatchConnectivity

final class WatchSyncEngine: NSObject, ObservableObject {
    static let shared = WatchSyncEngine()

    @Published var lastSyncDate: Date? {
        didSet {
            UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSyncKey)
        }
    }

    private static let lastSyncKey = "lastSyncDate"
    private var container: ModelContainer?

    private override init() {
        super.init()
        lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
    }

    func configure(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        // The system persists the last applicationContext; apply it on launch
        // so the watch shows data even before the phone is reachable.
        applyPayload(session.receivedApplicationContext)
    }

    /// Asks the phone for a fresh snapshot right now (when reachable).
    func requestSnapshot() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([SyncKeys.request: SyncKeys.requestSnapshot], replyHandler: { [weak self] reply in
            self?.applyPayload(reply)
        }, errorHandler: nil)
    }

    /// Sends a watch-added transaction: instant message when reachable, with a
    /// queued transferUserInfo fallback so it survives unreachability. The
    /// phone dedupes by UUID, so double delivery is harmless.
    func send(transaction dto: TransactionDTO) {
        guard let data = try? SnapshotBuilder.encodeTransaction(dto) else { return }
        let payload: [String: Any] = [SyncKeys.newTransaction: data]
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func applyPayload(_ payload: [String: Any]) {
        guard let data = payload[SyncKeys.snapshot] as? Data,
              let snapshot = try? SnapshotBuilder.decode(data) else { return }
        Task { @MainActor in
            guard let container = self.container else { return }
            do {
                try SnapshotBuilder.apply(snapshot, context: container.mainContext)
                self.lastSyncDate = .now
            } catch {
                print("WatchSyncEngine.applyPayload failed: \(error)")
            }
        }
    }
}

extension WatchSyncEngine: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            DispatchQueue.main.async {
                self.requestSnapshot()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyPayload(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyPayload(message)
    }
}
