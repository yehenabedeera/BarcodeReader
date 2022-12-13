//
//  ViewController.swift
//  BarcodeReader
//
//  Created by user on 2022/12/12.
//

import UIKit
import AVFoundation


class ViewController: UIViewController {

    @IBOutlet weak var preview: UIView!
    
    @IBOutlet weak var displayLabel: UILabel!
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.session)
        layer.frame = self.view.layer.frame
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        layer.connection?.videoOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.videoOrientation ?? .portrait
        return layer
    }()
    
    @IBOutlet weak var detectArea: UIView!{
        didSet {
            detectArea.layer.borderWidth = 3.0
            detectArea.layer.borderColor = UIColor.red.cgColor
        }
    }
    
    private var boundingBox = CAShapeLayer()
    
    private var allowDuplicateReading: Bool = false
    private var makeSound: Bool = false
    private var makeHapticFeedback: Bool = false
    private var showBoundingBox: Bool = false
    private var scannedQRs = Set<String>()
    
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    private var videoDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    private let metadataOutput = AVCaptureMetadataOutput()
    private let metadataObjectQueue = DispatchQueue(label: "metadataObjectQueue")

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                }
            }
        default:
            print("The user has previously denied access.")
        }
        
        sessionQueue.async {
            self.configureSession()
        }
        
        DispatchQueue.main.async {
            self.preview.layer.addSublayer(self.previewLayer)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 読み取り範囲の制限
        sessionQueue.async {
            DispatchQueue.main.async {
                print(self.detectArea.frame)
                let metadataOutputRectOfInterest = self.previewLayer.metadataOutputRectConverted(fromLayerRect: self.detectArea.frame)
                print(metadataOutputRectOfInterest)
                self.sessionQueue.async {
                    self.metadataOutput.rectOfInterest = metadataOutputRectOfInterest
                }
            }
            
            self.session.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        self.previewLayer.frame = self.view.frame
        if ((self.previewLayer.connection?.isVideoOrientationSupported) != nil) {
            self.previewLayer.connection?.videoOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.videoOrientation ?? .portrait
            }
    }
    
    // MARK: configureSession
    private func configureSession() {
        session.beginConfiguration()
        
        let defaultVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                         for: .video,
                                                         position: .back)
        
        guard let videoDevice = defaultVideoDevice else {
            session.commitConfiguration()
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            }
        } catch {
            session.commitConfiguration()
            return
        }
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: metadataObjectQueue)
            
            metadataOutput.metadataObjectTypes = [.codabar,
                                                  .qr,
                                                  .upce,
                                                  .code39,
                                                  .code39Mod43,
                                                  .code93,
                                                  .code128,
                                                  .ean8,
                                                  .ean13,
                                                  .aztec,
                                                  .pdf417,
                                                  .itf14,
                                                  .interleaved2of5]
        } else {
            session.commitConfiguration()
        }
        
        session.commitConfiguration()
    }
    
    private func resetViews() {
        boundingBox.isHidden = true
    }

}

// MARK: AVCaptureMetadataOutputObjectsDelegate
extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        for metadataObject in metadataObjects {
            guard let machineReadableCode = metadataObject as? AVMetadataMachineReadableCodeObject,
                  machineReadableCode.type == .qr ||
                  machineReadableCode.type == .codabar ||
                  machineReadableCode.type == .upce ||
                  machineReadableCode.type == .code39 ||
                  machineReadableCode.type == .code39Mod43 ||
                  machineReadableCode.type == .code93 ||
                  machineReadableCode.type == .code128 ||
                  machineReadableCode.type == .ean8 ||
                  machineReadableCode.type == .ean13 ||
                  machineReadableCode.type == .aztec ||
                  machineReadableCode.type == .pdf417 ||
                  machineReadableCode.type == .interleaved2of5,
                  let stringValue = machineReadableCode.stringValue
            else {
                return
            }
            
            if allowDuplicateReading {
                if !self.scannedQRs.contains(stringValue) {
                    self.scannedQRs.insert(stringValue)
                    // 読み取り成功
                    print("The content of code: \(stringValue)")
                    
                    
                    DispatchQueue.main.async {
                        self.displayLabel.text = "The content of code: \(stringValue)"
                    }
                    
                }
            } else {
                // 読み取り成功
                print("The content of code: \(stringValue)")
                DispatchQueue.main.async {
                    self.displayLabel.text = "The content of code: \(stringValue)"
                }            }
        }
    }
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeLeft
        case .landscapeLeft: return .landscapeRight
        case .portrait: return .portrait
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeRight
        case .landscapeLeft: return .landscapeLeft
        case .portrait: return .portrait
        default: return nil
        }
    }
}

