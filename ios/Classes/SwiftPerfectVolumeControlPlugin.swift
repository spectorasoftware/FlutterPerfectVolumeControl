import Flutter
import UIKit
import MediaPlayer
import AVFoundation

public class SwiftPerfectVolumeControlPlugin: NSObject, FlutterPlugin {
    /// Flutter 消息通道
    var channel: FlutterMethodChannel?;
    private let session: AVAudioSession
    private let volumeView: MPVolumeView;

    override init() {
        volumeView = MPVolumeView()
        session = AVAudioSession.sharedInstance()
        super.init();
        setupSession()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftPerfectVolumeControlPlugin()
        instance.channel = FlutterMethodChannel(name: "perfect_volume_control", binaryMessenger: registrar.messenger())
        instance.bindListener()
        registrar.addMethodCallDelegate(instance, channel: instance.channel!)
    }
    
    func setupSession() {
        print("Setting up audio session...")
        do {
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to setup session: \(error.localizedDescription)")
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getVolume":
            self.getVolume(call, result: result);
            break;
        case "setVolume":
            self.setVolume(call, result: result);
            break;
        case "hideUI":
            self.hideUI(call, result: result);
            break;
        default:
            result(FlutterMethodNotImplemented);
        }

    }

    /// 获得系统当前音量
    public func getVolume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(session.outputVolume);
    }

    /// 设置音量
    public func setVolume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        let volume = ((call.arguments as! [String: Any])["volume"]) as! Float;
        var slider: UISlider?
        for item in volumeView.subviews {
            if item is UISlider {
                slider = (item as! UISlider);
                break;
            }
        }
        
        guard let slider else {
            result(FlutterError(code: "-1", message: "Unable to get uislider", details: "Unable to get uislider"));
            return
        }
        
        slider.setValue(volume, animated: false)
        result(nil);
    }

    /// 隐藏UI
    public func hideUI(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let hide = ((call.arguments as! [String: Any])["hide"]) as! Bool
        if hide {
            volumeView.frame = CGRect(
                x: -1000,
                y: -1000,
                width: 1,
                height: 1
            )
            
            volumeView.showsRouteButton = false
            UIApplication.shared.delegate!.window!?.rootViewController!.view.addSubview(volumeView);
        } else {
            volumeView.removeFromSuperview();
        }
        result(nil);
    }
    
    public func bindListener() {
        session.addObserver(self, forKeyPath: "outputVolume", options: [.new, .old], context: nil)
        
        let notification =  NSNotification.Name(
            rawValue: "AVSystemController_SystemVolumeDidChangeNotification"
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.volumeChangeListener),
            name: notification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
            
        UIApplication.shared.beginReceivingRemoteControlEvents();
    }

    @objc func volumeChangeListener(notification: NSNotification) {
        let volume = notification.userInfo!["AVSystemController_AudioVolumeNotificationParameter"] as! Float
        channel?.invokeMethod("volumeChangeListener", arguments: volume)
    }
    
    @objc func appWillEnterForeground() {
        // Reactivate the audio session and re-enable volume monitoring
        setupSession()
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let volume = session.outputVolume
        channel?.invokeMethod("volumeChangeListener", arguments: volume)
    }
}
