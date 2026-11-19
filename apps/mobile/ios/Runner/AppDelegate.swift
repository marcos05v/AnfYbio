import Flutter
import PDFKit
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Necesario para que las notificaciones de suplementos también se muestren
    // si llegan con la app abierta.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // El botón "Ya lo tomé" corre en un motor de Flutter aparte cuando la app
    // está cerrada; necesita los mismos plugins (base de datos, rutas).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerPdfTextChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  /// Canal "anfybio/pdf_text": extrae el texto de un PDF con PDFKit, que viene
  /// con iOS (ADR-0009). El texto nunca sale del dispositivo.
  private func registerPdfTextChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "anfybio/pdf_text", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "extractText", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      // La lectura puede tardar: se hace fuera del hilo de la interfaz.
      DispatchQueue.global(qos: .userInitiated).async {
        guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
          DispatchQueue.main.async {
            result(FlutterError(code: "unreadable", message: "No se pudo abrir el PDF.", details: nil))
          }
          return
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
          pages.append(document.page(at: index)?.string ?? "")
        }
        DispatchQueue.main.async { result(pages.joined(separator: "\n")) }
      }
    }
  }
}
