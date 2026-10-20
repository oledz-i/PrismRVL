// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit
import UniformTypeIdentifiers

// MARK: - Option list

/// A single-choice list used for themes, Wii Remote styles and performance presets.
final class PrismOptionListViewController: UITableViewController {
  struct Option {
    let title: String
    let detail: String?
    let symbol: String?
    let swatch: UIImage?
  }

  private let options: [Option]
  private var selectedIndex: Int
  private let footer: String?
  private let onSelect: (Int) -> Void

  init(title: String, options: [Option], selectedIndex: Int, footer: String? = nil,
       onSelect: @escaping (Int) -> Void) {
    self.options = options
    self.selectedIndex = selectedIndex
    self.footer = footer
    self.onSelect = onSelect
    super.init(style: .insetGrouped)
    self.title = title
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "option")
    tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "footer")
    tableView.estimatedSectionFooterHeight = 44
    tableView.sectionFooterHeight = UITableView.automaticDimension
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tableView.reloadData()
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return options.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let theme = PrismThemeManager.shared.current
    let option = options[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "option", for: indexPath)

    var content = UIListContentConfiguration.subtitleCell()
    content.text = option.title
    content.textProperties.font = theme.font(size: 17, weight: .medium)
    content.secondaryText = option.detail
    content.secondaryTextProperties.font = theme.font(size: 13)
    content.secondaryTextProperties.color = .secondaryLabel
    content.textToSecondaryTextVerticalPadding = 3

    if let swatch = option.swatch {
      content.image = swatch
      content.imageProperties.cornerRadius = 8
      content.imageProperties.maximumSize = CGSize(width: 44, height: 44)
    } else if let symbol = option.symbol {
      content.image = UIImage(systemName: symbol)
      content.imageProperties.tintColor = theme.accent
      content.imageProperties.maximumSize = CGSize(width: 28, height: 28)
      content.imageProperties.reservedLayoutSize = CGSize(width: 30, height: 28)
    }

    cell.contentConfiguration = content
    cell.accessoryType = indexPath.row == selectedIndex ? .checkmark : .none
    cell.tintColor = theme.accent

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    guard indexPath.row != selectedIndex else {
      return
    }

    selectedIndex = indexPath.row
    PrismAmbience.shared.playSelect()
    onSelect(indexPath.row)
    tableView.reloadData()
  }

  override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    guard let footer = footer else {
      return nil
    }

    let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "footer") ?? UITableViewHeaderFooterView(reuseIdentifier: "footer")
    var content = UIListContentConfiguration.groupedFooter()
    content.text = footer
    content.textProperties.font = PrismThemeManager.shared.current.font(size: 13)
    view.contentConfiguration = content
    return view
  }
}

// MARK: - Credits

final class PrismCreditsViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Credits & Licenses"
    view.backgroundColor = .systemGroupedBackground

    let theme = PrismThemeManager.shared.current

    let textView = UITextView()
    textView.translatesAutoresizingMaskIntoConstraints = false
    textView.isEditable = false
    textView.backgroundColor = .clear
    textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 32, right: 16)
    textView.dataDetectorTypes = [.link]

    let body = theme.font(size: 15)
    let heading = theme.font(size: 17, weight: .semibold)

    let text = NSMutableAttributedString()

    func add(_ title: String, _ paragraph: String) {
      text.append(NSAttributedString(string: title + "\n", attributes: [.font: heading, .foregroundColor: UIColor.label]))
      text.append(NSAttributedString(string: paragraph + "\n\n", attributes: [.font: body, .foregroundColor: UIColor.secondaryLabel]))
    }

    add("PrismRVL", "A GameCube and Wii emulator for iPhone and iPad. Free software under the GNU General "
        + "Public License, version 2 or later. Source code: https://github.com/oledz-i/PrismRVL")
    add("Dolphin", "The emulation core. © 2003-2015+ Dolphin Team. GPLv2 or later. https://dolphin-emu.org")
    add("DolphiniOS", "The iOS port PrismRVL grew out of. © 2019-2024+ DolphiniOS Project and contributors. "
        + "GPLv2 or later.")
    add("StikDebug", "PrismRVL's JIT setup follows the StikDebug universal.js protocol. Thanks to the "
        + "StikDebug and idevice developers.")
    add("Music & Sound", "The menu music, interface sounds and the PrismRVL icon are original works made for "
        + "PrismRVL. You can swap in your own track under Settings > Menu Track.")
    add("Nintendo", "The home screen is a tribute to the Wii Menu. “Wii”, “GameCube” and “Nintendo” are "
        + "trademarks of Nintendo. PrismRVL is not affiliated with or endorsed by Nintendo. Please only "
        + "play games you own.")
    add("Third-Party Libraries", "Dolphin bundles a number of open-source libraries. Their licenses ship with "
        + "the source code under Externals/ and LICENSES/.")

    textView.attributedText = text

    view.addSubview(textView)
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.topAnchor),
      textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
    ])
  }
}

// MARK: - Settings

@objc(PrismSettingsViewController) final class PrismSettingsViewController: UITableViewController,
  UIDocumentPickerDelegate {

  private enum Row {
    case theme
    case music
    case volume
    case track
    case sounds
    case wiiStyle
    case upright
    case wiiInput
    case gameCubeInput
    case remembered
    case preset
    case underclock
    case fps
    case emulatorSettings
    case version
    case core
    case source
    case credits
  }

  private struct Section {
    let title: String
    let footer: String?
    let rows: [Row]
  }

  private var sections: [Section] = []

  @objc static func makeNavigationController() -> UINavigationController {
    let controller = PrismSettingsViewController(style: .insetGrouped)
    let navigation = UINavigationController(rootViewController: controller)
    navigation.navigationBar.prefersLargeTitles = true
    navigation.modalPresentationStyle = .formSheet
    return navigation
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "Settings"
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                                        action: #selector(doneTapped))

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
    tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "footer")
    tableView.estimatedSectionHeaderHeight = 38
    tableView.sectionHeaderHeight = UITableView.automaticDimension
    tableView.estimatedSectionFooterHeight = 44
    tableView.sectionFooterHeight = UITableView.automaticDimension

    NotificationCenter.default.addObserver(self, selector: #selector(themeChanged),
                                           name: .prismThemeDidChange, object: nil)

    buildSections()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    buildSections()
    tableView.reloadData()
  }

  @objc private func doneTapped() {
    PrismAmbience.shared.playBack()
    dismiss(animated: true)
  }

  @objc private func themeChanged() {
    navigationController?.view.tintColor = PrismThemeManager.shared.current.accent
    tableView.reloadData()
  }

  private func buildSections() {
    var lookRows: [Row] = [.theme, .music]
    if PrismAmbience.shared.musicEnabled {
      lookRows.append(contentsOf: [.volume, .track])
    }
    lookRows.append(.sounds)

    var wiiRows: [Row] = [.wiiStyle, .upright, .wiiInput, .gameCubeInput]
    if PrismInput.rememberedStyleCount() > 0 {
      wiiRows.append(.remembered)
    }

    sections = [
      Section(title: "Look & Sound", footer: nil, rows: lookRows),
      Section(title: "Controllers",
              footer: "You can also change the Wii Remote style during a game from the pull-down menu, "
                + "and have PrismRVL remember it for that game.",
              rows: wiiRows),
      Section(title: "Performance",
              footer: "Presets sit on top of your graphics settings. Per-game fixes from the Dolphin "
                + "database still take priority.",
              rows: [.preset, .underclock, .fps]),
      Section(title: "Emulator", footer: nil, rows: [.emulatorSettings]),
      Section(title: "About", footer: nil, rows: [.version, .core, .source, .credits]),
    ]
  }

  // MARK: Table

  override func numberOfSections(in tableView: UITableView) -> Int {
    return sections.count
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return sections[section].rows.count
  }

  override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") ?? UITableViewHeaderFooterView(reuseIdentifier: "header")
    var content = UIListContentConfiguration.groupedHeader()
    content.text = sections[section].title
    content.textProperties.font = PrismThemeManager.shared.current.font(size: 13, weight: .semibold)
    view.contentConfiguration = content
    return view
  }

  override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    guard let footer = sections[section].footer else {
      return nil
    }

    let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "footer") ?? UITableViewHeaderFooterView(reuseIdentifier: "footer")
    var content = UIListContentConfiguration.groupedFooter()
    content.text = footer
    content.textProperties.font = PrismThemeManager.shared.current.font(size: 13)
    view.contentConfiguration = content
    return view
  }

  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return sections[section].footer == nil ? 12 : UITableView.automaticDimension
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let theme = PrismThemeManager.shared.current
    let row = sections[indexPath.section].rows[indexPath.row]

    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.tintColor = theme.accent

    var content = UIListContentConfiguration.valueCell()
    content.textProperties.font = theme.font(size: 17)
    content.secondaryTextProperties.font = theme.font(size: 17)
    content.secondaryTextProperties.color = .secondaryLabel

    func symbol(_ name: String) {
      content.image = UIImage(systemName: name)
      content.imageProperties.tintColor = theme.accent
      content.imageProperties.reservedLayoutSize = CGSize(width: 28, height: 0)
    }

    switch row {
    case .theme:
      symbol("paintpalette")
      content.text = "Theme"
      content.secondaryText = theme.name
      cell.accessoryType = .disclosureIndicator
    case .music:
      symbol("music.note")
      content.text = "Menu Music"
      cell.accessoryView = makeSwitch(isOn: PrismAmbience.shared.musicEnabled, action: #selector(musicToggled(_:)))
      cell.selectionStyle = .none
    case .volume:
      symbol("speaker.wave.2")
      content.text = "Volume"
      let slider = UISlider()
      slider.minimumValue = 0
      slider.maximumValue = 1
      slider.value = PrismAmbience.shared.volume
      slider.minimumTrackTintColor = theme.accent
      slider.addTarget(self, action: #selector(volumeChanged(_:)), for: .valueChanged)
      slider.frame = CGRect(x: 0, y: 0, width: 170, height: 34)
      cell.accessoryView = slider
      cell.selectionStyle = .none
    case .track:
      symbol("waveform")
      content.text = "Menu Track"
      if PrismAmbience.shared.useCustomTrack {
        content.secondaryText = PrismAmbience.shared.customTrackName ?? "Custom"
      } else {
        content.secondaryText = "Theme Music"
      }
      cell.accessoryType = .disclosureIndicator
    case .sounds:
      symbol("speaker.badge.exclamationmark")
      content.text = "Interface Sounds"
      cell.accessoryView = makeSwitch(isOn: PrismAmbience.shared.menuSoundsEnabled, action: #selector(soundsToggled(_:)))
      cell.selectionStyle = .none
    case .wiiStyle:
      symbol(PrismInput.symbolName(for: PrismInput.currentWiiStyle()))
      content.text = "Wii Remote"
      content.secondaryText = shortName(for: PrismInput.currentWiiStyle())
      cell.accessoryType = .disclosureIndicator
    case .upright:
      symbol("arrow.up.to.line")
      content.text = "Hold Upright"
      cell.accessoryView = makeSwitch(isOn: PrismInput.uprightWiiRemote, action: #selector(uprightToggled(_:)))
      cell.selectionStyle = .none
    case .wiiInput:
      symbol("hand.tap")
      content.text = "Wii Input"
      cell.accessoryView = makeSourcePicker(selected: PrismInput.wiiInputSource, action: #selector(wiiSourceChanged(_:)))
      cell.selectionStyle = .none
    case .gameCubeInput:
      symbol("gamecontroller")
      content.text = "GameCube Input"
      cell.accessoryView = makeSourcePicker(selected: PrismInput.gameCubeInputSource, action: #selector(gameCubeSourceChanged(_:)))
      cell.selectionStyle = .none
    case .remembered:
      symbol("pin")
      let count = PrismInput.rememberedStyleCount()
      content.text = count == 1 ? "1 Game Remembered" : "\(count) Games Remembered"
      content.secondaryText = "Forget All"
      content.secondaryTextProperties.color = .systemRed
    case .preset:
      symbol("speedometer")
      content.text = "Preset"
      content.secondaryText = PrismPerformance.presetName(PrismPerformance.preset)
      cell.accessoryType = .disclosureIndicator
    case .underclock:
      symbol("tortoise")
      content.text = "CPU Speed Without JIT"
      content.secondaryText = PrismPerformance.underclockName(PrismPerformance.noJitUnderclock)
      cell.accessoryType = .disclosureIndicator
    case .fps:
      symbol("chart.bar")
      content.text = "Show FPS"
      cell.accessoryView = makeSwitch(isOn: PrismPerformance.showPerformanceOverlay, action: #selector(fpsToggled(_:)))
      cell.selectionStyle = .none
    case .emulatorSettings:
      symbol("slider.horizontal.3")
      content.text = "All Emulator Settings"
      content.secondaryText = "Graphics, Audio, Mapping"
      cell.accessoryType = .disclosureIndicator
    case .version:
      symbol("app.badge")
      content.text = "PrismRVL"
      content.secondaryText = VersionManager.shared().appVersion.userFacing
      cell.selectionStyle = .none
    case .core:
      symbol("cpu")
      content.text = "Dolphin Core"
      content.secondaryText = VersionManager.shared().coreVersion
      cell.selectionStyle = .none
    case .source:
      symbol("chevron.left.forwardslash.chevron.right")
      content.text = "Source Code"
      cell.accessoryType = .disclosureIndicator
    case .credits:
      symbol("heart.text.square")
      content.text = "Credits & Licenses"
      cell.accessoryType = .disclosureIndicator
    }

    cell.contentConfiguration = content
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    let row = sections[indexPath.section].rows[indexPath.row]

    switch row {
    case .theme:
      showThemePicker()
    case .track:
      showTrackOptions(from: tableView.cellForRow(at: indexPath))
    case .wiiStyle:
      showWiiStylePicker()
    case .remembered:
      confirmForgetRemembered()
    case .preset:
      showPresetPicker()
    case .underclock:
      showUnderclockPicker()
    case .emulatorSettings:
      showEmulatorSettings()
    case .source:
      if let url = URL(string: "https://github.com/oledz-i/PrismRVL") {
        UIApplication.shared.open(url)
      }
    case .credits:
      navigationController?.pushViewController(PrismCreditsViewController(), animated: true)
    default:
      break
    }
  }

  // MARK: Controls

  private func makeSwitch(isOn: Bool, action: Selector) -> UISwitch {
    let control = UISwitch()
    control.isOn = isOn
    control.onTintColor = PrismThemeManager.shared.current.accent
    control.addTarget(self, action: action, for: .valueChanged)
    return control
  }

  private func makeSourcePicker(selected: PrismInputSource, action: Selector) -> UISegmentedControl {
    let control = UISegmentedControl(items: ["Touch", "Controller"])
    switch selected {
    case .touchscreen:
      control.selectedSegmentIndex = 0
    case .physicalController:
      control.selectedSegmentIndex = 1
    default:
      control.selectedSegmentIndex = UISegmentedControl.noSegment
    }
    control.addTarget(self, action: action, for: .valueChanged)
    control.sizeToFit()
    return control
  }

  @objc private func musicToggled(_ sender: UISwitch) {
    PrismAmbience.shared.musicEnabled = sender.isOn
    buildSections()
    tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
  }

  @objc private func volumeChanged(_ sender: UISlider) {
    PrismAmbience.shared.volume = sender.value
  }

  @objc private func soundsToggled(_ sender: UISwitch) {
    PrismAmbience.shared.menuSoundsEnabled = sender.isOn
    PrismAmbience.shared.playSelect()
  }

  @objc private func uprightToggled(_ sender: UISwitch) {
    PrismInput.uprightWiiRemote = sender.isOn
  }

  @objc private func wiiSourceChanged(_ sender: UISegmentedControl) {
    PrismInput.wiiInputSource = sender.selectedSegmentIndex == 0 ? .touchscreen : .physicalController
  }

  @objc private func gameCubeSourceChanged(_ sender: UISegmentedControl) {
    PrismInput.gameCubeInputSource = sender.selectedSegmentIndex == 0 ? .touchscreen : .physicalController
  }

  @objc private func fpsToggled(_ sender: UISwitch) {
    PrismPerformance.showPerformanceOverlay = sender.isOn
  }

  // MARK: Pickers

  private func shortName(for style: PrismWiiStyle) -> String {
    switch style {
    case .vertical:
      return "Vertical"
    case .sideways:
      return "Sideways"
    case .nunchuk:
      return "+ Nunchuk"
    case .motionPlus:
      return "+ MotionPlus"
    case .nunchukMotionPlus:
      return "+ Nunchuk + M+"
    case .classic:
      return "Classic"
    @unknown default:
      return ""
    }
  }

  private func showThemePicker() {
    let themes = PrismTheme.all
    let options = themes.map {
      PrismOptionListViewController.Option(title: $0.name, detail: $0.tagline, symbol: nil,
                                           swatch: PrismSettingsViewController.swatch(for: $0))
    }
    let selected = themes.firstIndex { $0.id == PrismThemeManager.shared.currentID } ?? 0

    let picker = PrismOptionListViewController(title: "Theme", options: options, selectedIndex: selected,
                                               footer: "Each theme has its own type and menu music.") { index in
      let theme = themes[index]
      PrismThemeManager.shared.select(theme.id)
      PrismAmbience.shared.preview(theme: theme)
    }
    navigationController?.pushViewController(picker, animated: true)
  }

  private func showWiiStylePicker() {
    let styles: [PrismWiiStyle] = PrismInput.allWiiStyles.compactMap { PrismWiiStyle(rawValue: $0.integerValue) }
    let options = styles.map {
      PrismOptionListViewController.Option(title: PrismInput.name(for: $0), detail: PrismInput.detail(for: $0),
                                           symbol: PrismInput.symbolName(for: $0), swatch: nil)
    }
    let selected = styles.firstIndex(of: PrismInput.currentWiiStyle()) ?? 0

    let picker = PrismOptionListViewController(title: "Wii Remote", options: options, selectedIndex: selected,
                                               footer: "The touch controls switch to match. Sideways and Classic "
                                                 + "get their own layouts, the others share the standard one.") { index in
      PrismInput.apply(styles[index])
    }
    navigationController?.pushViewController(picker, animated: true)
  }

  private func showPresetPicker() {
    let presets: [PrismPerformancePreset] = [.quality, .balanced, .performance]
    let options = presets.map {
      PrismOptionListViewController.Option(title: PrismPerformance.presetName($0),
                                           detail: PrismPerformance.presetDetail($0), symbol: nil, swatch: nil)
    }
    let selected = presets.firstIndex(of: PrismPerformance.preset) ?? 1

    let picker = PrismOptionListViewController(title: "Preset", options: options, selectedIndex: selected,
                                               footer: "Takes effect the next time you start a game.") { index in
      PrismPerformance.preset = presets[index]
    }
    navigationController?.pushViewController(picker, animated: true)
  }

  private func showUnderclockPicker() {
    let levels: [PrismNoJitUnderclock] = [.off, .light, .medium, .strong]
    let details = [
      "Full speed CPU. Most accurate.",
      "A small cut that most games never notice.",
      "Noticeably faster without JIT. Some games may slow down in busy scenes.",
      "Fastest. Expect timing quirks in demanding games.",
    ]
    let options = levels.enumerated().map {
      PrismOptionListViewController.Option(title: PrismPerformance.underclockName($0.element),
                                           detail: details[$0.offset], symbol: nil, swatch: nil)
    }
    let selected = levels.firstIndex(of: PrismPerformance.noJitUnderclock) ?? 0

    let picker = PrismOptionListViewController(title: "CPU Speed Without JIT", options: options,
                                               selectedIndex: selected,
                                               footer: "Only used when a game runs without JIT. Lowering the "
                                                 + "emulated CPU speed gives the interpreter more headroom.") { index in
      PrismPerformance.noJitUnderclock = levels[index]
    }
    navigationController?.pushViewController(picker, animated: true)
  }

  private func confirmForgetRemembered() {
    let alert = UIAlertController(title: "Forget Remembered Styles?",
                                  message: "Games will start with your default Wii Remote style.",
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Forget All", style: .destructive) { _ in
      PrismInput.forgetAllRememberedStyles()
      self.buildSections()
      self.tableView.reloadData()
    })
    present(alert, animated: true)
  }

  private func showEmulatorSettings() {
    let storyboard = UIStoryboard(name: "SettingsRoot", bundle: nil)

    guard let controller = storyboard.instantiateInitialViewController() else {
      return
    }

    if let navigation = controller as? UINavigationController, let root = navigation.viewControllers.first {
      root.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                                               action: #selector(dismissEmulatorSettings))
    }

    controller.modalPresentationStyle = .formSheet
    present(controller, animated: true)
  }

  @objc private func dismissEmulatorSettings() {
    presentedViewController?.dismiss(animated: true)
  }

  // MARK: Menu track

  private func showTrackOptions(from cell: UITableViewCell?) {
    let sheet = UIAlertController(title: "Menu Track", message: nil, preferredStyle: .actionSheet)

    sheet.addAction(UIAlertAction(title: "Use Theme Music", style: .default) { _ in
      PrismAmbience.shared.useCustomTrack = false
      self.tableView.reloadData()
    })

    sheet.addAction(UIAlertAction(title: "Choose Audio File…", style: .default) { _ in
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      self.present(picker, animated: true)
    })

    if PrismAmbience.shared.customTrackURL != nil {
      sheet.addAction(UIAlertAction(title: "Remove Custom Track", style: .destructive) { _ in
        PrismAmbience.shared.removeCustomTrack()
        self.tableView.reloadData()
      })
    }

    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

    if let popover = sheet.popoverPresentationController {
      popover.sourceView = cell ?? view
      popover.sourceRect = cell?.bounds ?? view.bounds
    }

    present(sheet, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      return
    }

    do {
      try PrismAmbience.shared.importCustomTrack(from: url)
    } catch {
      let alert = UIAlertController(title: "Couldn't Use That File",
                                    message: "Pick an audio file such as M4A, MP3, AAC or WAV.",
                                    preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
    }

    tableView.reloadData()
  }

  // MARK: Swatches

  static func swatch(for theme: PrismTheme) -> UIImage {
    let size = CGSize(width: 44, height: 44)
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { context in
      let rect = CGRect(origin: .zero, size: size)
      let cg = context.cgContext

      let colors = [theme.backgroundTop.cgColor, theme.backgroundBottom.cgColor] as CFArray
      if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
      }

      let tileRect = CGRect(x: 8, y: 9, width: 28, height: 18)
      let tile = UIBezierPath(roundedRect: tileRect, cornerRadius: 5)
      theme.tile.setFill()
      tile.fill()
      theme.tileBorder.setStroke()
      tile.lineWidth = 1.5
      tile.stroke()

      let dock = UIBezierPath(rect: CGRect(x: 0, y: 32, width: size.width, height: 12))
      theme.dock.withAlphaComponent(1).setFill()
      dock.fill()

      theme.accent.setFill()
      UIBezierPath(ovalIn: CGRect(x: 18, y: 34, width: 8, height: 8)).fill()

      UIColor.black.withAlphaComponent(0.12).setStroke()
      let outline = UIBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
      outline.lineWidth = 1
      outline.stroke()
    }
  }
}
