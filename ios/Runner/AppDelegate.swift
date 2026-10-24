import Flutter
import UIKit
import UserNotifications
@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var saving = false
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "RomFlowLiquidNavigation") {
      registrar.register(GlassNavigationFactory(messenger: registrar.messenger()), withId: "romflow/liquid-navigation")
    }
    if let vc = window?.rootViewController as? FlutterViewController {
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


// Native Liquid Glass when compiled with the iOS 26 SDK; material blur fallback
// for older iOS versions. Flutter content and the native bar have separate layers.
final class GlassNavigationFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {self.messenger=messenger;super.init()}
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {FlutterStandardMessageCodec.sharedInstance()}
  func create(withFrame frame:CGRect,viewIdentifier viewId:Int64,arguments args:Any?) -> FlutterPlatformView {
    GlassNavigation(frame:frame,id:viewId,args:args as? [String:Any],messenger:messenger)
  }
}
final class GlassNavigation: NSObject,FlutterPlatformView {
  private let root=UIView()
  private var buttons:[UIButton]=[]
  private var labels:[UILabel]=[]
  private let channel:FlutterMethodChannel
  init(frame:CGRect,id:Int64,args:[String:Any]?,messenger:FlutterBinaryMessenger) {
    channel=FlutterMethodChannel(name:"romflow/liquid-navigation/\(id)",binaryMessenger:messenger)
    super.init()
    root.frame=frame;root.backgroundColor = .clear
    let effect:UIVisualEffect
    #if compiler(>=6.2)
    if #available(iOS 26.0,*) {let glass=UIGlassEffect(style:.regular);glass.isInteractive=true;effect=glass}
    else {effect=UIBlurEffect(style:.systemMaterial)}
    #else
    effect=UIBlurEffect(style:.systemMaterial)
    #endif
    let surface=UIVisualEffectView(effect:effect);surface.translatesAutoresizingMaskIntoConstraints=false;surface.layer.cornerRadius=30;surface.clipsToBounds=true;root.addSubview(surface)
    NSLayoutConstraint.activate([surface.leadingAnchor.constraint(equalTo:root.leadingAnchor),surface.trailingAnchor.constraint(equalTo:root.trailingAnchor),surface.topAnchor.constraint(equalTo:root.topAnchor),surface.bottomAnchor.constraint(equalTo:root.bottomAnchor)])
    let row=UIStackView();row.axis = .horizontal;row.distribution = .fillEqually;row.translatesAutoresizingMaskIntoConstraints=false;surface.contentView.addSubview(row)
    NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo:surface.contentView.leadingAnchor,constant:4),row.trailingAnchor.constraint(equalTo:surface.contentView.trailingAnchor,constant:-4),row.topAnchor.constraint(equalTo:surface.contentView.topAnchor,constant:4),row.bottomAnchor.constraint(equalTo:surface.contentView.bottomAnchor,constant:-4)])
    let titles=["Asosiy","Buyurtmalar","Katalog","Sozlamalar"],icons=["square.grid.2x2","doc.text","square.grid.3x3","slider.horizontal.3"]
    for i in 0..<4 {
      let button=UIButton(type:.system);button.tag=i;button.accessibilityLabel=titles[i];button.layer.cornerRadius=26
      let icon=UIImageView(image:UIImage(systemName:icons[i]));icon.contentMode = .scaleAspectFit
      let label=UILabel();label.text=titles[i];label.font = .systemFont(ofSize:10,weight:.medium);label.textAlignment = .center
      let content=UIStackView(arrangedSubviews:[icon,label]);content.axis = .vertical;content.spacing=4;content.alignment = .center;content.isUserInteractionEnabled=false;content.translatesAutoresizingMaskIntoConstraints=false;button.addSubview(content)
      NSLayoutConstraint.activate([content.centerXAnchor.constraint(equalTo:button.centerXAnchor),content.centerYAnchor.constraint(equalTo:button.centerYAnchor),icon.heightAnchor.constraint(equalToConstant:22),icon.widthAnchor.constraint(equalToConstant:26)])
      button.addTarget(self,action:#selector(tapped(_:)),for:.touchUpInside);row.addArrangedSubview(button);buttons.append(button);labels.append(label)
    }
    select(args?["selected"] as? Int ?? 0)
    channel.setMethodCallHandler { [weak self] call,result in
      if call.method=="select",let index=call.arguments as? Int {self?.select(index);result(nil)}else{result(FlutterMethodNotImplemented)}
    }
  }
  private func select(_ index:Int) {
    for (i,button) in buttons.enumerated(){button.isSelected=i==index;button.tintColor=i==index ? .systemBlue:.secondaryLabel;button.backgroundColor=i==index ? UIColor.systemBlue.withAlphaComponent(0.12):.clear;labels[i].textColor=button.tintColor;button.accessibilityTraits=i==index ? [.button,.selected]:[.button]}
  }
  @objc private func tapped(_ sender:UIButton){select(sender.tag);channel.invokeMethod("onTab",arguments:sender.tag)}
  func view() -> UIView {root}
  deinit {channel.setMethodCallHandler(nil)}
}
