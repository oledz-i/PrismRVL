// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

// MARK: - Grid metrics

/// Sizes for the channel grid. The home screen always shows at least three full rows so an empty
/// or small library still reads as a board of slots rather than a sparse list.
@objc(PrismHomeMetrics) final class PrismHomeMetrics: NSObject {
  @objc static let margin: CGFloat = 20
  @objc static let spacing: CGFloat = 14
  @objc static let tileAspect: CGFloat = 1.42
  @objc static let dockHeight: CGFloat = 104

  @objc(columnsForWidth:)
  static func columns(forWidth width: CGFloat) -> Int {
    switch width {
    case 1100...:
      return 5
    case 680...:
      return 4
    case 470...:
      return 3
    default:
      return 2
    }
  }

  @objc(slotCountForGameCount:columns:)
  static func slotCount(gameCount: Int, columns: Int) -> Int {
    let columns = max(1, columns)
    // One slot for "Add Game", then pad out to whole rows with a three-row minimum.
    let needed = max(gameCount + 1, columns * 3)
    return Int((Double(needed) / Double(columns)).rounded(.up)) * columns
  }

  @objc(itemSizeForWidth:columns:)
  static func itemSize(forWidth width: CGFloat, columns: Int) -> CGSize {
    let columns = CGFloat(max(1, columns))
    let available = width - margin * 2 - spacing * (columns - 1)
    let tileWidth = floor(available / columns)
    return CGSize(width: tileWidth, height: floor(tileWidth / tileAspect))
  }
}

// MARK: - Background

/// Soft gradient with fine horizontal pinstripes and a gentle glow near the top.
@objc(PrismHomeBackgroundView) final class PrismHomeBackgroundView: UIView {
  private let gradient = CAGradientLayer()
  private let stripes = CAReplicatorLayer()
  private let stripe = CALayer()
  private let glow = CAGradientLayer()

  private let stripePitch: CGFloat = 5

  override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }

  private func setUp() {
    isUserInteractionEnabled = false

    layer.addSublayer(gradient)
    stripes.addSublayer(stripe)
    layer.addSublayer(stripes)

    glow.type = .radial
    glow.startPoint = CGPoint(x: 0.5, y: 0.0)
    glow.endPoint = CGPoint(x: 1.15, y: 0.7)
    layer.addSublayer(glow)

    applyTheme()
  }

  @objc func applyTheme() {
    let theme = PrismThemeManager.shared.current

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    gradient.colors = [theme.backgroundTop.cgColor, theme.backgroundBottom.cgColor]
    stripe.backgroundColor = theme.stripe.cgColor
    glow.colors = [theme.glow.cgColor, theme.glow.withAlphaComponent(0).cgColor]
    CATransaction.commit()

    backgroundColor = theme.backgroundBottom
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    CATransaction.begin()
    CATransaction.setDisableActions(true)

    gradient.frame = bounds
    glow.frame = bounds

    stripes.frame = bounds
    stripe.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1)
    stripes.instanceCount = Int(ceil(bounds.height / stripePitch)) + 1
    stripes.instanceTransform = CATransform3DMakeTranslation(0, stripePitch, 0)

    CATransaction.commit()
  }
}

// MARK: - Gradient helper

final class PrismGradientView: UIView {
  override class var layerClass: AnyClass {
    return CAGradientLayer.self
  }

  var gradientLayer: CAGradientLayer {
    return layer as! CAGradientLayer
  }
}

// MARK: - Channel tile

@objc(PrismChannelCell) final class PrismChannelCell: UICollectionViewCell {
  private enum Kind {
    case game
    case add
    case empty
  }

  private let tile = UIView()
  private let clip = UIView()
  private let art = UIImageView()
  private let shade = PrismGradientView()
  private let titleLabel = UILabel()
  private let glyph = UIImageView()
  private let caption = UILabel()

  private var kind: Kind = .empty
  private var hasArt = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }

  private func setUp() {
    contentView.addSubview(tile)
    tile.translatesAutoresizingMaskIntoConstraints = false
    tile.layer.cornerRadius = 18
    tile.layer.cornerCurve = .continuous
    tile.layer.borderWidth = 2
    tile.layer.shadowOffset = CGSize(width: 0, height: 3)
    tile.layer.shadowRadius = 6
    tile.layer.shadowOpacity = 1

    tile.addSubview(clip)
    clip.translatesAutoresizingMaskIntoConstraints = false
    clip.layer.cornerRadius = 16
    clip.layer.cornerCurve = .continuous
    clip.clipsToBounds = true

    art.contentMode = .scaleAspectFill
    art.clipsToBounds = true
    art.translatesAutoresizingMaskIntoConstraints = false
    clip.addSubview(art)

    shade.translatesAutoresizingMaskIntoConstraints = false
    shade.gradientLayer.colors = [UIColor.black.withAlphaComponent(0).cgColor,
                                  UIColor.black.withAlphaComponent(0.62).cgColor]
    shade.gradientLayer.locations = [0.45, 1.0]
    clip.addSubview(shade)

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.textColor = .white
    titleLabel.numberOfLines = 1
    titleLabel.lineBreakMode = .byTruncatingTail
    clip.addSubview(titleLabel)

    glyph.translatesAutoresizingMaskIntoConstraints = false
    glyph.contentMode = .scaleAspectFit
    clip.addSubview(glyph)

    caption.translatesAutoresizingMaskIntoConstraints = false
    caption.textAlignment = .center
    caption.numberOfLines = 2
    caption.lineBreakMode = .byTruncatingTail
    caption.adjustsFontSizeToFitWidth = true
    caption.minimumScaleFactor = 0.8
    clip.addSubview(caption)

    NSLayoutConstraint.activate([
      tile.topAnchor.constraint(equalTo: contentView.topAnchor),
      tile.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      tile.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      tile.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

      clip.topAnchor.constraint(equalTo: tile.topAnchor, constant: 2),
      clip.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -2),
      clip.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 2),
      clip.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -2),

      art.topAnchor.constraint(equalTo: clip.topAnchor),
      art.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
      art.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
      art.trailingAnchor.constraint(equalTo: clip.trailingAnchor),

      shade.topAnchor.constraint(equalTo: clip.topAnchor),
      shade.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
      shade.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
      shade.trailingAnchor.constraint(equalTo: clip.trailingAnchor),

      titleLabel.leadingAnchor.constraint(equalTo: clip.leadingAnchor, constant: 10),
      titleLabel.trailingAnchor.constraint(equalTo: clip.trailingAnchor, constant: -10),
      titleLabel.bottomAnchor.constraint(equalTo: clip.bottomAnchor, constant: -7),

      glyph.centerXAnchor.constraint(equalTo: clip.centerXAnchor),
      glyph.centerYAnchor.constraint(equalTo: clip.centerYAnchor, constant: -12),
      glyph.heightAnchor.constraint(equalTo: clip.heightAnchor, multiplier: 0.3),
      glyph.widthAnchor.constraint(equalTo: glyph.heightAnchor),

      caption.topAnchor.constraint(equalTo: glyph.bottomAnchor, constant: 6),
      caption.leadingAnchor.constraint(equalTo: clip.leadingAnchor, constant: 10),
      caption.trailingAnchor.constraint(equalTo: clip.trailingAnchor, constant: -10),
    ])

    isAccessibilityElement = true
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    tile.layer.shadowPath = UIBezierPath(roundedRect: tile.bounds, cornerRadius: 18).cgPath
  }

  override var isHighlighted: Bool {
    didSet {
      guard kind != .empty else {
        return
      }

      UIView.animate(withDuration: isHighlighted ? 0.12 : 0.22, delay: 0,
                     usingSpringWithDamping: 0.7, initialSpringVelocity: 0,
                     options: [.allowUserInteraction, .beginFromCurrentState]) {
        self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
      }
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    art.image = nil
    transform = .identity
  }

  /// A game slot. `image` is the cover or banner art; without one the tile shows the platform.
  @objc(configureGameWithTitle:image:platform:symbol:)
  func configureGame(title: String, image: UIImage?, platform: String, symbol: String) {
    kind = .game
    hasArt = image != nil

    art.image = image
    art.isHidden = image == nil
    shade.isHidden = image == nil
    titleLabel.isHidden = image == nil
    titleLabel.text = title

    glyph.isHidden = image != nil
    caption.isHidden = image != nil
    glyph.image = UIImage(systemName: symbol)
    caption.text = title

    accessibilityLabel = title
    accessibilityHint = platform
    accessibilityTraits = .button

    applyTheme()
  }

  @objc func configureAddSlot() {
    kind = .add
    hasArt = false

    art.image = nil
    art.isHidden = true
    shade.isHidden = true
    titleLabel.isHidden = true

    glyph.isHidden = false
    caption.isHidden = false
    glyph.image = UIImage(systemName: "plus")
    caption.text = "Add Game"

    accessibilityLabel = "Add Game"
    accessibilityHint = nil
    accessibilityTraits = .button

    applyTheme()
  }

  @objc func configureEmptySlot() {
    kind = .empty
    hasArt = false

    art.image = nil
    art.isHidden = true
    shade.isHidden = true
    titleLabel.isHidden = true
    glyph.isHidden = true
    caption.isHidden = true

    accessibilityLabel = nil
    accessibilityHint = nil
    accessibilityTraits = .notEnabled
    isAccessibilityElement = false

    applyTheme()
  }

  private func applyTheme() {
    let theme = PrismThemeManager.shared.current

    isAccessibilityElement = kind != .empty

    tile.layer.borderColor = theme.tileBorder.cgColor
    tile.layer.shadowColor = theme.tileShadow.cgColor

    switch kind {
    case .game:
      tile.backgroundColor = theme.tile
      tile.alpha = 1
      tile.layer.shadowOpacity = 1
      clip.backgroundColor = theme.tile
      glyph.tintColor = theme.accent
      caption.textColor = theme.tileText
      caption.font = theme.font(size: 15, weight: .semibold)
      titleLabel.font = theme.font(size: 13, weight: .semibold)
    case .add:
      tile.backgroundColor = theme.tile
      tile.alpha = 0.92
      tile.layer.shadowOpacity = 0.5
      clip.backgroundColor = theme.tile
      glyph.tintColor = theme.accent
      caption.textColor = theme.secondaryText
      caption.font = theme.font(size: 14, weight: .medium)
    case .empty:
      tile.backgroundColor = theme.tile
      tile.alpha = 0.45
      tile.layer.shadowOpacity = 0
      clip.backgroundColor = theme.tile
    }
  }
}

// MARK: - Dock

private final class PrismDockButton: UIButton {
  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.borderWidth = 2
    layer.shadowOffset = CGSize(width: 0, height: 2)
    layer.shadowRadius = 5
    layer.shadowOpacity = 1
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
    layer.shadowPath = UIBezierPath(ovalIn: bounds).cgPath
  }

  override var isHighlighted: Bool {
    didSet {
      UIView.animate(withDuration: 0.15) {
        self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
      }
    }
  }

  func apply(theme: PrismTheme) {
    backgroundColor = theme.dockButton
    layer.borderColor = theme.dockBorder.cgColor
    layer.shadowColor = theme.tileShadow.cgColor
    tintColor = theme.accent
  }
}

/// The bar along the bottom of the home screen: settings on the left, the library menu on the
/// right and a clock in between.
@objc(PrismDockView) final class PrismDockView: UIView {
  @objc var onSettings: (() -> Void)?

  private let surface = CAShapeLayer()
  private let rim = CAShapeLayer()

  private let settingsButton = PrismDockButton(frame: .zero)
  private let libraryButton = PrismDockButton(frame: .zero)

  private let clockLabel = UILabel()
  private let dateLabel = UILabel()

  private var clockTimer: Timer?
  private var colonVisible = true

  private let buttonSize: CGFloat = 60

  override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }

  deinit {
    clockTimer?.invalidate()
  }

  private func setUp() {
    surface.shadowOffset = CGSize(width: 0, height: -2)
    surface.shadowRadius = 10
    surface.shadowOpacity = 1
    layer.addSublayer(surface)

    rim.fillColor = UIColor.clear.cgColor
    rim.lineWidth = 1.5
    layer.addSublayer(rim)

    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)

    settingsButton.setImage(UIImage(systemName: "gearshape.fill", withConfiguration: symbolConfiguration), for: .normal)
    settingsButton.accessibilityLabel = "Settings"
    settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

    libraryButton.setImage(UIImage(systemName: "square.grid.2x2.fill", withConfiguration: symbolConfiguration), for: .normal)
    libraryButton.accessibilityLabel = "Library"
    libraryButton.showsMenuAsPrimaryAction = true

    clockLabel.textAlignment = .center
    clockLabel.adjustsFontSizeToFitWidth = true
    clockLabel.minimumScaleFactor = 0.7
    dateLabel.textAlignment = .center

    for view in [settingsButton, libraryButton, clockLabel, dateLabel] as [UIView] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }

    NSLayoutConstraint.activate([
      settingsButton.widthAnchor.constraint(equalToConstant: buttonSize),
      settingsButton.heightAnchor.constraint(equalToConstant: buttonSize),
      settingsButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
      settingsButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),

      libraryButton.widthAnchor.constraint(equalToConstant: buttonSize),
      libraryButton.heightAnchor.constraint(equalToConstant: buttonSize),
      libraryButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
      libraryButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),

      clockLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      clockLabel.topAnchor.constraint(equalTo: topAnchor, constant: 32),
      clockLabel.leadingAnchor.constraint(greaterThanOrEqualTo: settingsButton.trailingAnchor, constant: 40),
      clockLabel.trailingAnchor.constraint(lessThanOrEqualTo: libraryButton.leadingAnchor, constant: -40),

      dateLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      dateLabel.topAnchor.constraint(equalTo: clockLabel.bottomAnchor, constant: 0),
    ])

    applyTheme()
    updateClock()
  }

  @objc func setLibraryMenu(_ menu: UIMenu) {
    libraryButton.menu = menu
  }

  @objc private func settingsTapped() {
    PrismAmbience.shared.playSelect()
    onSettings?()
  }

  @objc func applyTheme() {
    let theme = PrismThemeManager.shared.current

    surface.fillColor = theme.dock.cgColor
    surface.shadowColor = theme.tileShadow.cgColor
    rim.strokeColor = theme.dockBorder.cgColor

    settingsButton.apply(theme: theme)
    libraryButton.apply(theme: theme)

    clockLabel.textColor = theme.primaryText
    dateLabel.textColor = theme.secondaryText
    dateLabel.font = theme.font(size: 14, weight: .medium)

    updateClock()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let width = bounds.width
    let height = bounds.height

    // The surface rises around the two buttons and dips in the middle where the clock sits.
    let high: CGFloat = 2
    let low: CGFloat = 26
    let leftEdge = min(safeAreaInsets.left + 24 + buttonSize + 22, width * 0.3)
    let rightEdge = max(width - safeAreaInsets.right - 24 - buttonSize - 22, width * 0.7)
    let run: CGFloat = 46

    let top = UIBezierPath()
    top.move(to: CGPoint(x: 0, y: high))
    top.addLine(to: CGPoint(x: leftEdge, y: high))
    top.addCurve(to: CGPoint(x: leftEdge + run, y: low),
                 controlPoint1: CGPoint(x: leftEdge + run * 0.5, y: high),
                 controlPoint2: CGPoint(x: leftEdge + run * 0.5, y: low))
    top.addLine(to: CGPoint(x: rightEdge - run, y: low))
    top.addCurve(to: CGPoint(x: rightEdge, y: high),
                 controlPoint1: CGPoint(x: rightEdge - run * 0.5, y: low),
                 controlPoint2: CGPoint(x: rightEdge - run * 0.5, y: high))
    top.addLine(to: CGPoint(x: width, y: high))

    let fill = UIBezierPath(cgPath: top.cgPath)
    fill.addLine(to: CGPoint(x: width, y: height))
    fill.addLine(to: CGPoint(x: 0, y: height))
    fill.close()

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    surface.frame = bounds
    surface.path = fill.cgPath
    surface.shadowPath = fill.cgPath
    rim.frame = bounds
    rim.path = top.cgPath
    CATransaction.commit()
  }

  // MARK: Clock

  @objc func startClock() {
    stopClock()
    updateClock()

    let timer = Timer(timeInterval: 1, target: self, selector: #selector(clockTick), userInfo: nil, repeats: true)
    RunLoop.main.add(timer, forMode: .common)
    clockTimer = timer
  }

  @objc func stopClock() {
    clockTimer?.invalidate()
    clockTimer = nil
  }

  @objc private func clockTick() {
    colonVisible.toggle()
    updateClock()
  }

  private static let uses12HourClock: Bool = {
    let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current) ?? ""
    return format.contains("a")
  }()

  private static let hourFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = PrismDockView.uses12HourClock ? "h" : "HH"
    return formatter
  }()

  private static let minuteFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "mm"
    return formatter
  }()

  private static let periodFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "a"
    return formatter
  }()

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("EEEMd")
    return formatter
  }()

  private func updateClock() {
    let theme = PrismThemeManager.shared.current
    let now = Date()

    let digits = theme.clockFont(size: 38)
    let colonColor = colonVisible ? theme.primaryText : theme.primaryText.withAlphaComponent(0.25)

    let text = NSMutableAttributedString(string: PrismDockView.hourFormatter.string(from: now),
                                         attributes: [.font: digits, .foregroundColor: theme.primaryText])
    text.append(NSAttributedString(string: ":", attributes: [.font: digits, .foregroundColor: colonColor]))
    text.append(NSAttributedString(string: PrismDockView.minuteFormatter.string(from: now),
                                   attributes: [.font: digits, .foregroundColor: theme.primaryText]))

    if PrismDockView.uses12HourClock {
      text.append(NSAttributedString(string: " " + PrismDockView.periodFormatter.string(from: now),
                                     attributes: [.font: theme.font(size: 15, weight: .medium),
                                                  .foregroundColor: theme.secondaryText]))
    }

    clockLabel.attributedText = text
    dateLabel.text = PrismDockView.dateFormatter.string(from: now)

    clockLabel.accessibilityLabel = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short)
  }
}
