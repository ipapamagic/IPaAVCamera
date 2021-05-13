//
//  IPaAVCamera.swift
//  IPaAVCamera
//
//  Created by IPa Chen on 2015/7/9.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import IPaImageTool
open class IPaAVCamera :NSObject{
    var orientationObserver:NSObjectProtocol?
    var cameras:[AVCaptureDevice] {
        var deviceTypes = [AVCaptureDevice.DeviceType]()
        if #available(iOS 13.0, *) {
            deviceTypes = [.builtInDualCamera,.builtInDualWideCamera,.builtInTelephotoCamera,.builtInTripleCamera,.builtInTrueDepthCamera,.builtInUltraWideCamera,.builtInWideAngleCamera]
        } else {
            // Fallback on earlier versions
            deviceTypes = [.builtInDualCamera,.builtInTelephotoCamera]
        }
        
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes,
                                                                              mediaType: AVMediaType.video,
                                                                              position: AVCaptureDevice.Position.unspecified)

        return deviceDescoverySession.devices
    }
    open var cameraCount:Int {
        get {
            return self.cameras.count
        }
    }
    
    open var isRecording:Bool {
        get {
            if let movieFileOutput = movieFileOutput {
                return movieFileOutput.isRecording
            }
            return false
        }
    }
//    lazy var outputSetting = AVCapturePhotoSettings(format: [AVVideoCodecKey:AVVideoCodecType.jpeg])
    var movieFileOutput:AVCaptureMovieFileOutput?
    var _orientation:AVCaptureVideoOrientation = .portrait
    open var orientation:AVCaptureVideoOrientation {
        get {
            return _orientation
        }
    }
    var _previewLayer:AVCaptureVideoPreviewLayer?
    open var previewLayer:AVCaptureVideoPreviewLayer? {
        get {
            return _previewLayer
        }
    }
    lazy var session:AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        return session
    }()
    var audioInput:AVCaptureDeviceInput?
    var videoInput:AVCaptureDeviceInput?
    var photoOutput:AVCapturePhotoOutput?
    
    var backgroundRecordingID:UIBackgroundTaskIdentifier?
    open var canWorking:Bool {
        get {
            return videoInput != nil
        }
    }
    lazy var outputFileURL:URL = URL(fileURLWithPath: NSTemporaryDirectory() + "output.mov")
    // Find a front facing camera, returning nil if one is not found
    var frontFacingCamera:AVCaptureDevice? {
        get {
            return getCamera(.front)
        }
    }
    
    // Find a back facing camera, returning nil if one is not found
    var backFacingCamera:AVCaptureDevice? {
        get {
            return getCamera(.back)
        }
    }
    
    // Find and return an audio device, returning nil if one is not found
    var audioDevice:AVCaptureDevice? {
        get {
            let deviceDescoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone],
                                                                                  mediaType: AVMediaType.audio,
                                                                                  position: AVCaptureDevice.Position.unspecified)
            let devices = deviceDescoverySession.devices
            return devices.first
        }

    }
    var capturePhotoDataCallback:((Data) -> ())?
    public var flashMode:AVCaptureDevice.FlashMode = .auto
    
    public override init (){
        super.init()

    }
    deinit {

        session.stopRunning()
        videoInput = nil;
        audioInput = nil;
        photoOutput = nil;

    }
    open func setupCamera(_ position:AVCaptureDevice.Position,error:NSErrorPointer) {
        var settingError:NSError?
        let cameraDevice = getCamera(position)
        if let cameraDevice = cameraDevice {
            do {
                videoInput = try AVCaptureDeviceInput(device:cameraDevice)
            } catch let error as NSError {
                settingError = error
                videoInput = nil
            }
            if settingError != nil {
                let localizedDescription = "Video Input init error";
                let localizedFailureReason = "Can not initial video input.";
                let errorDict = [NSLocalizedDescriptionKey:localizedDescription,NSLocalizedFailureReasonErrorKey:localizedFailureReason]
                
                
                error?.pointee = NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
            }
            else {
                if session.canAddInput(videoInput!) {
                    session.addInput(videoInput!)
                }

            }
        }
        else {
            let localizedDescription = "Video Input init error";
            let localizedFailureReason = "Can not get Camera for position";
            let errorDict = [NSLocalizedDescriptionKey:localizedDescription,NSLocalizedFailureReasonErrorKey:localizedFailureReason]
            
            
            error?.pointee = NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
        }
    }

    open func setPreview(_ enable:Bool) {
        if let previewLayer = self.previewLayer {
            if let connection = previewLayer.connection {
                connection.isEnabled = enable
            }
        }
    }
    open func startObserveDeviceOrientation() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        orientationObserver = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: OperationQueue.main, using: {
            noti in
            let deviceOrientation = UIDevice.current.orientation
            self.setOrientationFrom(deviceOrientation)
        })
    }
    open func stopObserveDeviceOrientation() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        if let orientationObserver = orientationObserver {
            NotificationCenter.default.removeObserver(orientationObserver)
        }
    }
    open func setPreviewView(_ view:UIView,videoGravity:AVLayerVideoGravity) {
        if let _previewLayer = _previewLayer {
            _previewLayer.removeFromSuperlayer()
        }
        else {
            _previewLayer = AVCaptureVideoPreviewLayer(session: session)
        }
        
        let viewLayer = view.layer
        viewLayer.masksToBounds = true
        _previewLayer!.frame = viewLayer.bounds
        _previewLayer?.backgroundColor = UIColor.black.cgColor
        
        _previewLayer!.videoGravity = videoGravity
        viewLayer.addSublayer(previewLayer!)
        
    }
    open func createPreviewView(_ size:CGSize) -> UIView
    {
        let view = UIView(frame: CGRect(origin: CGPoint.zero, size: size))
        setPreviewView(view,videoGravity:AVLayerVideoGravity.resizeAspectFill)
        return view;
    }
    open func setupCapturePhoto(_ cameraPosition:AVCaptureDevice.Position, error:NSErrorPointer?)
    {
        session.stopRunning()
        if movieFileOutput != nil {
            session.removeOutput(movieFileOutput!)
        }
        if audioInput != nil {
            session.removeInput(audioInput!)
        }
        if videoInput == nil {
            let device = getCamera(.back)
            if let device = device {
                do {
                    videoInput = try AVCaptureDeviceInput(device: device)
                } catch let error1 as NSError {
                    error??.pointee = error1
                    videoInput = nil
                }
                if error != nil {
                    return
                }
                if session.canAddInput(videoInput!) {
                    session.addInput(videoInput!)
                }
            }
        }

        if photoOutput == nil {
            photoOutput = AVCapturePhotoOutput()
            
//            photoOutput?.photoSettingsForSceneMonitoring = self.outputSetting
        }
        if session.canAddOutput(photoOutput!) {
            session.addOutput(photoOutput!)
        }
        
        session.startRunning()
    }
    open func setupRecordVideo(_ error:NSErrorPointer?) {
        session.stopRunning()
        if movieFileOutput == nil {
            movieFileOutput = AVCaptureMovieFileOutput()
        }
        var videoConnection:AVCaptureConnection?
        //var audioConnection:AVCaptureConnection?
        
        if let movieFileOutput = movieFileOutput {
            if session.canAddOutput(movieFileOutput) {
            
                session.addOutput(movieFileOutput)
            }
            if (audioInput == nil) {
                if let audioDevice = audioDevice {
                    do {
                        audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    } catch let error1 as NSError {
                        error??.pointee = error1
                        audioInput = nil
                    }
                    if error != nil {
                        return
                    }
                }
            }
            if session.canAddInput(audioInput!) {
                session.addInput(audioInput!)
            }
            
            
            for connection in movieFileOutput.connections {
                for port in connection.inputPorts  {
                    if port.mediaType == AVMediaType.video {
                        videoConnection = connection
                    }
//                            else if port.mediaType == AVMediaTypeAudio {
//                                audioConnection = connection
//                            }
         
                }
                    
                
            }
        }
        
        if videoConnection == nil || !videoConnection!.isActive {
            // Send an error to the delegate if video recording is unavailable
            let localizedDescription = "Video recording unavailable"
            let localizedFailureReason = "Movies recorded on this device will only contain audio. They will be accessible through iTunes file sharing."
            let errorDict = [NSLocalizedDescriptionKey:
                localizedDescription,NSLocalizedFailureReasonErrorKey:            localizedFailureReason]
            error??.pointee = NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
            return
        }
     
        //start running
        session.startRunning()
    }
    open func startRecording(_ delegate:AVCaptureFileOutputRecordingDelegate ,error:NSErrorPointer)
    {
        if let movieFileOutput = movieFileOutput {
            if UIDevice.current.isMultitaskingSupported {
        // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns
        // to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library
        // when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error:
        // after the recorded file has been saved.
                backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                    
                })
            }
            let filePath = outputFileURL.path
            let fileManager = FileManager.default
            
            if fileManager.fileExists(atPath: filePath) {
                do {
                    try fileManager.removeItem(atPath: filePath)
                } catch let error1 as NSError {
                    error?.pointee = error1
                    return
                }
            }
        
            if let videoConnection = connectionWithMediaType(AVMediaType.video.rawValue, connections: movieFileOutput.connections as [AnyObject]?) {
            
                if videoConnection.isVideoOrientationSupported {
                    videoConnection.videoOrientation = self.orientation
                }
                movieFileOutput.startRecording(to: outputFileURL, recordingDelegate: delegate)
                
            
            }
        }
    }
    
    open func stopRecording()
    {
        movieFileOutput?.stopRecording()
    }
    open func capturePhoto(in rectOfPreview:CGRect,complete:@escaping(UIImage?)->()) {
        self.capturePhotoData({
            data in
            guard let image = UIImage(data: data),let previewLayer = self.previewLayer else {
                complete(nil)
                return
            }
            
            
                
            let rect = previewLayer.metadataOutputRectConverted(fromLayerRect: rectOfPreview)
                
            var outputMarkRect = CGRect.zero
            switch (image.imageOrientation) {
            case .right,.rightMirrored:
                outputMarkRect.origin = CGPoint(x: 1 - rect.maxY, y: rect.origin.x)
                outputMarkRect.size = CGSize(width: rect.height, height: rect.width)
            
            case .left,.leftMirrored:
                outputMarkRect.origin = CGPoint(x: rect.origin.y, y: 1 - rect.maxX)
                outputMarkRect.size = CGSize(width: rect.height, height: rect.width)
            case .up,.upMirrored:
                outputMarkRect = rect
            case .down,.downMirrored:
                outputMarkRect.size = rect.size
                outputMarkRect.origin = CGPoint(x: 1 - rect.maxX, y: 1 - rect.maxY)
            @unknown default:
                break
            }
            outputMarkRect.origin.x *= image.size.width
            outputMarkRect.origin.y *= image.size.height
            outputMarkRect.size.width *= image.size.width
            outputMarkRect.size.height *= image.size.height
            
            complete(image.image(cropRect: outputMarkRect))
            
        })
    }
    open func capturePhotoData(_ complete:@escaping (Data)->()) {
        if let photoOutput = photoOutput {
            if let photoConnection = connectionWithMediaType(AVMediaType.video.rawValue, connections: photoOutput.connections as [AnyObject]?) {
                
                if photoConnection.isVideoOrientationSupported {
                    photoConnection.videoOrientation = orientation
                    self.capturePhotoDataCallback = complete
                    let setting = AVCapturePhotoSettings()
                    setting.flashMode = self.flashMode
                    photoOutput.capturePhoto(with: setting, delegate: self)
                    
                    
                }
                
            }
            
        }
    }
    // Toggle between the front and back camera, if both are present.
    open func toggleCamera() -> Bool {
        if let videoInput = videoInput {
            
            if self.cameraCount > 1 {
                //var error:NSError?
                var newVideoInput:AVCaptureDeviceInput?
                let position:AVCaptureDevice.Position = videoInput.device.position

                if position == .back {
                    newVideoInput = try? AVCaptureDeviceInput(device: frontFacingCamera!)
                }
                else if (position == .front) {
                    newVideoInput = try? AVCaptureDeviceInput(device: backFacingCamera!)
                }
                else {
                    return false
                }
                if let newVideoInput = newVideoInput {
                    session.beginConfiguration()
                    if session.canAddInput(newVideoInput) {
                        session.removeInput(videoInput)
                        session.addInput(newVideoInput)
                    }
                    session.commitConfiguration()
                }
                
            }
        }
        return false
    }
// MARK:Camera Properties
    
    open func setCamera(_ position:AVCaptureDevice.Position,torchMode:AVCaptureDevice.TorchMode) {
        if let camera = getCamera(position) {
            if camera.hasTorch {
                do {
                    try camera.lockForConfiguration()
                    if camera.isTorchModeSupported(torchMode) {
                        camera.torchMode = torchMode
                    }
                    camera.unlockForConfiguration()
                } catch _ {
                }
            }
        }
    }
    
    open func getCameraTorchMode(_ position:AVCaptureDevice.Position) -> AVCaptureDevice.TorchMode {
        if let camera = getCamera(position) {
            return camera.torchMode
        }
        return .off
    }
    open func setCameraFocusAt(_ point:CGPoint,focusMode:AVCaptureDevice.FocusMode) {
        if let videoInput = videoInput {
            let device = videoInput.device
            if (device.isFocusPointOfInterestSupported) && (device.isFocusModeSupported(focusMode)) {
              
                do {
                    try device.lockForConfiguration()
                    device.focusPointOfInterest = point
                    device.focusMode = focusMode
                    device.unlockForConfiguration()
                } catch _ as NSError {

                }
            }
        }

    }
    open func setOrientationFrom(_ deviceOrientation:UIDeviceOrientation) {
        switch (deviceOrientation) {
        case .portrait:
            _orientation = .portrait
        case .portraitUpsideDown:
            
            _orientation = .portraitUpsideDown

        case .landscapeLeft:
            _orientation = .landscapeRight

        case .landscapeRight:
            _orientation = .landscapeLeft
        default:
            break
        }
        
        self.previewLayer?.connection?.videoOrientation = _orientation
    }
//MARK : private
    func getCamera(_ position:AVCaptureDevice.Position) -> AVCaptureDevice? {
        return self.cameras.first { device in
            return device.position == position
        }
    }

    fileprivate func connectionWithMediaType(_ mediaType:String, connections:[AnyObject]!) -> AVCaptureConnection?
    {
        for connection in connections {
            if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                for port in connection.inputPorts  {
                    if port.mediaType.rawValue == mediaType {
                        return connection;
                    }
                }

            }
        }

        return nil;
    }
    
}
extension IPaAVCamera:AVCapturePhotoCaptureDelegate
{
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let callback = self.capturePhotoDataCallback,let data = photo.fileDataRepresentation() {
            callback(data)
            self.capturePhotoDataCallback = nil
        }
    }
}
