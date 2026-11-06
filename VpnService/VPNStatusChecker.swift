import Foundation
import SystemConfiguration

class VPNStatusChecker: ObservableObject {
    //    @Published var mode: Bool = false
    @Published var status: SCNetworkConnectionStatus?
    @Published var name: String = UserDefaults.standard.string(forKey: "vpnName") ?? "Happ" {
        didSet { UserDefaults.standard.set(name, forKey: "vpnName") }
    }
    @Published var connection: SCNetworkConnection?
    @Published var clicks = 0

    func describe(_ status: SCNetworkConnectionStatus) -> String {
        switch status {
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .disconnecting: return "disconnecting"
        case .disconnected: return "disconnected"
        case .invalid: return "invalid"
        @unknown default: return "unknown"
        }
    }

    /// Имена всех VPN-подключений из системных настроек
    static func availableVPNNames() -> [String] {
        guard let prefs = SCPreferencesCreate(nil, "vpn-list" as CFString, nil),
              let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService]
        else { return [] }

        // "VPN" — тип у VPN-приложений вроде Happ и FoXray (публичной константы для него нет),
        // остальные — встроенные VPN macOS
        let vpnTypes: Set<String> = [
            "VPN",
            kSCNetworkInterfaceTypeIPSec as String,
            kSCNetworkInterfaceTypeL2TP as String,
            kSCNetworkInterfaceTypePPP as String,
        ]

        return services.compactMap { service in
            guard let interface = SCNetworkServiceGetInterface(service),
                  let type = SCNetworkInterfaceGetInterfaceType(interface) as String?,
                  vpnTypes.contains(type)
            else { return nil }
            return SCNetworkServiceGetName(service) as String?
        }
    }

    func start() {
        // 0. Отписываемся от старого VPN, если уже были подписаны
        if let old = connection {
            SCNetworkConnectionSetDispatchQueue(old, nil)
            connection = nil
        }
        // 1. Находим VPN-сервис по имени
        guard let prefs = SCPreferencesCreate(nil, "vpn-probe" as CFString, nil),
              let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService],
              let service = services.first(where: { (SCNetworkServiceGetName($0) as String?) == name }),
              let serviceID = SCNetworkServiceGetServiceID(service)
        else {
            print("Сервис \(name) не найден")
            status = SCNetworkConnectionStatus.invalid
            return
        }

        // 2. C-колбэк не может захватить self, поэтому кладём self в info
        var context = SCNetworkConnectionContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: SCNetworkConnectionCallBack = { _, status, info in
            guard let info else { return }
            let checker = Unmanaged<VPNStatusChecker>.fromOpaque(info).takeUnretainedValue()
            checker.update(status)
        }

        guard let connection = SCNetworkConnectionCreateWithServiceID(nil, serviceID, callback, &context) else {
            print("Не удалось подписаться")
            return
        }
        self.connection = connection

        update(SCNetworkConnectionGetStatus(connection))
        SCNetworkConnectionSetDispatchQueue(connection, .main)
    }

    func toggleVPN() {
        guard let connection else { return }
        if status == SCNetworkConnectionStatus.connected {
            SCNetworkConnectionStop(connection, true)
        } else {
            SCNetworkConnectionStart(connection, nil, false)
        }
    }

    private func update(_ newStatus: SCNetworkConnectionStatus) {
        status = newStatus
        print(Date(), describe(newStatus))
    }
}
