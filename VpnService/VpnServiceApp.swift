//
//  VpnServiceApp.swift
//  VpnService
//
//  Created by Григорий Алексеев on 02.12.2024.
//

import SwiftUI
import SystemConfiguration
import ServiceManagement

@main
struct VpnServiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {}
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var statusMenu: NSMenu?
    var providerMenu: NSMenu?
    var themeMenu: NSMenu?
    var loginItem: NSMenuItem?
    var vpnStatus = VPNStatusChecker()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Создаем статус-бар элемент
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Проверяем, что статус-бар элемент создан
        guard let button = statusItem?.button else { return }
        
        // Устанавливаем кастомное представление через SwiftUI
        let hostingView = NSHostingView(rootView: StatusBarView(vpnStatus: vpnStatus))
        hostingView.frame = NSRect(x: 0, y: 0, width: 36, height: 22)
        
        button.addSubview(hostingView)
        button.frame = hostingView.frame
        
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(sender:))
        
        statusMenu = NSMenu()
        providerMenu = NSMenu()
        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        providerItem.submenu = providerMenu
        statusMenu?.addItem(providerItem)

        themeMenu = NSMenu()
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        statusMenu?.addItem(themeItem)

        let loginItem = NSMenuItem(title: "Запускать при входе", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        statusMenu?.addItem(loginItem)
        self.loginItem = loginItem

        statusMenu?.addItem(.separator())
        statusMenu?.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
    }

    /// Заполняет подменю Provider текущими VPN из системы
    func rebuildProviderMenu() {
        providerMenu?.removeAllItems()

        let names = VPNStatusChecker.availableVPNNames()
        if names.isEmpty {
            providerMenu?.addItem(NSMenuItem(title: "Нет VPN-подключений", action: nil, keyEquivalent: ""))
        }

        for name in names {
            let item = NSMenuItem(title: name, action: #selector(selectProvider(_:)), keyEquivalent: "")
            item.target = self
            item.state = name == vpnStatus.name ? .on : .off   // галочка у текущего
            providerMenu?.addItem(item)
        }
    }

    /// Заполняет подменю Theme: у каждой темы образец цветов и галочка у текущей
    func rebuildThemeMenu() {
        themeMenu?.removeAllItems()

        let current = Theme.saved
        for theme in Theme.allCases {
            let item = NSMenuItem(title: theme.rawValue, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.rawValue
            item.image = theme.swatch
            item.state = theme == current ? .on : .off
            themeMenu?.addItem(item)
        }
    }

    @objc func selectTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        // StatusBarView читает этот ключ через @AppStorage и перекрашивается сам
        UserDefaults.standard.set(raw, forKey: Theme.storageKey)
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            print("Автозапуск: \(error)")
        }
        // macOS может попросить подтвердить автозапуск в настройках
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    @objc func selectProvider(_ sender: NSMenuItem) {
        vpnStatus.name = sender.title
        vpnStatus.start()
    }

    @objc func handleClick(sender: NSStatusBarButton) {
        guard let currentEvent = NSApp.currentEvent else { return }

        if currentEvent.type == .rightMouseUp {
            if let menu = statusMenu {
                rebuildProviderMenu()
                rebuildThemeMenu()
                loginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
                statusItem?.menu = menu
                statusItem?.button?.performClick(nil)
                statusItem?.menu = nil
            }
        } else if currentEvent.type == .leftMouseUp {
            vpnStatus.clicks += 1
            vpnStatus.toggleVPN() // Переключаем иконку после изменения состояния VPN
        }
    }
}

struct StatusBarView: View {
    @ObservedObject var vpnStatus: VPNStatusChecker
    @AppStorage(Theme.storageKey) private var theme: Theme = Theme.standard

    private var statusColor: Color {
        switch vpnStatus.status {
        case .connected: theme.connected
        case .connecting: theme.connecting
        case .disconnecting: theme.disconnecting
        case .disconnected: .clear
        default: .clear
        }
    }

    var body: some View {
        ZStack {
            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.primary, statusColor)
                .animation(.easeInOut(duration: 0.3), value: statusColor)
                .symbolEffect(.bounce.down.byLayer, options: .nonRepeating, value: vpnStatus.clicks)
                .symbolEffect(.pulse, isActive: vpnStatus.status == .connected)
        }.frame(width: 36, height: 22)
            .cornerRadius(12)
            .onAppear {
                vpnStatus.start()
            }
    }
}
