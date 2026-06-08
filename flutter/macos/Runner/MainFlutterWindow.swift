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

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
