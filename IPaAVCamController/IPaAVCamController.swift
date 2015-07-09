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
@objc protocol IPaAVCamControllerDelegate {
    func onIPaAVCamControllerDeviceConfigurationChanged(controller:IPaAVCamController);
    func onIPaAVCamControllerRecordingDidFinish(controller:IPaAVCamController ,outputFile:NSURL,error:NSError)
    func onIPaAVCamControllerDidCaptured(controller:IPaAVCamController, image:UIImage)
}
public class IPaAVCamController :NSObject, AVCaptureFileOutputRecordingDelegate{
    weak var delegate:IPaAVCamControllerDelegate?
    public var cameraCount:Int {
        get {
            return AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count
        }
    }
    public var minCount:Int {
        get {
            return AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio).count
        }
    }
    public var isRecording:Bool {
        get {
            if let movieFileOutput = movieFileOutput {
                return movieFileOutput.recording
            }
            return false
        }
    }
    
    var movieFileOutput:AVCaptureMovieFileOutput?
    var _orientation:AVCaptureVideoOrientation = .Portrait
    public var orientation:AVCaptureVideoOrientation {
        get {
            return _orientation
        }
    }
    var _previewLayer:AVCaptureVideoPreviewLayer?
    public var previewLayer:AVCaptureVideoPreviewLayer? {
        get {
            return _previewLayer
        }
    }
    lazy var session = AVCaptureSession()
    var audioInput:AVCaptureDeviceInput?
    var videoInput:AVCaptureDeviceInput?
    var stillImageOutput:AVCaptureStillImageOutput?
    var deviceConnectedObserver:NSObjectProtocol?
    var deviceDisconnectObserver:NSObjectProtocol?
    var backgroundRecordingID:UIBackgroundTaskIdentifier?
    var canWorking:Bool {
        get {
            return videoInput != nil
        }
    }
    lazy var outputFileURL:NSURL = NSURL(fileURLWithPath: NSTemporaryDirectory() + "output.mov")!
    // Find a front facing camera, returning nil if one is not found
    var frontFacingCamera:AVCaptureDevice? {
        get {
            return getCamera(.Front)
        }
    }
    
    // Find a back facing camera, returning nil if one is not found
    var backFacingCamera:AVCaptureDevice? {
        get {
            return getCamera(.Back)
        }
    }
    
    // Find and return an audio device, returning nil if one is not found
    var audioDevice:AVCaptureDevice? {
        get {
            let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio)
            return devices.first as? AVCaptureDevice
        }

    }
    override init (){
        super.init()
        let notificationCenter = NSNotificationCenter.defaultCenter()
        deviceConnectedObserver = notificationCenter.addObserverForName(AVCaptureDeviceWasConnectedNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: {
            noti in
            if let device:AVCaptureDevice = noti.object as? AVCaptureDevice {
                var sessionHasDeviceWithMatchingMediaType:Bool = false
                var deviceMediaType:String?
                
                if device.hasMediaType(AVMediaTypeAudio) {
                    deviceMediaType = AVMediaTypeAudio
                }
                else if device.hasMediaType(AVMediaTypeVideo) {
                    deviceMediaType = AVMediaTypeVideo
                }
                if let deviceMediaType = deviceMediaType {
                    for input in self.session.inputs {
                        if let inputDevice:AVCaptureDeviceInput = input as? AVCaptureDeviceInput {
                            if inputDevice.device.hasMediaType(deviceMediaType) {
                                sessionHasDeviceWithMatchingMediaType = true
                                break
                            }
                        }
                    }

                    if !sessionHasDeviceWithMatchingMediaType {
                        var error:NSError?
                        let input = AVCaptureDeviceInput.deviceInputWithDevice(device, error: &error) as! AVCaptureDeviceInput
                        if self.session.canAddInput(input) {
                            self.session.addInput(input)
                        }

                    }
                    
                }
                if let delegate = self.delegate {
                    delegate.onIPaAVCamControllerDeviceConfigurationChanged(self)
                }
            }
        })
        deviceDisconnectObserver = notificationCenter.addObserverForName(AVCaptureDeviceWasDisconnectedNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: {
            noti in
            if let device:AVCaptureDevice = noti.object as? AVCaptureDevice {
                if device.hasMediaType(AVMediaTypeAudio) {
                    if let audioInput = self.audioInput {
                        self.session.removeInput(audioInput)
                        self.audioInput = nil
                    }

                }
                else if device.hasMediaType(AVMediaTypeVideo) {
                    if let videoInput = self.videoInput {
                        self.session.removeInput(videoInput)
                        self.videoInput = nil
                    }

                }
                if let delegate = self.delegate {
                    delegate.onIPaAVCamControllerDeviceConfigurationChanged(self)
                }
            }
        })
    }
    deinit {
        if let deviceConnectedObserver = deviceConnectedObserver {
            NSNotificationCenter.defaultCenter().removeObserver(deviceConnectedObserver)
        }
        if let deviceDisconnectedObserver = deviceDisconnectObserver {
             NSNotificationCenter.defaultCenter().removeObserver(deviceDisconnectedObserver)
        }
        session.stopRunning()
        videoInput = nil;
        audioInput = nil;
        stillImageOutput = nil;

    }
    public func setupCamera(position:AVCaptureDevicePosition,error:NSErrorPointer) {
        var settingError:NSError?
        var cameraDevice = getCamera(position)
        if let cameraDevice = cameraDevice {
            videoInput = AVCaptureDeviceInput(device:cameraDevice, error: &settingError)
            if settingError != nil {
                let localizedDescription = "Video Input init error";
                let localizedFailureReason = "Can not initial video input.";
                let errorDict = [NSLocalizedDescriptionKey:localizedDescription,NSLocalizedFailureReasonErrorKey:localizedFailureReason]
                
                
                error.memory = NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
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
            
            
            error.memory = NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
        }
    }

    
    public func setPreviewView(view:UIView) {
        if let _previewLayer = _previewLayer {
            _previewLayer.removeFromSuperlayer()
        }
        else {
            _previewLayer = AVCaptureVideoPreviewLayer(session: session)
        }
        
        let viewLayer = view.layer
        viewLayer.masksToBounds = true
        _previewLayer!.frame = view.bounds
        
        
        _previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        let firstLayer = viewLayer.sublayers.first as! CALayer
        viewLayer.insertSublayer(_previewLayer!, below: firstLayer)        
    }
    public func createPreviewView(size:CGSize) -> UIView
    {
        let view = UIView(frame: CGRect(origin: CGPointZero, size: size))
        setPreviewView(view)
        return view;
    }
    public func setupCaptureStillImage(cameraPosition:AVCaptureDevicePosition, error:NSErrorPointer)
    {
        session.stopRunning()
        if movieFileOutput != nil {
            session.removeOutput(movieFileOutput)
        }
        if audioInput != nil {
            session.removeInput(audioInput)
        }
        if videoInput == nil {
            var device = getCamera(.Back)
            if let device = device {
                videoInput = AVCaptureDeviceInput(device: device, error: error)
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
    public func setupRecordVideo(error:NSErrorPointer) {
        session.stopRunning()
        if movieFileOutput == nil {
            movieFileOutput = AVCaptureMovieFileOutput()
        }
        var videoConnection:AVCaptureConnection?
        var audioConnection:AVCaptureConnection?
        
        if let movieFileOutput = movieFileOutput {
            if session.canAddOutput(movieFileOutput) {
            
                session.addOutput(movieFileOutput)
            }
            if (audioInput == nil) {
                if let audioDevice = audioDevice {
                    audioInput = AVCaptureDeviceInput(device: audioDevice, error: error)
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
                            else if port.mediaType == AVMediaTypeAudio {
                                audioConnection = connection
                            }
                        }
                    }
                    
                }
            }
        }
        
        if videoConnection == nil || !videoConnection!.active {
            // Send an error to the delegate if video recording is unavailable
            let localizedDescription = "Video recording unavailable"
            let localizedFailureReason = "Movies recorded on this device will only contain audio. They will be accessible through iTunes file sharing."
            let errorDict = [NSLocalizedDescriptionKey:
                localizedDescription,NSLocalizedFailureReasonErrorKey:            localizedFailureReason]
            error.memory = NSError(domain: "IPaAVCam", code: 0, userInfo: errorDict)
            return
        }
     
        //start running
        session.startRunning()
    }
    public func startRecording(error:NSErrorPointer)
    {
        if let movieFileOutput = movieFileOutput {
            if UIDevice.currentDevice().multitaskingSupported {
        // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns
        // to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library
        // when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error:
        // after the recorded file has been saved.
                backgroundRecordingID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({
                    
                })
            }
            if let filePath = outputFileURL.path {
                let fileManager = NSFileManager.defaultManager()
                
                if fileManager.fileExistsAtPath(filePath) {
                    if !fileManager.removeItemAtPath(filePath,error:error)  {
                        return
                    }
                }
            }
            if let videoConnection = connectionWithMediaType(AVMediaTypeVideo, connections: movieFileOutput.connections) {
            
                if videoConnection.supportsVideoOrientation {
                    videoConnection.videoOrientation = self.orientation
                }
                movieFileOutput.startRecordingToOutputFileURL(outputFileURL, recordingDelegate: self)
                
            
            }
        }
    }
    
    public func stopRecording()
    {
        movieFileOutput?.stopRecording()
    }
    public func captureStillImage() {
        if let stillImageOutput = stillImageOutput {
            if let stillImageConnection = connectionWithMediaType(AVMediaTypeVideo, connections: stillImageOutput.connections) {
                
                if stillImageConnection.supportsVideoOrientation {
                    stillImageConnection.videoOrientation = orientation
                    stillImageOutput.captureStillImageAsynchronouslyFromConnection(stillImageConnection, completionHandler: {
                        imageDataSampleBuffer,error in
                        let imageData =  AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                        if let image = UIImage(data: imageData) {
                        
                            if let delegate = self.delegate {
                                delegate.onIPaAVCamControllerDidCaptured(self, image: image)
                            }
                        }
                    })
                }
                
            }
            
        }
    }
    // Toggle between the front and back camera, if both are present.
    public func toggleCamera() -> Bool {
        if let videoInput = videoInput {
            let cameraCount = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count
            if cameraCount > 1 {
                var error:NSError?
                var newVideoInput:AVCaptureDeviceInput?
                var position:AVCaptureDevicePosition = videoInput.device.position

                if position == .Back {
                    newVideoInput = AVCaptureDeviceInput(device: frontFacingCamera, error: nil)
                }
                else if (position == .Front) {
                    newVideoInput = AVCaptureDeviceInput(device: backFacingCamera, error: nil)
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
    public func setCamera(position:AVCaptureDevicePosition,flashMode:AVCaptureFlashMode)
    {
        if let camera = getCamera(position) {
            if camera.hasFlash {
                if camera.lockForConfiguration(nil) {
                    if camera.isFlashModeSupported(flashMode) {
                        camera.flashMode = flashMode
                    }
                    camera.unlockForConfiguration()
                }
            }
        }
    }
    
    public func setCamera(position:AVCaptureDevicePosition,torchMode:AVCaptureTorchMode) {
        if let camera = getCamera(position) {
            if camera.hasTorch {
                if camera.lockForConfiguration(nil) {
                    if camera.isTorchModeSupported(torchMode) {
                        camera.torchMode = torchMode
                    }
                    camera.unlockForConfiguration()
                }
            }
        }
    }
    public func getCameraFlashMode(position:AVCaptureDevicePosition) -> AVCaptureFlashMode {
        if let camera = getCamera(position) {
            return camera.flashMode
        }
        return .Off
    }
    public func getCameraTorchMode(position:AVCaptureDevicePosition) -> AVCaptureTorchMode {
        if let camera = getCamera(position) {
            return camera.torchMode
        }
        return .Off
    }
    public func setCameraFocusAt(point:CGPoint,focusMode:AVCaptureFocusMode) {
        if let videoInput = videoInput {
            let device = videoInput.device
            if device.focusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                var error:NSError?
                if device.lockForConfiguration(&error) {
                    device.focusPointOfInterest = point
                    device.focusMode = focusMode
                    device.unlockForConfiguration()
                }
            }
        }

    }
    public func setOrientationFrom(deviceOrientation:UIDeviceOrientation) {
        switch (deviceOrientation) {
        case .Portrait:
            _orientation = .Portrait
        case .PortraitUpsideDown:
            
            _orientation = .PortraitUpsideDown

        case .LandscapeLeft:
            _orientation = .LandscapeRight

        case .LandscapeRight:
            _orientation = .LandscapeLeft
        default:
            break
        }
        
    
    }
//MARK : private
    func getCamera(position:AVCaptureDevicePosition) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        
        for device in devices {
            if let device:AVCaptureDevice = device as? AVCaptureDevice {
                if (device.position == position) {
                    return device;
                }
            }
        }
        return nil;
        
    }

    private func connectionWithMediaType(mediaType:String, connections:[AnyObject]!) -> AVCaptureConnection?
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
    
    //MARK: AVCaptureFileOutputRecordingDelepublic gate
    public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        if let delegate = delegate {
            delegate .onIPaAVCamControllerRecordingDidFinish(self, outputFile: outputFileURL, error: error)
        }
    }
}