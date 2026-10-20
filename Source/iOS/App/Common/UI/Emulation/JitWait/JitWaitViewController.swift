// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

class JitWaitViewController: UIViewController {
  @objc weak var delegate: JitWaitViewControllerDelegate?
  
  var timer: Timer?
  var isShowingError: Bool = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkJit), userInfo: nil, repeats: true)
    
    JitManager.shared().acquireJitByAltServer()
    JitManager.shared().acquireJitByJitStreamer()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    self.showAcquisitionErrorIfNecessary()
  }
  
  @objc func checkJit() {
    if (self.isShowingError) {
      return
    }
    
    let manager = JitManager.shared()
    
    manager.recheckIfJitIsAcquired()
    
    if (manager.acquiredJit) {
      self.timer?.invalidate()
      self.delegate?.didFinishJitScreen(result: .jitAcquired, sender: self)
      
      return
    }
    
    self.showAcquisitionErrorIfNecessary()
  }
  
  func showAcquisitionErrorIfNecessary() {
    let manager = JitManager.shared()
    
    if let error = manager.acquisitionError {
      manager.acquisitionError = nil
      self.isShowingError = true
      
      let alertController = UIAlertController(title: DOLCoreLocalizedString("Error"), message: error, preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: DOLCoreLocalizedString("OK"), style: .default, handler: {_ in
        self.isShowingError = false
      }))
      
      self.present(alertController, animated: true, completion: nil)
    }
  }
  
  /// Asks StikDebug to attach to this process. On TXM devices the request names universal.js,
  /// which matches the breakpoint calls the JIT allocator makes.
  @IBAction func helpPressed(_ sender: Any) {
    var components = URLComponents()
    components.scheme = "stikdebug"
    components.host = "enable-jit"
    components.queryItems = [
      URLQueryItem(name: "bundle-id", value: Bundle.main.bundleIdentifier ?? ""),
      URLQueryItem(name: "pid", value: String(getpid()))
    ]

    if JitManager.shared().deviceHasTxm {
      components.queryItems?.append(URLQueryItem(name: "script-name", value: "universal.js"))
    }

    guard let url = components.url else {
      return
    }

    UIApplication.shared.open(url, options: [:]) { opened in
      if opened {
        return
      }

      var message = "Install StikDebug, then come back here and tap Open StikDebug again. "
        + "You can also enable JIT from StikDebug yourself: choose PrismRVL and the universal.js script."

      if ProcessInfo.processInfo.environment["LC_HOME_PATH"] != nil {
        message += "\n\nRunning in LiveContainer: turn on \"Use LiveContainer's Bundle ID\" in LiveContainer's settings first."
      }

      let alert = UIAlertController(title: "StikDebug Not Found", message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: DOLCoreLocalizedString("OK"), style: .default))
      self.present(alert, animated: true)
    }
  }
  
  @IBAction func noJitPressed(_ sender: Any) {
    self.timer?.invalidate()
    self.delegate?.didFinishJitScreen(result: .noJitRequested, sender: self)
  }
  
  @IBAction func cancelPressed(_ sender: Any) {
    self.timer?.invalidate()
    self.delegate?.didFinishJitScreen(result: .cancel, sender: self)
  }
}
