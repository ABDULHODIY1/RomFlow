import Flutter
import UIKit
import Darwin
import UserNotifications
@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var saving = false
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "RomFlowLiquidNavigation") {
      registrar.register(NativeTabBarFactory(messenger: registrar.messenger()), withId: "romflow/liquid-navigation")
      registrar.register(GlassButtonsFactory(messenger: registrar.messenger()), withId: "romflow/glass-buttons")
      registrar.register(GlassSurfaceFactory(), withId: "romflow/glass-surface")
    }
    if let vc = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "romflow/render-device", binaryMessenger: vc.binaryMessenger).setMethodCallHandler { call, result in
        guard call.method == "status" else { result(FlutterMethodNotImplemented); return }
        var system = utsname()
        uname(&system)
        let machine = Mirror(reflecting: system.machine).children.reduce("") { text, element in
          guard let value = element.value as? Int8, value != 0 else { return text }
          return text + String(UnicodeScalar(UInt8(bitPattern: value)))
        }
        result(["machine": machine, "thermal": ProcessInfo.processInfo.thermalState.rawValue])
      }
      FlutterMethodChannel(name: "romflow/reminders", binaryMessenger: vc.binaryMessenger).setMethodCallHandler { call, result in
        if call.method == "reconcile", let args=call.arguments as? [String:Any],let items=args["items"] as? [[String:Any]] {
          let center=UNUserNotificationCenter.current(),keep=Set(items.compactMap {$0["id"] as? String})
          center.getPendingNotificationRequests { requests in
            center.removePendingNotificationRequests(withIdentifiers:requests.map {$0.identifier}.filter {!keep.contains($0)})
            center.getNotificationSettings { settings in
              if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                for item in items {
                  guard let id=item["id"] as? String,let title=item["title"] as? String,let time=item["timeMs"] as? NSNumber else {continue}
                  let date=Date(timeIntervalSince1970:time.doubleValue/1000);if date <= Date(){continue}
                  let content=UNMutableNotificationContent();content.title=title;content.body=item["note"] as? String ?? "";content.sound = .default
                  let fields=Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second],from:date)
                  center.add(UNNotificationRequest(identifier:id,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:fields,repeats:false)),withCompletionHandler:nil)
                }
              }
              DispatchQueue.main.async { result(nil) }
            }
          }
          return
        }
        guard let args = call.arguments as? [String:Any], let id = args["id"] as? String else { result(FlutterError(code:"REMINDER",message:"Eslatma ID yo‘q",details:nil)); return }
        let center = UNUserNotificationCenter.current()
        if call.method == "cancel" { center.removePendingNotificationRequests(withIdentifiers:[id]);center.removeDeliveredNotifications(withIdentifiers:[id]);result(nil);return }
        guard call.method == "schedule",let title=args["title"] as? String,let millis=args["timeMs"] as? NSNumber else {result(FlutterMethodNotImplemented);return}
        let date=Date(timeIntervalSince1970:millis.doubleValue/1000)
        guard date > Date() else {result(false);return}
        center.requestAuthorization(options:[.alert,.sound,.badge]) { allowed,error in
          guard allowed,error == nil else {DispatchQueue.main.async {result(false)};return}
          let content=UNMutableNotificationContent();content.title=title;content.body=args["note"] as? String ?? "";content.sound = .default
          let fields=Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second],from:date)
          let request=UNNotificationRequest(identifier:id,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:fields,repeats:false))
          center.add(request) {error in DispatchQueue.main.async {if let error=error {result(FlutterError(code:"REMINDER",message:error.localizedDescription,details:nil))}else{result(true)}}}
        }
      }

      FlutterMethodChannel(name: "romflow/offline", binaryMessenger: vc.binaryMessenger).setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        if call.method == "open" {
          if let text = (call.arguments as? [String:Any])?["url"] as? String,
             text.hasPrefix("https://") || text.hasPrefix("itms-apps://"),
             let url = URL(string: text) { UIApplication.shared.open(url) }
          result(nil); return
        }
        if call.method == "dial" {
          let digits = ((call.arguments as? [String:Any])?["phone"] as? String ?? "").filter { "+0123456789".contains($0) }
          if let url = URL(string: "tel:\(digits)"), !digits.isEmpty { UIApplication.shared.open(url) }
          result(nil); return
        }
        guard self.pending == nil else { result(FlutterError(code:"BUSY", message:"Oldingi fayl amali tugamadi",details:nil)); return }
        do {
          let picker: UIDocumentPickerViewController
          if call.method == "pickBackup" {
            self.saving = false
            picker = UIDocumentPickerViewController(documentTypes:["public.json","public.text","public.data"],in:.import)
          } else if call.method == "saveFile", let args = call.arguments as? [String:Any] {
            self.saving = true
            let name = ((args["name"] as? String) ?? "RomFlow-backup.json") as NSString
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name.lastPathComponent)
            guard let bytes = args["bytes"] as? FlutterStandardTypedData else { result(FlutterError(code:"FILE",message:"Fayl ma’lumoti yo‘q",details:nil));return }
            try bytes.data.write(to:url,options:.atomic)
            picker = UIDocumentPickerViewController(url:url,in:.exportToService)
          } else { result(FlutterMethodNotImplemented);return }
          picker.delegate = self; picker.allowsMultipleSelection = false; self.pending = result
          vc.present(picker,animated:true)
        } catch { result(FlutterError(code:"FILE",message:error.localizedDescription,details:nil)) }
      }
    }
    return super.application(application,didFinishLaunchingWithOptions:launchOptions)
  }
  func documentPicker(_ controller: UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]) {
    guard let callback = pending else {return}; pending = nil
    if saving {callback(true);return}
    guard let url = urls.first else {callback(nil);return}
    let access = url.startAccessingSecurityScopedResource();defer {if access {url.stopAccessingSecurityScopedResource()}}
    do {
      let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
      guard size <= 10*1024*1024 else {callback(FlutterError(code:"FILE",message:"Zaxira 10 MBdan katta",details:nil));return}
      let data = try Data(contentsOf:url)
      guard let text = String(data:data,encoding:.utf8) else {callback(FlutterError(code:"FILE",message:"JSON UTF-8 bo‘lishi kerak",details:nil));return}
      callback(text)
    } catch {callback(FlutterError(code:"FILE",message:error.localizedDescription,details:nil))}
  }
  func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController) {let callback=pending;pending=nil;callback?(saving ? false : nil)}
}


// Apple's own Liquid Glass. With the iOS 26 SDK the system draws the tab bar
// and the glass buttons exactly as in its own apps (the lens on the chosen
// tab, the glass that bends the content behind); earlier iOS versions get
// the system bars and tinted buttons of their time.
final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeTabBar(frame: frame, id: viewId, args: args as? [String: Any], messenger: messenger)
  }
}

/// Reports its layout, so the tab bar's own height (with the home
/// indicator's safe area) can be handed to Flutter.
final class TabBarRoot: UIView {
  var onLayout: (() -> Void)?
  override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
  override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); onLayout?() }
}

final class NativeTabBar: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let root = TabBarRoot()
  private let bar = UITabBar()
  private let channel: FlutterMethodChannel
  private var reported: CGFloat = 0
  init(frame: CGRect, id: Int64, args: [String: Any]?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "romflow/liquid-navigation/\(id)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.backgroundColor = .clear
    // The view reaches the bottom of the screen like a system tab bar; the
    // bar keeps its items above the home indicator by its safe area and
    // tells Flutter the height it needs, so the capsule is never squeezed.
    root.onLayout = { [weak self] in self?.reportHeight() }
    let titles = args?["titles"] as? [String] ?? ["Asosiy", "Buyurtmalar", "Katalog", "Sozlamalar"]
    let icons = args?["icons"] as? [String] ?? ["square.grid.2x2", "doc.text", "square.grid.3x3", "slider.horizontal.3"]
    var items: [UITabBarItem] = []
    for (i, title) in titles.enumerated() {
      let name = i < icons.count ? icons[i] : "circle"
      let item = UITabBarItem(title: title, image: UIImage(systemName: name), tag: i)
      item.selectedImage = UIImage(systemName: name + ".fill") ?? UIImage(systemName: name)
      items.append(item)
    }
    bar.items = items
    bar.delegate = self
    bar.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(bar)
    NSLayoutConstraint.activate([
      bar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      bar.topAnchor.constraint(equalTo: root.topAnchor),
      bar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
    ])
    configure(args ?? [:])
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "configure", let args = call.arguments as? [String: Any] {
        self?.configure(args); result(nil)
      } else if call.method == "select", let index = call.arguments as? Int {
        self?.select(index); result(nil)
      } else { result(FlutterMethodNotImplemented) }
    }
  }
  private func configure(_ args: [String: Any]) {
    root.overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
    select(args["selected"] as? Int ?? 0)
  }
  private func select(_ index: Int) {
    guard let items = bar.items, index >= 0, index < items.count else { return }
    bar.selectedItem = items[index]
  }
  private func reportHeight() {
    guard root.bounds.width > 0 else { return }
    let height = bar.sizeThatFits(CGSize(width: root.bounds.width, height: .greatestFiniteMagnitude)).height
    guard height > 0, abs(height - reported) > 0.5 else { return }
    reported = height
    channel.invokeMethod("height", arguments: Double(height))
  }
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) { channel.invokeMethod("onTab", arguments: item.tag) }
  func view() -> UIView { root }
  deinit { channel.setMethodCallHandler(nil) }
}

final class GlassButtonsFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger; super.init() }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassButtons(frame: frame, id: viewId, args: args as? [String: Any], messenger: messenger)
  }
}

/// A row (or column) of system glass buttons. Each item: id, symbol (SF
/// Symbol), title, subtitle, style ("glass", "prominent", "white"),
/// selected, enabled, expand (takes the free width), size (a round button).
final class GlassButtons: NSObject, FlutterPlatformView, UIGestureRecognizerDelegate {
  private let root = UIView()
  private let stack = UIStackView()
  private let channel: FlutterMethodChannel
  private static let blue = UIColor(red: 0.125, green: 0.42, blue: 0.77, alpha: 1)

  /// A template icon from unit-square polylines (an opening symbol): the
  /// button tints it like an SF symbol.
  static func drawnIcon(_ strokes: [[Double]], mark: [Double]?, side: CGFloat) -> UIImage {
    let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
      let inset: CGFloat = 1.5, span = side - 2 * inset
      func at(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: inset + CGFloat(x) * span, y: inset + CGFloat(y) * span)
      }
      UIColor.black.setStroke()
      let box = UIBezierPath(roundedRect: CGRect(x: inset, y: inset, width: span, height: span), cornerRadius: 2)
      box.lineWidth = 1.6
      box.stroke()
      for line in strokes where line.count >= 4 {
        let path = UIBezierPath()
        path.move(to: at(line[0], line[1]))
        var i = 2
        while i + 1 < line.count { path.addLine(to: at(line[i], line[i + 1])); i += 2 }
        path.lineWidth = 1.5
        path.lineJoinStyle = .round
        path.stroke()
      }
      if let m = mark, m.count == 4 {
        let path = UIBezierPath()
        path.move(to: at(m[0], m[1]))
        path.addLine(to: at(m[2], m[3]))
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.stroke()
      }
    }
    return image.withRenderingMode(.alwaysTemplate)
  }
  init(frame: CGRect, id: Int64, args: [String: Any]?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "romflow/glass-buttons/\(id)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.backgroundColor = .clear
    stack.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      stack.topAnchor.constraint(equalTo: root.topAnchor),
      stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
    ])
    configure(args ?? [:])
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "configure", let args = call.arguments as? [String: Any] {
        self?.configure(args); result(nil)
      } else if call.method == "items", let items = call.arguments as? [[String: Any]] {
        self?.build(items); result(nil)
      } else { result(FlutterMethodNotImplemented) }
    }
  }
  private func configure(_ args: [String: Any]) {
    root.overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
    stack.axis = args["vertical"] as? Bool == true ? .vertical : .horizontal
    stack.spacing = CGFloat(args["spacing"] as? Double ?? 8)
    stack.alignment = .center
    stack.distribution = args["equal"] as? Bool == true ? .fillEqually : .fill
    build(args["items"] as? [[String: Any]] ?? [])
  }
  private var dragIds: [ObjectIdentifier: String] = [:]
  /// The recognizer that is dragging now: a pull and a hold never both drag.
  private var activeDrag: ObjectIdentifier?
  @objc private func dragged(_ gesture: UIGestureRecognizer) {
    let key = ObjectIdentifier(gesture)
    guard let id = dragIds[key] else { return }
    if gesture.state == .began {
      guard activeDrag == nil else { return }
      activeDrag = key
    }
    guard activeDrag == key else { return }
    let phase: String
    switch gesture.state {
    case .began: phase = "start"
    case .changed: phase = "move"
    case .ended: phase = "end"
    default: phase = "cancel"
    }
    if phase == "end" || phase == "cancel" { activeDrag = nil }
    let at = gesture.location(in: nil)
    channel.invokeMethod("drag", arguments: ["id": id, "phase": phase, "x": Double(at.x), "y": Double(at.y)])
  }
  // The glass button keeps its own press effect while the finger drags.
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
  private func build(_ items: [[String: Any]]) {
    dragIds.removeAll()
    activeDrag = nil
    for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
    for item in items { stack.addArrangedSubview(make(item)) }
  }
  private func make(_ item: [String: Any]) -> UIButton {
    let id = item["id"] as? String ?? ""
    let selected = item["selected"] as? Bool ?? false
    let style = selected ? "prominent" : (item["style"] as? String ?? "glass")
    let tint: UIColor
    if let argb = item["tint"] as? NSNumber {
      let value = argb.uint32Value
      tint = UIColor(red: CGFloat((value >> 16) & 255) / 255,
        green: CGFloat((value >> 8) & 255) / 255,
        blue: CGFloat(value & 255) / 255,
        alpha: CGFloat((value >> 24) & 255) / 255)
    } else { tint = GlassButtons.blue }
    var config: UIButton.Configuration
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      // Prominent glass takes its colours from the tint, so a white one
      // washed its blue title out to white on white: white stays solid.
      config = style == "glass" ? .glass() : style == "white" ? .filled() : .prominentGlass()
    } else {
      config = style == "glass" ? .tinted() : .filled()
    }
    #else
    config = style == "glass" ? .tinted() : .filled()
    #endif
    config.cornerStyle = .capsule
    var foreground = style == "white" ? GlassButtons.blue : (style == "glass" ? tint : .white)
    if item["light"] as? Bool == true { foreground = .white }
    let fontSize = CGFloat(item["fontSize"] as? Double ?? 15)
    if let title = item["title"] as? String, !title.isEmpty {
      config.title = title
      // One line: a long title shrinks (below) instead of breaking in two.
      config.titleLineBreakMode = .byTruncatingTail
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
        var a = attributes
        a.font = .systemFont(ofSize: fontSize, weight: .semibold)
        if style == "white" { a.foregroundColor = foreground }
        return a
      }
    }
    if item["expand"] as? Bool == true {
      config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
    }
    if let subtitle = item["subtitle"] as? String, !subtitle.isEmpty {
      config.subtitle = subtitle
      config.titleAlignment = .center
      config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
        var a = attributes; a.font = .systemFont(ofSize: CGFloat(item["subtitleFontSize"] as? Double ?? 11), weight: .medium); return a
      }
    }
    if let symbol = item["symbol"] as? String {
      // An unknown name draws nothing: a plain square instead.
      config.image = UIImage(systemName: symbol) ?? UIImage(systemName: "square")
      config.imagePadding = 6
      config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
        pointSize: CGFloat(item["iconSize"] as? Double ?? 16), weight: .semibold)
    }
    if let strokes = item["strokes"] as? [[Double]] {
      config.image = GlassButtons.drawnIcon(
        strokes, mark: item["mark"] as? [Double],
        side: CGFloat(item["iconSize"] as? Double ?? 16) + 4)
    }
    config.baseBackgroundColor = style == "white" ? .white : tint
    config.baseForegroundColor = foreground
    if style == "white" { config.imageColorTransformer = UIConfigurationColorTransformer { _ in foreground } }
    let button = UIButton(configuration: config)
    button.tintColor = style == "white" ? GlassButtons.blue : tint
    button.titleLabel?.numberOfLines = 1
    button.titleLabel?.adjustsFontSizeToFitWidth = true
    button.titleLabel?.minimumScaleFactor = 0.75
    button.isEnabled = item["enabled"] as? Bool ?? true
    button.isSelected = selected
    button.accessibilityLabel = item["label"] as? String ?? config.title ?? id
    button.accessibilityHint = item["subtitle"] as? String
    button.addAction(UIAction { [weak self] _ in self?.channel.invokeMethod("onTap", arguments: id) }, for: .touchUpInside)
    if item["draggable"] as? Bool == true {
      // Pulled at once (as the Flutter tools) or held still and moved, the
      // button drags its part onto the drawing: the finger's position goes
      // to Flutter in screen points.
      let pull = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
      pull.maximumNumberOfTouches = 1
      let hold = UILongPressGestureRecognizer(target: self, action: #selector(dragged(_:)))
      hold.minimumPressDuration = 0.1
      for gesture in [pull, hold] as [UIGestureRecognizer] {
        gesture.delegate = self
        button.addGestureRecognizer(gesture)
        dragIds[ObjectIdentifier(gesture)] = id
      }
    }
    button.translatesAutoresizingMaskIntoConstraints = false
    if let size = item["size"] as? Double {
      NSLayoutConstraint.activate([
        button.widthAnchor.constraint(equalToConstant: max(44, CGFloat(size))),
        button.heightAnchor.constraint(equalToConstant: max(44, CGFloat(size))),
      ])
    } else {
      button.heightAnchor.constraint(equalToConstant: CGFloat(item["height"] as? Double ?? 48)).isActive = true
    }
    let expand = item["expand"] as? Bool ?? false
    button.setContentHuggingPriority(expand ? .defaultLow : .required, for: .horizontal)
    button.setContentCompressionResistancePriority(expand ? .defaultLow : .required, for: .horizontal)
    return button
  }
  func view() -> UIView { root }
  deinit { channel.setMethodCallHandler(nil) }
}


/// Apple's own Liquid Glass material behind a Flutter surface (app bar,
/// sheets, dialogs, floating buttons): UIGlassEffect with the iOS 26 SDK,
/// the system's thin material before it. Flutter draws the content on top.
final class GlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassSurfaceView(frame: frame, args: args as? [String: Any] ?? [:])
  }
}

/// Keeps the glass's corners at most half its side: a 100 pt radius on a
/// 50 pt button turned a capsule into a pointed lens.
final class GlassEffectView: UIVisualEffectView {
  var wantedRadius: CGFloat = 0
  override func layoutSubviews() {
    super.layoutSubviews()
    let radius = min(wantedRadius, bounds.height / 2, bounds.width / 2)
    if layer.cornerRadius != radius { layer.cornerRadius = radius }
  }
}

final class GlassSurfaceView: NSObject, FlutterPlatformView {
  private let effectView: GlassEffectView
  init(frame: CGRect, args: [String: Any]) {
    let dark = args["dark"] as? Bool == true
    var tint: UIColor?
    if let argb = args["tint"] as? NSNumber {
      let value = argb.uint32Value
      tint = UIColor(red: CGFloat((value >> 16) & 255) / 255,
        green: CGFloat((value >> 8) & 255) / 255,
        blue: CGFloat(value & 255) / 255,
        alpha: CGFloat((value >> 24) & 255) / 255)
    }
    var effect: UIVisualEffect = UIBlurEffect(style: dark ? .systemThinMaterialDark : .systemThinMaterial)
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: args["clear"] as? Bool == true ? .clear : .regular)
      glass.tintColor = tint
      effect = glass
    }
    #endif
    effectView = GlassEffectView(effect: effect)
    super.init()
    effectView.frame = frame
    effectView.overrideUserInterfaceStyle = dark ? .dark : .light
    effectView.isUserInteractionEnabled = false
    // Corners: top-left, top-right, bottom-right, bottom-left (a sheet is
    // rounded only at the top).
    let corners = (args["corners"] as? [Double] ?? [0, 0, 0, 0]).map { CGFloat($0) }
    let radius = corners.max() ?? 0
    var masked: CACornerMask = []
    if corners.count == 4 {
      if corners[0] > 0 { masked.insert(.layerMinXMinYCorner) }
      if corners[1] > 0 { masked.insert(.layerMaxXMinYCorner) }
      if corners[2] > 0 { masked.insert(.layerMaxXMaxYCorner) }
      if corners[3] > 0 { masked.insert(.layerMinXMaxYCorner) }
    }
    effectView.wantedRadius = radius
    effectView.layer.cornerRadius = min(radius, frame.height / 2, frame.width / 2)
    effectView.layer.maskedCorners = masked
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = radius > 0
  }
  func view() -> UIView { effectView }
}
