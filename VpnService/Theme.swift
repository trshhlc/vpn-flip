//
//  Theme.swift
//  VpnService
//

import SwiftUI

/// Сочетание цветов круга иконки: включается → включён → выключается.
/// Сами цвета лежат в Assets, у каждого свой вариант для светлой и тёмной строки меню.
enum Theme: String, CaseIterable {
    case steel, halo, moon, garden, blood

    /// Ключ в UserDefaults, где хранится выбранная тема
    static let storageKey = "theme"
    static let standard: Theme = .steel

    /// Тема, сохранённая в настройках (или стандартная, если ещё не выбирали)
    static var saved: Theme {
        Theme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? standard
    }

    /// Имена цветов из Assets по порядку: включается, включён, выключается
    var colorNames: [String] {
        switch self {
        case .steel: ["frost", "steel", "dusk"]
        case .halo: ["blush", "bronze", "ash"]
        case .moon: ["mist", "moon", "pewter"]
        case .garden: ["blush", "moss", "bronze"]
        case .blood: ["ember", "garnet", "ash"]
        }
    }

    var connecting: Color { Color(colorNames[0]) }
    var connected: Color { Color(colorNames[1]) }
    var disconnecting: Color { Color(colorNames[2]) }

    /// Образец для пункта меню: три кружка цветов темы.
    /// Рисуется в момент показа меню, поэтому цвета сами берут вариант под светлую или тёмную тему.
    var swatch: NSImage {
        let size: CGFloat = 10, gap: CGFloat = 3
        let names = colorNames
        let image = NSImage(size: NSSize(width: size * 3 + gap * 2, height: size), flipped: false) { _ in
            for (i, name) in names.enumerated() {
                NSColor(named: name)?.setFill()
                NSBezierPath(ovalIn: NSRect(x: CGFloat(i) * (size + gap), y: 0, width: size, height: size)).fill()
            }
            return true
        }
        return image
    }
}
