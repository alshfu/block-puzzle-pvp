import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Минимальный размер контента: ниже этого порога экраны начинают давать
    // RenderFlex overflow. Запрещаем ужимать окно до проблемных размеров.
    self.contentMinSize = NSSize(width: 560, height: 720)
    // Стартовый размер делаем комфортным (игровое поле помещается целиком).
    self.setContentSize(NSSize(width: 900, height: 840))
    self.center()
    // Тёмный фон окна под цвет тёмной темы — без белой вспышки при
    // старте/ресайзе до первого кадра Flutter.
    self.backgroundColor = NSColor(
      red: 0x0E / 255.0, green: 0x11 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
