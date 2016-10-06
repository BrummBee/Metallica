
// Solution logger from Toni Suter, HSR
// This is used for the HSR App Quest


import UIKit
import AVFoundation

class SolutionLogger {
    let viewController: UIViewController
    
    init(viewController: UIViewController) {
        self.viewController = viewController
    }
    
    static func JSONStringify(_ jsonObj: Any) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObj)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            return ""
        }
    }
    
    func logSolution(_ solution: String) {
        let logbookScheme = "appquest://submit"
        let encodedSolution = solution.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let urlStr = "\(logbookScheme)/\(encodedSolution)"
        let url = URL(string: urlStr)!
        UIApplication.shared.open(url)
    }
    
    func scanQRCode(completion: @escaping (String) -> Void) {
        presentQRCodeReader { reader in
            reader.shouldCaptureImage = false
            reader.onCodeDetected = { code in
                reader.navigationController?.dismiss(animated: true) {
                    completion(code)
                }
            }
        }
    }
    
    func scanQRCodeAndCaptureImage(completion: @escaping (String, UIImage) -> Void) {
        presentQRCodeReader { reader in
            reader.shouldCaptureImage = true
            reader.onCodeDetectedAndImageCaptured = { code, img in
                reader.navigationController?.dismiss(animated: true) {
                    completion(code, img)
                }
            }
        }
    }
    
    private func presentQRCodeReader(configure: (QRCodeReaderViewController) -> ()) {
        let reader = QRCodeReaderViewController()
        let nc = UINavigationController(rootViewController: reader)
        nc.navigationBar.barTintColor = #colorLiteral(red: 0.04705882353, green: 0.3098039216, blue: 0.5647058824, alpha: 1)
        nc.navigationBar.isTranslucent = false
        nc.navigationBar.barStyle = .black
        configure(reader)
        viewController.present(nc, animated: true)
    }
    
    private class QRCodeReaderViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
        var shouldCaptureImage = false
        let session: AVCaptureSession
        let previewLayer: AVCaptureVideoPreviewLayer
        let highlightView: UIView
        var photoOutput: AVCapturePhotoOutput!
        var detectedCode: String?
        var onCodeDetected: ((String) -> ())?
        var onCodeDetectedAndImageCaptured: ((String, UIImage) -> ())?
        
        init() {
            highlightView = UIView()
            highlightView.layer.borderColor = UIColor.green.cgColor
            highlightView.layer.borderWidth = 3
            session = AVCaptureSession()
            
            let preset = AVCaptureSessionPresetHigh
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            super.init(nibName: nil, bundle: nil)
            
            self.title = "QR-Code-Scanner"
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancel))
            cancelButton.tintColor = #colorLiteral(red: 0.9932497144, green: 0.6978339553, blue: 0.2971298099, alpha: 1)
            self.navigationItem.leftBarButtonItem = cancelButton
        }
        
        func cancel() {
            self.dismiss(animated: true)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLayoutSubviews() {
            previewLayer.frame = view.bounds
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            self.view.addSubview(highlightView)
            
            do {
                let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
                let input = try AVCaptureDeviceInput(device: device)
                session.addInput(input)
            } catch _ {
                print("Error: Can't create AVCaptureDeviceInput")
            }
            
            let output = AVCaptureMetadataOutput()
            output.setMetadataObjectsDelegate(self, queue: .main)
            session.addOutput(output)
            output.metadataObjectTypes = output.availableMetadataObjectTypes
            
            if shouldCaptureImage {
                self.photoOutput = AVCapturePhotoOutput()
                self.session.addOutput(photoOutput)
            }
            
            previewLayer.frame = self.view.bounds
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            view.layer.addSublayer(previewLayer)
            session.startRunning()
            
            self.view.bringSubview(toFront: highlightView)
        }
        
        func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
            highlightView.frame = CGRect.zero
            
            for metadata in metadataObjects {
                if let metadataObject = metadata as? AVMetadataObject,
                    metadataObject.type == AVMetadataObjectTypeQRCode,
                    let barCodeObject = previewLayer.transformedMetadataObject(for: metadataObject) as? AVMetadataMachineReadableCodeObject,
                    let machineReadableObject = metadataObject as? AVMetadataMachineReadableCodeObject {
                    
                    let detectionString = machineReadableObject.stringValue
                    highlightView.frame = barCodeObject.bounds
                    
                    if detectionString != nil && detectedCode == nil {
                        detectedCode = detectionString
                        if shouldCaptureImage {
                            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
                        } else {
                            onCodeDetected?(detectedCode!)
                        }
                        return
                    }
                }
            }
        }
        
        func capture(_ captureOutput: AVCapturePhotoOutput,
                     didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                     previewPhotoSampleBuffer: CMSampleBuffer?,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     bracketSettings: AVCaptureBracketedStillImageSettings?,
                     error: Error?) {
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            
            if let photoSampleBuffer = photoSampleBuffer,
                let jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer),
                let image = UIImage(data: jpegData),
                let detectedCode = detectedCode {
                self.onCodeDetectedAndImageCaptured?(detectedCode, image)
                self.session.stopRunning()
            }
        }
        
        override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
            switch toInterfaceOrientation {
            case .portrait:
                previewLayer.connection.videoOrientation = .portrait
            case .portraitUpsideDown:
                previewLayer.connection.videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                previewLayer.connection.videoOrientation = .landscapeLeft
            case .landscapeRight:
                previewLayer.connection.videoOrientation = .landscapeRight
            default:
                previewLayer.connection.videoOrientation = .portrait
            }
        }
    }
}
