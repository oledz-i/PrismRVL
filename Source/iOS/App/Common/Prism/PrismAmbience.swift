// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

import AVFoundation
import AudioToolbox
import UIKit

/// Menu music and interface sounds for the home screen.
///
/// The bundled loops are original compositions written for PrismRVL. They are decoded once and
/// looped from memory so the repeat point is seamless. A custom track the user imports is streamed
/// with AVAudioPlayer instead, since it can be any length.
@objc(PrismAmbience) final class PrismAmbience: NSObject {
  @objc static let shared = PrismAmbience()

  private enum Keys {
    static let enabled = "prism_music_enabled"
    static let volume = "prism_music_volume"
    static let useCustom = "prism_music_use_custom"
    static let customName = "prism_music_custom_name"
    static let sounds = "prism_menu_sounds"
  }

  // Bundled loops.
  private let engine = AVAudioEngine()
  private let loopNode = AVAudioPlayerNode()
  private var loopBuffers: [URL: AVAudioPCMBuffer] = [:]

  // Custom track.
  private var streamPlayer: AVAudioPlayer?

  private var playingURL: URL?
  private var outputVolume: Float = 0

  private var homeVisible = false
  private var emulationRunning = false

  private var fadeTimer: Timer?
  private var fadeStartVolume: Float = 0
  private var fadeTargetVolume: Float = 0
  private var fadeStepCount = 1
  private var fadeStep = 0
  private var fadeCompletion: (() -> Void)?

  private var selectSound: SystemSoundID = 0
  private var backSound: SystemSoundID = 0

  private override init() {
    super.init()

    UserDefaults.standard.register(defaults: [
      Keys.enabled: true,
      Keys.volume: 0.45,
      Keys.useCustom: false,
      Keys.sounds: true,
    ])

    engine.attach(loopNode)

    selectSound = loadSound("Prism-Select")
    backSound = loadSound("Prism-Back")

    let center = NotificationCenter.default
    center.addObserver(self, selector: #selector(emulationDidStart),
                       name: Notification.Name("DOLEmulationDidStartNotification"), object: nil)
    center.addObserver(self, selector: #selector(emulationDidEnd),
                       name: Notification.Name("DOLEmulationDidEndNotification"), object: nil)
    center.addObserver(self, selector: #selector(themeDidChange),
                       name: .prismThemeDidChange, object: nil)
    center.addObserver(self, selector: #selector(appWillResign),
                       name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(appDidBecomeActive),
                       name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(engineConfigurationChanged),
                       name: .AVAudioEngineConfigurationChange, object: engine)
  }

  // MARK: Settings

  @objc var musicEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: Keys.enabled) }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.enabled)
      refresh()
    }
  }

  @objc var volume: Float {
    get { UserDefaults.standard.float(forKey: Keys.volume) }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.volume)
      if fadeTimer == nil, playingURL != nil {
        setOutputVolume(newValue)
      }
    }
  }

  @objc var useCustomTrack: Bool {
    get { UserDefaults.standard.bool(forKey: Keys.useCustom) && customTrackURL != nil }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.useCustom)
      refresh(restart: true)
    }
  }

  @objc var menuSoundsEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: Keys.sounds) }
    set { UserDefaults.standard.set(newValue, forKey: Keys.sounds) }
  }

  // MARK: Custom track

  private var musicDirectory: URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("PrismRVL/Music", isDirectory: true)
  }

  @objc var customTrackURL: URL? {
    let contents = (try? FileManager.default.contentsOfDirectory(at: musicDirectory,
                                                                 includingPropertiesForKeys: nil)) ?? []
    return contents.first { $0.deletingPathExtension().lastPathComponent == "Custom" }
  }

  @objc var customTrackName: String? {
    return UserDefaults.standard.string(forKey: Keys.customName)
  }

  /// Copies a user-picked audio file into the app and switches to it.
  @objc func importCustomTrack(from source: URL) throws {
    let accessing = source.startAccessingSecurityScopedResource()
    defer {
      if accessing {
        source.stopAccessingSecurityScopedResource()
      }
    }

    // Make sure the file can actually be played before replacing anything.
    _ = try AVAudioPlayer(contentsOf: source)

    try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)

    stopPlayback()

    if let existing = customTrackURL {
      try FileManager.default.removeItem(at: existing)
    }

    let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
    let destination = musicDirectory.appendingPathComponent("Custom").appendingPathExtension(ext)
    try FileManager.default.copyItem(at: source, to: destination)

    UserDefaults.standard.set(source.deletingPathExtension().lastPathComponent, forKey: Keys.customName)
    UserDefaults.standard.set(true, forKey: Keys.useCustom)
    refresh(restart: true)
  }

  @objc func removeCustomTrack() {
    stopPlayback()

    if let existing = customTrackURL {
      try? FileManager.default.removeItem(at: existing)
    }

    UserDefaults.standard.removeObject(forKey: Keys.customName)
    UserDefaults.standard.set(false, forKey: Keys.useCustom)
    refresh(restart: true)
  }

  // MARK: Home screen lifecycle

  @objc func homeDidAppear() {
    homeVisible = true
    refresh()
  }

  @objc func homeWillDisappear() {
    homeVisible = false
    refresh()
  }

  /// Switches to a theme's loop right away, for the theme picker.
  func preview(theme: PrismTheme) {
    guard musicEnabled, !useCustomTrack, !emulationRunning else {
      return
    }

    if let url = Bundle.main.url(forResource: theme.trackName, withExtension: "m4a"), url != playingURL {
      start(url: url, fadeIn: 0.6)
    }
  }

  // MARK: Interface sounds

  @objc func playSelect() {
    guard menuSoundsEnabled, selectSound != 0 else {
      return
    }

    AudioServicesPlaySystemSound(selectSound)
  }

  @objc func playBack() {
    guard menuSoundsEnabled, backSound != 0 else {
      return
    }

    AudioServicesPlaySystemSound(backSound)
  }

  private func loadSound(_ name: String) -> SystemSoundID {
    guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
      return 0
    }

    var sound: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(url as CFURL, &sound)
    return sound
  }

  // MARK: Playback

  private var desiredURL: URL? {
    if useCustomTrack, let custom = customTrackURL {
      return custom
    }

    return Bundle.main.url(forResource: PrismThemeManager.shared.current.trackName, withExtension: "m4a")
  }

  private var shouldPlay: Bool {
    // Stay quiet if the user already has a podcast or playlist going in another app.
    let otherAudioPlaying = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint

    return musicEnabled && homeVisible && !emulationRunning && !otherAudioPlaying &&
      UIApplication.shared.applicationState != .background
  }

  private var isPlaying: Bool {
    if let streamPlayer = streamPlayer {
      return streamPlayer.isPlaying
    }

    return loopNode.isPlaying
  }

  private func refresh(restart: Bool = false) {
    guard shouldPlay, let url = desiredURL else {
      fadeOut()
      return
    }

    if !restart, playingURL == url {
      if !isPlaying {
        resume()
      }
      return
    }

    start(url: url, fadeIn: 1.2)
  }

  private func start(url: URL, fadeIn: TimeInterval) {
    stopPlayback()

    let isBundled = url.path.hasPrefix(Bundle.main.bundlePath)

    if isBundled, let buffer = loopBuffer(for: url) {
      engine.disconnectNodeOutput(loopNode)
      engine.connect(loopNode, to: engine.mainMixerNode, format: buffer.format)

      do {
        if !engine.isRunning {
          try engine.start()
        }
      } catch {
        return
      }

      loopNode.volume = 0
      loopNode.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
      loopNode.play()
    } else {
      guard let player = try? AVAudioPlayer(contentsOf: url) else {
        return
      }

      player.numberOfLoops = -1
      player.volume = 0
      player.prepareToPlay()
      player.play()
      streamPlayer = player
    }

    playingURL = url
    outputVolume = 0
    fade(to: volume, duration: fadeIn)
  }

  private func resume() {
    if let streamPlayer = streamPlayer {
      streamPlayer.play()
    } else {
      do {
        if !engine.isRunning {
          try engine.start()
        }
      } catch {
        return
      }
      loopNode.play()
    }

    fade(to: volume, duration: 0.8)
  }

  private func pausePlayback() {
    streamPlayer?.pause()

    if loopNode.isPlaying {
      loopNode.pause()
    }

    if engine.isRunning {
      engine.pause()
    }
  }

  private func stopPlayback() {
    fadeTimer?.invalidate()
    fadeTimer = nil
    fadeCompletion = nil

    streamPlayer?.stop()
    streamPlayer = nil

    loopNode.stop()

    if engine.isRunning {
      engine.stop()
    }

    playingURL = nil
    outputVolume = 0
  }

  private func setOutputVolume(_ value: Float) {
    outputVolume = value
    streamPlayer?.volume = value
    loopNode.volume = value
  }

  /// Decodes a bundled loop into memory, dropping any encoder padding so the loop point is exact.
  private func loopBuffer(for url: URL) -> AVAudioPCMBuffer? {
    if let cached = loopBuffers[url] {
      return cached
    }

    guard let file = try? AVAudioFile(forReading: url) else {
      return nil
    }

    let format = file.processingFormat
    let length = AVAudioFrameCount(file.length)

    guard length > 0, let decoded = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length) else {
      return nil
    }

    do {
      try file.read(into: decoded)
    } catch {
      return nil
    }

    let trimmed = trimmedEdges(of: decoded) ?? decoded

    // Only keep the most recent loop around; the others decode again in a moment if needed.
    loopBuffers.removeAll()
    loopBuffers[url] = trimmed
    return trimmed
  }

  private func trimmedEdges(of buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard let channels = buffer.floatChannelData else {
      return nil
    }

    let frames = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    let threshold: Float = 0.0004
    let searchLimit = min(4096, frames / 4)

    func isSilent(_ frame: Int) -> Bool {
      for channel in 0..<channelCount where abs(channels[channel][frame]) > threshold {
        return false
      }
      return true
    }

    var first = 0
    while first < searchLimit, isSilent(first) {
      first += 1
    }

    var last = frames
    while last > frames - searchLimit, isSilent(last - 1) {
      last -= 1
    }

    guard first > 0 || last < frames else {
      return buffer
    }

    let count = last - first

    guard count > 0,
          let trimmed = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(count)),
          let destination = trimmed.floatChannelData else {
      return nil
    }

    for channel in 0..<channelCount {
      destination[channel].update(from: channels[channel].advanced(by: first), count: count)
    }

    trimmed.frameLength = AVAudioFrameCount(count)
    return trimmed
  }

  // MARK: Fading

  private func fadeOut() {
    guard playingURL != nil, isPlaying else {
      return
    }

    fade(to: 0, duration: 0.6) { [weak self] in
      self?.pausePlayback()
    }
  }

  private func fade(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
    fadeTimer?.invalidate()
    fadeTimer = nil

    fadeStartVolume = outputVolume
    fadeTargetVolume = target
    fadeStepCount = max(1, Int(duration / 0.05))
    fadeStep = 0
    fadeCompletion = completion

    let timer = Timer(timeInterval: 0.05, target: self, selector: #selector(fadeTick), userInfo: nil, repeats: true)
    RunLoop.main.add(timer, forMode: .common)
    fadeTimer = timer
  }

  @objc private func fadeTick() {
    fadeStep += 1
    let progress = min(1, Float(fadeStep) / Float(fadeStepCount))
    setOutputVolume(fadeStartVolume + (fadeTargetVolume - fadeStartVolume) * progress)

    if fadeStep >= fadeStepCount {
      fadeTimer?.invalidate()
      fadeTimer = nil

      let completion = fadeCompletion
      fadeCompletion = nil
      completion?()
    }
  }

  // MARK: Notifications

  @objc private func emulationDidStart() {
    DispatchQueue.main.async {
      self.emulationRunning = true
      self.stopPlayback()
      self.loopBuffers.removeAll()
    }
  }

  @objc private func emulationDidEnd() {
    DispatchQueue.main.async {
      self.emulationRunning = false
      self.refresh()
    }
  }

  @objc private func themeDidChange() {
    refresh()
  }

  @objc private func appWillResign() {
    fadeTimer?.invalidate()
    fadeTimer = nil
    fadeCompletion = nil
    pausePlayback()
  }

  @objc private func appDidBecomeActive() {
    refresh()
  }

  @objc private func engineConfigurationChanged() {
    DispatchQueue.main.async {
      guard self.streamPlayer == nil, self.playingURL != nil else {
        return
      }

      self.refresh(restart: true)
    }
  }
}
