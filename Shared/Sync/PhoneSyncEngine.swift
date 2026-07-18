//
//  PhoneSyncEngine.swift
//  Finlogue (iOS target only)
//
//  Phone side of the sync: pushes full snapshots to the watch and applies
//  transactions added on the watch. The phone is the source of truth.
//

import Foundation
import SwiftData
import WatchConnectivity

final class PhoneSyncEngine: NSObject, ObservableObject {
    static let shared = PhoneSyncEngine()

    @Published var lastPushDate: Date?

    private var container: ModelContainer?

    private override init() {
        super.init()
    }

    func configure(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Builds the current snapshot and sends it: durable applicationContext,
    /// plus an instant message when the watch is reachable.
    func pushSnapshot() {
        guard let container, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        Task { @MainActor in
            do {
                let snapshot = try SnapshotBuilder.build(context: container.mainContext)
                let data = try SnapshotBuilder.encode(snapshot)
                let payload: [String: Any] = [
                    SyncKeys.snapshot: data,
                    "generatedAt": snapshot.generatedAt.timeIntervalSince1970,
                ]
                try session.updateApplicationContext(payload)
                if session.isReachable {
                    session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
                }
                self.lastPushDate = .now
            } catch {
                print("PhoneSyncEngine.pushSnapshot failed: \(error)")
            }
        }
    }

    /// Inserts a watch-added transaction if we haven't seen its UUID before.
    /// Safe against double delivery (sendMessage + transferUserInfo).
    @MainActor
    private func applyIncomingTransaction(_ dto: TransactionDTO) {
        guard let container else { return }
        let context = container.mainContext
        do {
            let incomingID = dto.id
            var descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { $0.id == incomingID }
            )
            descriptor.fetchLimit = 1
            guard try context.fetch(descriptor).isEmpty else { return }

            let accountID = dto.accountID
            let toAccountID = dto.toAccountID
            let categoryID = dto.categoryID
            let account = try accountID.flatMap { id in
                try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })).first
            }
            let toAccount = try toAccountID.flatMap { id in
                try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })).first
            }
            let category = try categoryID.flatMap { id in
                try context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })).first
            }
            let personID = dto.personID
            let person = try personID.flatMap { id in
                try context.fetch(FetchDescriptor<Person>(predicate: #Predicate { $0.id == id })).first
            }
            let transaction = Transaction(
                id: dto.id,
                type: dto.type,
                name: dto.name,
                amount: dto.amount,
                charges: dto.charges,
                date: dto.date,
                note: dto.note,
                account: account,
                toAccount: toAccount,
                category: category,
                person: person,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt
            )
            context.insert(transaction)
            try context.save()
            pushSnapshot()
        } catch {
            print("PhoneSyncEngine.applyIncomingTransaction failed: \(error)")
        }
    }

    private func handle(payload: [String: Any]) {
        guard let data = payload[SyncKeys.newTransaction] as? Data,
              let dto = try? SnapshotBuilder.decodeTransaction(data) else { return }
        Task { @MainActor in
            self.applyIncomingTransaction(dto)
        }
    }
}

extension PhoneSyncEngine: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            pushSnapshot()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after the user switches to a different paired watch.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(payload: userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(payload: message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message[SyncKeys.request] as? String == SyncKeys.requestSnapshot {
            Task { @MainActor in
                guard let container = self.container else {
                    replyHandler([:])
                    return
                }
                do {
                    let snapshot = try SnapshotBuilder.build(context: container.mainContext)
                    let data = try SnapshotBuilder.encode(snapshot)
                    replyHandler([SyncKeys.snapshot: data])
                } catch {
                    replyHandler([:])
                }
            }
        } else {
            handle(payload: message)
            replyHandler(["status": "ok"])
        }
    }
}
