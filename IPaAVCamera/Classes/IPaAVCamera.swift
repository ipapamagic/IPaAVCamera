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
    open var photoQualityPreset:AVCaptureSession.Preset {
        get {
            return self.session.sessionPreset
        }
        set {
            if self.session.canSetSessionPreset(newValue) {
                self.session.sessionPreset = newValue
            }
        }
    }
    var activeDevice:AVCaptureDevice?
    var audioInput:AVCaptureDeviceInput?
    var videoInput:AVCaptureDeviceInput?
    lazy var _photoOutput:AVCapturePhotoOutput = AVCapturePhotoOutput()
    public var photoOutput:AVCapturePhotoOutput {
        return _photoOutput
    }
    var backgroundRecordingID:UIBackgroundTaskIdentifier?
    open var canWorking:Bool {
        get {
            return videoInput != nil
        }
    }
    lazy var outputFileURL:URL = URL(fileURLWithPath: NSTemporaryDirectory() + "output.mov")
    
    
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
    var capturePhotoDataCallback:((AVCapturePhoto) -> ())?
    
    
    public override init (){
        super.init()

    }
    deinit {

        session.stopRunning()
        videoInput = nil
        audioInput = nil

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
            self.setPreviewOrientation(from: deviceOrientation)
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
    fileprivate func setupVideoInput(_ deviceTypes:[AVCaptureDevice.DeviceType],position:AVCaptureDevice.Position) throws {
        if videoInput == nil {
            for (index,deviceType) in deviceTypes.enumerated() {
            
                let cameraDevice = getCamera(deviceType,position: position)
                if let cameraDevice = cameraDevice {
                    do {
                        let input = try AVCaptureDeviceInput(device:cameraDevice)
                        if session.canAddInput(input) {
                            session.addInput(input)
                            self.activeDevice = cameraDevice
                            self.videoInput = input
                            
                            break
                        }
                    } catch let error as NSError {
                        self.videoInput = nil
                        self.activeDevice = nil
                        if index == (deviceTypes.count - 1)
                        {
                            throw error
                        }
                    }
                }
                else if index == (deviceTypes.count - 1) {
                    let localizedDescription = "Video Input init error";
                    let localizedFailureReason = "Can not get Camera for types";
                    let errorDict = [NSLocalizedDescriptionKey:localizedDescription,NSLocalizedFailureReasonErrorKey:localizedFailureReason]
                    throw NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
                }
          
            }
            
        }
        
    }
    open func setupCapturePhoto(_ deviceTypes:[AVCaptureDevice.DeviceType],position:AVCaptureDevice.Position, torchMode:AVCaptureDevice.TorchMode = .auto) throws
    {
        session.stopRunning()
        if movieFileOutput != nil {
            session.removeOutput(movieFileOutput!)
        }
        if audioInput != nil {
            session.removeInput(audioInput!)
        }
        
        try self.setupVideoInput(deviceTypes,position: position)
        if let cameraDevice = self.activeDevice {
            if cameraDevice.hasTorch{
                do {
                    try cameraDevice.lockForConfiguration()
                    if cameraDevice.isTorchModeSupported(torchMode) {
                        cameraDevice.torchMode = torchMode
                    }
                    cameraDevice.unlockForConfiguration()
                } catch _ {
                }
            }
        }
        
        
        if session.canAddOutput(_photoOutput) {
            session.addOutput(_photoOutput)
        }
        
        session.startRunning()
    }
    open func setupRecordVideo(_ deviceTypes:[AVCaptureDevice.DeviceType],position:AVCaptureDevice.Position) throws {
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
                    } catch let error {
                        
                        audioInput = nil
                        throw error
                    }
                    
                }
            }
            if session.canAddInput(audioInput!) {
                session.addInput(audioInput!)
            }
            try self.setupVideoInput(deviceTypes,position: position)
            
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
            throw NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
            
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
    fileprivate func convertOutputRect(from rectOfPreview:CGRect,size:CGSize,orientation:UIImage.Orientation) -> CGRect {
        let rect = self.previewLayer?.metadataOutputRectConverted(fromLayerRect: rectOfPreview) ?? .zero
            
        var outputMarkRect = CGRect.zero
        switch (orientation) {
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
        outputMarkRect.origin.x *= size.width
        outputMarkRect.origin.y *= size.height
        outputMarkRect.size.width *= size.width
        outputMarkRect.size.height *= size.height
        return outputMarkRect
        
    }
    open func capturePhoto(in rectOfPreview:CGRect,setting:AVCapturePhotoSettings ,complete:@escaping(UIImage?)->()) {
        self.capturePhoto(setting,complete:{
            photo in
            var resultImage:UIImage?
            if let pixelBuffer = photo.pixelBuffer,let orientation = photo.metadata[kCGImagePropertyOrientation as String] as? NSNumber,let cgOrientation = CGImagePropertyOrientation(rawValue: orientation.uint32Value) {
                var ciimage = CIImage(cvPixelBuffer: pixelBuffer).oriented(cgOrientation)
                let rect = self.convertOutputRect(from:rectOfPreview,size:ciimage.extent.size,orientation: .up)
                ciimage = ciimage.cropped(to: rect)
                resultImage = ciimage.uiImage
            }
            else if let data = photo.fileDataRepresentation(),let image = UIImage(data: data) {
                let rect = self.convertOutputRect(from:rectOfPreview,size:image.size,orientation: image.imageOrientation)
                resultImage = image.image(cropRect: rect)
            }
            complete(resultImage)
            
        })
    }
    open func capturePhoto(_ setting:AVCapturePhotoSettings, complete:@escaping (AVCapturePhoto)->()) {
        
        if let photoConnection = connectionWithMediaType(AVMediaType.video.rawValue, connections: photoOutput.connections as [AnyObject]?) {
            
            if photoConnection.isVideoOrientationSupported {
                photoConnection.videoOrientation = orientation
                
                
            }
            photoOutput.isHighResolutionCaptureEnabled = setting.isHighResolutionPhotoEnabled
            self.capturePhotoDataCallback = complete
            photoOutput.capturePhoto(with: setting, delegate: self)
            
            
        }
        
    
    }
// MARK:Camera Properties
    
    open func getCurrentCameraTorchMode() -> AVCaptureDevice.TorchMode {
        if let camera = activeDevice {
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
    open func setPreviewOrientation(from deviceOrientation:UIDeviceOrientation) {
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
    func getCamera(_ deviceType:AVCaptureDevice.DeviceType,position:AVCaptureDevice.Position) -> AVCaptureDevice? {
        return self.cameras.first {
            camera in
            return camera.deviceType == deviceType && camera.position == position
            
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
        
        if let callback = self.capturePhotoDataCallback {
            callback(photo)
            
            self.capturePhotoDataCallback = nil
        }
    }
}
