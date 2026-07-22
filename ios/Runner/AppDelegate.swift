import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundTasks: [Int: UIBackgroundTaskIdentifier] = [:]
  private var nextTaskId = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackgroundTaskPlugin") else { return }
    let channel = FlutterMethodChannel(
      name: "com.samantha/background_task",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: FlutterResult) in
      switch call.method {
      case "beginBackgroundTask":
        let taskId = self?.beginBackgroundTask() ?? -1
        result(taskId)
      case "endBackgroundTask":
        if let args = call.arguments as? [String: Any],
           let taskId = args["taskId"] as? Int {
          self?.endBackgroundTask(taskId: taskId)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginBackgroundTask() -> Int {
    let taskId = nextTaskId
    nextTaskId += 1

    let bgTask = UIApplication.shared.beginBackgroundTask(withName: "com.samantha.socketKeepAlive") { [weak self] in
      self?.endBackgroundTask(taskId: taskId)
    }

    backgroundTasks[taskId] = bgTask
    return taskId
  }

  private func endBackgroundTask(taskId: Int) {
    guard let bgTask = backgroundTasks[taskId] else { return }
    UIApplication.shared.endBackgroundTask(bgTask)
    backgroundTasks.removeValue(forKey: taskId)
  }
}
