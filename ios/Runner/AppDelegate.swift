import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // P2-2: initialise Google Maps Platform. Key is read from Info.plist
    // (`GMSApiKey`), which should be populated from an xcconfig/build setting
    // rather than committed in source. Empty string just produces grey tiles
    // and a logged warning; it does not crash.
    let apiKey = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String) ?? ""
    GMSServices.provideAPIKey(apiKey)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
