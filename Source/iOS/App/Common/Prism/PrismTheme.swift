// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

@objc enum PrismThemeID: Int, CaseIterable {
  case channel = 0
  case nightChannel = 1
  case cube = 2
  case prism = 3
}

/// How a theme sets its type. Each one maps to a face that ships with iOS, so nothing has to be
/// bundled and every weight renders crisply.
enum PrismTypeface {
  case rounded
  case avenir
  case standard
}

final class PrismTheme: NSObject {
  let id: PrismThemeID
  let name: String
  let tagline: String

  let interfaceStyle: UIUserInterfaceStyle
  let typeface: PrismTypeface

  let backgroundTop: UIColor
  let backgroundBottom: UIColor
  let stripe: UIColor
  let glow: UIColor

  let tile: UIColor
  let tileBorder: UIColor
  let tileShadow: UIColor
  let tileText: UIColor

  let accent: UIColor
  let primaryText: UIColor
  let secondaryText: UIColor

  let dock: UIColor
  let dockBorder: UIColor
  let dockButton: UIColor

  let trackName: String

  init(id: PrismThemeID, name: String, tagline: String, interfaceStyle: UIUserInterfaceStyle,
       typeface: PrismTypeface, backgroundTop: UIColor, backgroundBottom: UIColor, stripe: UIColor,
       glow: UIColor, tile: UIColor, tileBorder: UIColor, tileShadow: UIColor, tileText: UIColor,
       accent: UIColor, primaryText: UIColor, secondaryText: UIColor, dock: UIColor,
       dockBorder: UIColor, dockButton: UIColor, trackName: String) {
    self.id = id
    self.name = name
    self.tagline = tagline
    self.interfaceStyle = interfaceStyle
    self.typeface = typeface
    self.backgroundTop = backgroundTop
    self.backgroundBottom = backgroundBottom
    self.stripe = stripe
    self.glow = glow
    self.tile = tile
    self.tileBorder = tileBorder
    self.tileShadow = tileShadow
    self.tileText = tileText
    self.accent = accent
    self.primaryText = primaryText
    self.secondaryText = secondaryText
    self.dock = dock
    self.dockBorder = dockBorder
    self.dockButton = dockButton
    self.trackName = trackName
  }

  func font(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
    switch typeface {
    case .rounded:
      let base = UIFont.systemFont(ofSize: size, weight: weight)
      if let descriptor = base.fontDescriptor.withDesign(.rounded) {
        return UIFont(descriptor: descriptor, size: size)
      }
      return base
    case .avenir:
      let name: String
      switch weight {
      case .heavy, .black:
        name = "AvenirNext-Heavy"
      case .bold:
        name = "AvenirNext-Bold"
      case .semibold:
        name = "AvenirNext-DemiBold"
      case .medium:
        name = "AvenirNext-Medium"
      default:
        name = "AvenirNext-Regular"
      }
      return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    case .standard:
      return UIFont.systemFont(ofSize: size, weight: weight)
    }
  }

  /// Monospaced digits keep the dock clock from jittering as the minutes change.
  func clockFont(size: CGFloat) -> UIFont {
    let base = font(size: size, weight: .light)
    // kNumberSpacingType (6) / kMonospacedNumbersSelector (0), spelled out so this does not
    // depend on which name the current SDK gives the feature keys.
    let settings: [[UIFontDescriptor.FeatureKey: Int]] = [[
      UIFontDescriptor.FeatureKey(rawValue: "CTFeatureTypeIdentifier"): 6,
      UIFontDescriptor.FeatureKey(rawValue: "CTFeatureSelectorIdentifier"): 0
    ]]
    let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: settings])
    return UIFont(descriptor: descriptor, size: size)
  }

  static func hex(_ value: UInt32, alpha: CGFloat = 1) -> UIColor {
    return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                   green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255,
                   alpha: alpha)
  }

  static let all: [PrismTheme] = [
    PrismTheme(
      id: .channel, name: "Channel", tagline: "Bright, soft and familiar.",
      interfaceStyle: .light, typeface: .rounded,
      backgroundTop: hex(0xF7F8FA), backgroundBottom: hex(0xE4E8ED),
      stripe: hex(0xD5DBE2, alpha: 0.55), glow: hex(0x34BEED, alpha: 0.10),
      tile: hex(0xFFFFFF), tileBorder: hex(0xC6CFD9), tileShadow: hex(0x8C9AAB, alpha: 0.35),
      tileText: hex(0x50565E),
      accent: hex(0x2FB4E8), primaryText: hex(0x4A4F57), secondaryText: hex(0x8B929B),
      dock: hex(0xF4F5F7, alpha: 0.96), dockBorder: hex(0xBFC8D2), dockButton: hex(0xFFFFFF),
      trackName: "Prism-Plaza"),
    PrismTheme(
      id: .nightChannel, name: "Night Channel", tagline: "The same room after lights-out.",
      interfaceStyle: .dark, typeface: .rounded,
      backgroundTop: hex(0x161B22), backgroundBottom: hex(0x0B0E12),
      stripe: hex(0x232A33, alpha: 0.6), glow: hex(0x4FC3F7, alpha: 0.10),
      tile: hex(0x1D232C), tileBorder: hex(0x323D4A), tileShadow: hex(0x000000, alpha: 0.6),
      tileText: hex(0xC9D2DC),
      accent: hex(0x5CCBF7), primaryText: hex(0xE1E7EE), secondaryText: hex(0x8995A3),
      dock: hex(0x141920, alpha: 0.96), dockBorder: hex(0x2B3440), dockButton: hex(0x222A34),
      trackName: "Prism-Lamplight"),
    PrismTheme(
      id: .cube, name: "Cube", tagline: "Indigo plastic and chunky type.",
      interfaceStyle: .dark, typeface: .avenir,
      backgroundTop: hex(0x2E2560), backgroundBottom: hex(0x17123A),
      stripe: hex(0x3B3175, alpha: 0.45), glow: hex(0xB4A4FF, alpha: 0.16),
      tile: hex(0x382E73), tileBorder: hex(0x5B4EA6), tileShadow: hex(0x0B0820, alpha: 0.6),
      tileText: hex(0xEDE9FF),
      accent: hex(0xB9A8FF), primaryText: hex(0xF1EEFF), secondaryText: hex(0xA79FD6),
      dock: hex(0x251E52, alpha: 0.96), dockBorder: hex(0x4C4196), dockButton: hex(0x3A3078),
      trackName: "Prism-Boot"),
    PrismTheme(
      id: .prism, name: "Prism", tagline: "Dark glass with a little spectrum.",
      interfaceStyle: .dark, typeface: .standard,
      backgroundTop: hex(0x120F2B), backgroundBottom: hex(0x05040E),
      stripe: hex(0xFFFFFF, alpha: 0.025), glow: hex(0x8F7CFF, alpha: 0.22),
      tile: hex(0xFFFFFF, alpha: 0.06), tileBorder: hex(0xFFFFFF, alpha: 0.14),
      tileShadow: hex(0x000000, alpha: 0.7), tileText: hex(0xF2F0FF),
      accent: hex(0x9C8BFF), primaryText: hex(0xF4F2FF), secondaryText: hex(0x9A95BC),
      dock: hex(0x100D24, alpha: 0.94), dockBorder: hex(0xFFFFFF, alpha: 0.10),
      dockButton: hex(0xFFFFFF, alpha: 0.08),
      trackName: "Prism-Refraction"),
  ]
}

extension Notification.Name {
  static let prismThemeDidChange = Notification.Name("PrismThemeDidChange")
}

@objc final class PrismThemeManager: NSObject {
  @objc static let shared = PrismThemeManager()

  private let themeKey = "prism_theme"

  private override init() {
    super.init()
  }

  var current: PrismTheme {
    let id = PrismThemeID(rawValue: UserDefaults.standard.integer(forKey: themeKey)) ?? .channel
    return PrismTheme.all.first { $0.id == id } ?? PrismTheme.all[0]
  }

  @objc var currentID: PrismThemeID {
    return current.id
  }

  func select(_ id: PrismThemeID) {
    guard id != currentID else {
      return
    }

    UserDefaults.standard.set(id.rawValue, forKey: themeKey)
    applyToApp()
    NotificationCenter.default.post(name: .prismThemeDidChange, object: nil)
  }

  /// Pushes the theme into the global UIKit chrome: window style, tint and bar typography.
  @objc func applyToApp() {
    let theme = current

    let navigationAppearance = UINavigationBar.appearance()
    navigationAppearance.titleTextAttributes = [.font: theme.font(size: 17, weight: .semibold)]
    navigationAppearance.largeTitleTextAttributes = [.font: theme.font(size: 32, weight: .bold)]

    let barButton = UIBarButtonItem.appearance()
    barButton.setTitleTextAttributes([.font: theme.font(size: 17, weight: .regular)], for: .normal)
    barButton.setTitleTextAttributes([.font: theme.font(size: 17, weight: .regular)], for: .highlighted)

    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else {
        continue
      }

      for window in windowScene.windows {
        window.overrideUserInterfaceStyle = theme.interfaceStyle
        window.tintColor = theme.accent

        // UIAppearance only affects views created afterwards, so refresh the live bars too.
        refreshBars(in: window.rootViewController, theme: theme)
      }
    }
  }

  private func refreshBars(in controller: UIViewController?, theme: PrismTheme) {
    guard let controller = controller else {
      return
    }

    if let navigation = controller as? UINavigationController {
      let bar = navigation.navigationBar
      bar.titleTextAttributes = [.font: theme.font(size: 17, weight: .semibold)]
      bar.largeTitleTextAttributes = [.font: theme.font(size: 32, weight: .bold)]
      bar.tintColor = theme.accent
    }

    for child in controller.children {
      refreshBars(in: child, theme: theme)
    }

    refreshBars(in: controller.presentedViewController, theme: theme)
  }
}
