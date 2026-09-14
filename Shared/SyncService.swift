import Foundation
import WatchConnectivity

final class SyncService: NSObject, WCSessionDelegate {
    var onReceive: ((PinSnapshot) -> Void)?

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ snapshot: PinSnapshot) {
        guard WCSession.isSupported() else { return }
        guard let data = try? PinoJSON.encoder.encode(snapshot) else { return }
        let payload = ["snapshot": data]
        let session = WCSession.default
        if session.activationState == .activated {
            try? session.updateApplicationContext(payload)
        }
        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { _ in })
        }
    }

    private func handle(_ payload: [String: Any]) {
        guard let data = payload["snapshot"] as? Data,
              let snapshot = try? PinoJSON.decoder.decode(PinSnapshot.self, from: data) else { return }
        onReceive?(snapshot)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            if !context.isEmpty {
                handle(context)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in handle(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in handle(userInfo) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in handle(message) }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}
