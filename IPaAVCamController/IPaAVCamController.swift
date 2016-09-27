//
//  IPaAVCamController.swift
//  IPaAVCamController
//
//  Created by IPa Chen on 2015/7/9.
//  Copyright (c) 2015年 A Magic Studio. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class IPaAVCamController :NSObject{
    var cameraCount:Int {
        get {
            return AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo).count
        }
    }
    var minCount:Int {
        get {
            return AVCaptureDevice.devices(withMediaType: AVMediaTypeAudio).count
        }
    }
    var isRecording:Bool {
        get {
            if let movieFileOutput = movieFileOutput {
                return movieFileOutput.isRecording
            }
            return false
        }
    }
    
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
        session.sessionPreset = AVCaptureSessionPresetPhoto
        return session
    }()
    var audioInput:AVCaptureDeviceInput?
    var videoInput:AVCaptureDeviceInput?
    var stillImageOutput:AVCaptureStillImageOutput?
    
    var backgroundRecordingID:UIBackgroundTaskIdentifier?
    var canWorking:Bool {
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
            let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeAudio)
            return devices?.first as? AVCaptureDevice
        }

    }
    override init (){
        super.init()
//        let notificationCenter = NSNotificationCenter.defaultCenter()
//        deviceConnectedObserver = notificationCenter.addObserverForName(AVCaptureDeviceWasConnectedNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: {
//            noti in
//            if let device:AVCaptureDevice = noti.object as? AVCaptureDevice {
//                var sessionHasDeviceWithMatchingMediaType:Bool = false
//                var deviceMediaType:String?
//                
//                if device.hasMediaType(AVMediaTypeAudio) {
//                    deviceMediaType = AVMediaTypeAudio
//                }
//                else if device.hasMediaType(AVMediaTypeVideo) {
//                    deviceMediaType = AVMediaTypeVideo
//                }
//                if let deviceMediaType = deviceMediaType {
//                    for input in self.session.inputs {
//                        if let inputDevice:AVCaptureDeviceInput = input as? AVCaptureDeviceInput {
//                            if inputDevice.device.hasMediaType(deviceMediaType) {
//                                sessionHasDeviceWithMatchingMediaType = true
//                                break
//                            }
//                        }
//                    }
//
//                    if !sessionHasDeviceWithMatchingMediaType {
//                        var error:NSError?
//                        let input = AVCaptureDeviceInput.deviceInputWithDevice(device, error: &error) as! AVCaptureDeviceInput
//                        if self.session.canAddInput(input) {
//                            self.session.addInput(input)
//                        }
//
//                    }
//                    
//                }
//                if let delegate = self.delegate {
//                    delegate.onIPaAVCamControllerDeviceConfigurationChanged(self)
//                }
//            }
//        })
//        deviceDisconnectObserver = notificationCenter.addObserverForName(AVCaptureDeviceWasDisconnectedNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: {
//            noti in
//            if let device:AVCaptureDevice = noti.object as? AVCaptureDevice {
//                if device.hasMediaType(AVMediaTypeAudio) {
//                    if let audioInput = self.audioInput {
//                        self.session.removeInput(audioInput)
//                        self.audioInput = nil
//                    }
//
//                }
//                else if device.hasMediaType(AVMediaTypeVideo) {
//                    if let videoInput = self.videoInput {
//                        self.session.removeInput(videoInput)
//                        self.videoInput = nil
//                    }
//
//                }
//                if let delegate = self.delegate {
//                    delegate.onIPaAVCamControllerDeviceConfigurationChanged(self)
//                }
//            }
//        })
    }
    deinit {
//        if let deviceConnectedObserver = deviceConnectedObserver {
//            NSNotificationCenter.defaultCenter().removeObserver(deviceConnectedObserver)
//        }
//        if let deviceDisconnectedObserver = deviceDisconnectObserver {
//             NSNotificationCenter.defaultCenter().removeObserver(deviceDisconnectedObserver)
//        }
        session.stopRunning()
        videoInput = nil;
        audioInput = nil;
        stillImageOutput = nil;

    }
    open func setupCamera(_ position:AVCaptureDevicePosition,error:NSErrorPointer) {
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
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
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

    
    open func setPreviewView(_ view:UIView,videoGravity:String) {
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
        setPreviewView(view,videoGravity:AVLayerVideoGravityResizeAspectFill)
        return view;
    }
    open func setupCaptureStillImage(_ cameraPosition:AVCaptureDevicePosition, error:NSErrorPointer?)
    {
        session.stopRunning()
        if movieFileOutput != nil {
            session.removeOutput(movieFileOutput)
        }
        if audioInput != nil {
            session.removeInput(audioInput)
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
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                }
            }
        }

        if stillImageOutput == nil {
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput?.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
        }
        if session.canAddOutput(stillImageOutput) {
            session.addOutput(stillImageOutput)
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
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
            
            
            for connection in movieFileOutput.connections {
                if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                    for port in connection.inputPorts  {
                        if let port:AVCaptureInputPort = port as? AVCaptureInputPort {
                            if port.mediaType == AVMediaTypeVideo {
                                videoConnection = connection
                            }
//                            else if port.mediaType == AVMediaTypeAudio {
//                                audioConnection = connection
//                            }
                        }
                    }
                    
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
        
            if let videoConnection = connectionWithMediaType(AVMediaTypeVideo, connections: movieFileOutput.connections as [AnyObject]!) {
            
                if videoConnection.isVideoOrientationSupported {
                    videoConnection.videoOrientation = self.orientation
                }
                movieFileOutput.startRecording(toOutputFileURL: outputFileURL, recordingDelegate: delegate)
                
            
            }
        }
    }
    
    open func stopRecording()
    {
        movieFileOutput?.stopRecording()
    }
    open func captureStillImageData(_ complete:@escaping (Data)->()) {
        if let stillImageOutput = stillImageOutput {
            if let stillImageConnection = connectionWithMediaType(AVMediaTypeVideo, connections: stillImageOutput.connections as [AnyObject]!) {
                
                if stillImageConnection.isVideoOrientationSupported {
                    stillImageConnection.videoOrientation = orientation
                    stillImageOutput.captureStillImageAsynchronously(from: stillImageConnection, completionHandler: {
                        imageDataSampleBuffer,error in
                        let imageData =  AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                        complete(imageData!)
                    })
                }
                
            }
            
        }
    }
    open func captureStillImage(_ complete:@escaping (UIImage)->()) {
        captureStillImageData({
            imageData in
            if let image = UIImage(data: imageData) {
                complete(image)
            }
            
        })
    }
    // Toggle between the front and back camera, if both are present.
    open func toggleCamera() -> Bool {
        if let videoInput = videoInput {
            let cameraCount = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo).count
            if cameraCount > 1 {
                //var error:NSError?
                var newVideoInput:AVCaptureDeviceInput?
                let position:AVCaptureDevicePosition = videoInput.device.position

                if position == .back {
                    newVideoInput = try? AVCaptureDeviceInput(device: frontFacingCamera)
                }
                else if (position == .front) {
                    newVideoInput = try? AVCaptureDeviceInput(device: backFacingCamera)
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
    open func setCamera(_ position:AVCaptureDevicePosition,flashMode:AVCaptureFlashMode)
    {
        if let camera = getCamera(position) {
            if camera.hasFlash {
                do {
                    try camera.lockForConfiguration()
                    if camera.isFlashModeSupported(flashMode) {
                        camera.flashMode = flashMode
                    }
                    camera.unlockForConfiguration()
                } catch _ {
                }
            }
        }
    }
    
    open func setCamera(_ position:AVCaptureDevicePosition,torchMode:AVCaptureTorchMode) {
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
    open func getCameraFlashMode(_ position:AVCaptureDevicePosition) -> AVCaptureFlashMode {
        if let camera = getCamera(position) {
            return camera.flashMode
        }
        return .off
    }
    open func getCameraTorchMode(_ position:AVCaptureDevicePosition) -> AVCaptureTorchMode {
        if let camera = getCamera(position) {
            return camera.torchMode
        }
        return .off
    }
    open func setCameraFocusAt(_ point:CGPoint,focusMode:AVCaptureFocusMode) {
        if let videoInput = videoInput {
            let device = videoInput.device
            if (device?.isFocusPointOfInterestSupported)! && (device?.isFocusModeSupported(focusMode))! {
              
                do {
                    try device?.lockForConfiguration()
                    device?.focusPointOfInterest = point
                    device?.focusMode = focusMode
                    device?.unlockForConfiguration()
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
        
    
    }
//MARK : private
    func getCamera(_ position:AVCaptureDevicePosition) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        
        for device in devices! {
            if let device:AVCaptureDevice = device as? AVCaptureDevice {
                if (device.position == position) {
                    return device;
                }
            }
        }
        return nil;
        
    }

    fileprivate func connectionWithMediaType(_ mediaType:String, connections:[AnyObject]!) -> AVCaptureConnection?
    {
        for connection in connections {
            if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                for port in connection.inputPorts  {
                    if let port:AVCaptureInputPort = port as? AVCaptureInputPort {
                        if port.mediaType == mediaType {
                            return connection;
                        }
                    }
                }

            }
        }

        return nil;
    }
    
}
