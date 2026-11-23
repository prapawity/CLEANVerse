import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    AppIconChannel.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Returns the Finder icon of a file or app bundle as PNG bytes. Read-only:
/// uses NSWorkspace, which needs no extra permissions.
enum AppIconChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "cleanverse/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "iconPng",
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let size = (args["size"] as? Int) ?? 64
      DispatchQueue.global(qos: .userInitiated).async {
        let png = iconPng(path: path, size: size)
        DispatchQueue.main.async {
          result(png.map { FlutterStandardTypedData(bytes: $0) })
        }
      }
    }
  }

  static func iconPng(path: String, size: Int) -> Data? {
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: path)
    let pixels = max(16, min(size, 512))
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
              from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
  }
}
