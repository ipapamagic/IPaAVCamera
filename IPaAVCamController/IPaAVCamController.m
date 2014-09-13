//
//  IPaAVCamController.m
//  IPaAVCamController
//
//  Created by IPaPa on 12/7/27.
//  Copyright (c) 2012年 IPaPa. All rights reserved.
//

#import "IPaAVCamController.h"
#import <AssetsLibrary/AssetsLibrary.h>


@interface IPaAVCamController () <AVCaptureFileOutputRecordingDelegate>
@property (nonatomic,readonly) AVCaptureDevice* frontFacingCamera;
@property (nonatomic,readonly) AVCaptureDevice* backFacingCamera;
@property (nonatomic,readonly) AVCaptureDevice* audioDevice;
@end
@implementation IPaAVCamController
{
    AVCaptureSession *session;
    AVCaptureVideoOrientation orientation;
    AVCaptureDeviceInput *videoInput;
    AVCaptureVideoPreviewLayer *previewLayer;
    //still image
    AVCaptureStillImageOutput *stillImageOutput;
    //video record
    AVCaptureDeviceInput *audioInput;
    AVCaptureMovieFileOutput *movieFileOutput;
    NSURL *outputFileURL;
    
    UIBackgroundTaskIdentifier backgroundRecordingID;

}

-(id)init
{
    self = [super init];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(onDeviceConnected:) name:AVCaptureDeviceWasConnectedNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(onDeviceDisconnected:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [notificationCenter addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    orientation = AVCaptureVideoOrientationPortrait;
    
    session = [[AVCaptureSession alloc] init];
    
    return self;
}
-(id)initWithCameraPositoin:(AVCaptureDevicePosition)devicePosition
{
    self = [self init];
    NSError *error;
    videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self cameraWithPosition:devicePosition] error:&error];
    if (error != nil) {
        if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:didFailWithError:)])
        {
            NSString *localizedDescription = @"Video Input init error";
            NSString *localizedFailureReason = @"Can not initial video input.";
            NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                       localizedDescription, NSLocalizedDescriptionKey,
                                       localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                       nil];
            NSError *noVideoError = [NSError errorWithDomain:@"AVCam" code:0 userInfo:errorDict];
            
            [self.delegate onIPaAVCamController:self didFailWithError:noVideoError];
        }
    }
    if([session canAddInput:videoInput]){
        [session addInput:videoInput];
    }
    return self;
}
- (void)setPreviewLayerConnectionEnable:(BOOL)enable
{
    previewLayer.connection.enabled = enable;
    
}
- (void)setPreviewView:(UIView*) view
{
    if (previewLayer) {
        [previewLayer removeFromSuperlayer];
    }
    else {
        previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];        
    }

    CALayer *viewLayer = [view layer];
    [viewLayer setMasksToBounds:YES];
    
    CGRect bounds = [view bounds];
    [previewLayer setFrame:bounds];

    
//    if (videoConnection.supportsVideoOrientation) {
//        videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
//    }
//    
//    if ([previewLayer isOrientationSupported]) {
//        [previewLayer setOrientation:AVCaptureVideoOrientationPortrait];
//    }
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    [viewLayer insertSublayer:previewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
    

}
- (UIView*) createPreviewViewWithSize:(CGSize)size;
{
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    
    [self setPreviewView:view];
    
    return view;
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [session stopRunning];
    videoInput = nil;
    audioInput = nil;
    stillImageOutput = nil;

}
- (void)setupCaptureStillImage
{
    [session stopRunning];
    if (movieFileOutput) {
        [session removeOutput:movieFileOutput];
       // movieFileOutput = nil;
    }
    if (audioInput) {
        [session removeInput:audioInput];
       // audioInput = nil;
    }
    if (videoInput == nil) {
        videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:nil];
        if ([session canAddInput:videoInput]) {
            [session addInput:videoInput];
        }
    }
    if (stillImageOutput == nil) {
        stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        AVVideoCodecJPEG, AVVideoCodecKey,
                                        nil];
        [stillImageOutput setOutputSettings:outputSettings];
    }
    if ([session canAddOutput:stillImageOutput]) {
        [session addOutput:stillImageOutput];
    }
    [session startRunning];
}
- (void)setupRecordVideo
{
    [session stopRunning];
    if (movieFileOutput == nil) {
        movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    }
    if ([session canAddOutput:movieFileOutput])
    {
        [session addOutput:movieFileOutput];
    }
    if (audioInput == nil) {
        audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    }
    if ([session canAddInput:audioInput]) {
        [session addInput:audioInput];
    }
    if (outputFileURL == nil) {
        // Set up the movie file output
        outputFileURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@output.mov", NSTemporaryDirectory()]];
    }
    
    AVCaptureConnection *videoConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[movieFileOutput connections]];
    AVCaptureConnection *audioConnection = [self connectionWithMediaType:AVMediaTypeAudio fromConnections:[movieFileOutput connections]];
    
    
    
    
	// Send an error to the delegate if video recording is unavailable
	if (![videoConnection isActive] && [audioConnection isActive]) {
        if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:didFailWithError:)])
        {
            NSString *localizedDescription = @"Video recording unavailable";
            NSString *localizedFailureReason = @"Movies recorded on this device will only contain audio. They will be accessible through iTunes file sharing.";
            NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                       localizedDescription, NSLocalizedDescriptionKey,
                                       localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                       nil];
            NSError *noVideoError = [NSError errorWithDomain:@"AVCam" code:0 userInfo:errorDict];
            
            [self.delegate onIPaAVCamController:self didFailWithError:noVideoError];
        }
	}
    //start running
    [session startRunning];
}

- (void) startRecording
{
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns
		// to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library
		// when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error:
		// after the recorded file has been saved.
        backgroundRecordingID =[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}];

    }
    NSString *filePath = [outputFileURL path];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:filePath error:&error] == NO) {
            if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:didFailWithError:)]) {
                [self.delegate onIPaAVCamController:self didFailWithError:error];
            }
        }
    }
    AVCaptureConnection *videoConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[movieFileOutput connections]];
    if ([videoConnection isVideoOrientationSupported])
        [videoConnection setVideoOrientation:orientation];
    
    [movieFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];

}

- (void) stopRecording
{
    [movieFileOutput stopRecording];
}

- (void) captureStillImage
{
    AVCaptureConnection *stillImageConnection = [self connectionWithMediaType:AVMediaTypeVideo fromConnections:[stillImageOutput connections]];
    if ([stillImageConnection isVideoOrientationSupported])
        [stillImageConnection setVideoOrientation:orientation];
    
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            if (imageDataSampleBuffer != NULL) {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:didCaptureImage:)]) {
                    [self.delegate onIPaAVCamController:self didCaptureImage:image];
                }
            }
    }];
}

// Toggle between the front and back camera, if both are present.
- (BOOL) toggleCamera {

    
    if (self.cameraCount > 1) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition position = [[videoInput device] position];
        
        if (position == AVCaptureDevicePositionBack) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.frontFacingCamera error:&error];
        }
        else if (position == AVCaptureDevicePositionFront) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.backFacingCamera error:&error];
        }
        else {
            return NO;
        }
        
        if (newVideoInput != nil) {
            [session beginConfiguration];

            if ([session canAddInput:newVideoInput]) {
                [session removeInput:videoInput];
                [session addInput:newVideoInput];
                videoInput = newVideoInput;
            }
            [session commitConfiguration];

        } else if (error) {
            if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:didFailWithError:)]) {
                [self.delegate onIPaAVCamController:self didFailWithError:error];
            }
        }
    }
    return YES;
    
}


#pragma mark Device Counts

- (NSUInteger) cameraCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (NSUInteger) micCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] count];
}


#pragma mark Camera Properties

- (void) setDeviceOnPosition:(AVCaptureDevicePosition)position withFlashMode:(AVCaptureFlashMode)flashMode
{
    AVCaptureDevice *camera = [self cameraWithPosition:position];
    if ([camera hasFlash]) {
        if ([camera lockForConfiguration:nil]) {
            if ([camera isFlashModeSupported:flashMode]) {
                [camera setFlashMode:flashMode];
            }
            [camera unlockForConfiguration];
        }
    }
}
-(void) setBackCameraFlashMode:(AVCaptureFlashMode)flashMode
{
    [self setDeviceOnPosition:AVCaptureDevicePositionBack withFlashMode:flashMode];
}
- (void) setDeviceOnPosition:(AVCaptureDevicePosition)position withTorchMode:(AVCaptureTorchMode)torchMode
{
    AVCaptureDevice *camera = [self cameraWithPosition:position];
    if ([camera hasTorch]) {
        if ([camera lockForConfiguration:nil]) {
            if ([camera isTorchModeSupported:AVCaptureTorchModeAuto]) {
                [camera setTorchMode:AVCaptureTorchModeAuto];
            }
            [camera unlockForConfiguration];
        }
    }
}

-(void) setBackCameraTorchMode:(AVCaptureTorchMode)torchMode
{
    [self setDeviceOnPosition:AVCaptureDevicePositionBack withTorchMode:torchMode];
}
- (void) autoFocusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = [videoInput device];
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:didFailWithError:)]) {
                [self.delegate onIPaAVCamController:self didFailWithError:error];
            }
        }
    }
}


- (void) continuousFocusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = [videoInput device];
	
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
		NSError *error;
		if ([device lockForConfiguration:&error]) {
			[device setFocusPointOfInterest:point];
			[device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
			[device unlockForConfiguration];
		} else {
			if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:didFailWithError:)]) {
                [self.delegate onIPaAVCamController:self didFailWithError:error];
            }
		}
	}
}
-(BOOL)isRecording
{
    return [movieFileOutput isRecording];
}
#pragma mark - InternalMethods
// Find a camera with the specificed AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}
// Find a front facing camera, returning nil if one is not found
- (AVCaptureDevice *) frontFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

// Find a back facing camera, returning nil if one is not found
- (AVCaptureDevice *) backFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

// Find and return an audio device, returning nil if one is not found
- (AVCaptureDevice *) audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0) {
        return [devices objectAtIndex:0];
    }
    return nil;
}

- (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
	return nil;
}

#pragma mark - Notification
-(void)onDeviceConnected:(NSNotification*)noti
{
    AVCaptureDevice *device = [noti object];
    
    BOOL sessionHasDeviceWithMatchingMediaType = NO;
    NSString *deviceMediaType = nil;
    if ([device hasMediaType:AVMediaTypeAudio])
        deviceMediaType = AVMediaTypeAudio;
    else if ([device hasMediaType:AVMediaTypeVideo])
        deviceMediaType = AVMediaTypeVideo;
    
    if (deviceMediaType != nil) {
        for (AVCaptureDeviceInput *input in [session inputs])
        {
            if ([[input device] hasMediaType:deviceMediaType]) {
                sessionHasDeviceWithMatchingMediaType = YES;
                break;
            }
        }
        
        if (!sessionHasDeviceWithMatchingMediaType) {
            NSError	*error;
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
            if ([session canAddInput:input])
                [session addInput:input];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(onIPaAVCamControllerDeviceConfigurationChanged:)]) {
        [self.delegate onIPaAVCamControllerDeviceConfigurationChanged:self];
    }
}
-(void)onDeviceDisconnected:(NSNotification*)noti
{
    AVCaptureDevice *device = [noti object];
    
    if ([device hasMediaType:AVMediaTypeAudio]) {
        [session removeInput: audioInput];
        audioInput = nil;
    }
    else if ([device hasMediaType:AVMediaTypeVideo]) {
        [session removeInput:videoInput];
        videoInput = nil;
    }
    
    if ([self.delegate respondsToSelector:@selector(onIPaAVCamControllerDeviceConfigurationChanged:)]) {
        [self.delegate onIPaAVCamControllerDeviceConfigurationChanged:self];
    }
}

// Keep track of current device orientation so it can be applied to movie recordings and still image captures
- (void)deviceOrientationDidChange:(NSNotification*)noti
{
	UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    
	if (deviceOrientation == UIDeviceOrientationPortrait)
		orientation = AVCaptureVideoOrientationPortrait;
	else if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown)
		orientation = AVCaptureVideoOrientationPortraitUpsideDown;
	
	// AVCapture and UIDevice have opposite meanings for landscape left and right (AVCapture orientation is the same as UIInterfaceOrientation)
	else if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
		orientation = AVCaptureVideoOrientationLandscapeRight;
	else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
		orientation = AVCaptureVideoOrientationLandscapeLeft;
	
	// Ignore device orientations for which there is no corresponding still image orientation (e.g. UIDeviceOrientationFaceUp)
}

#pragma mark - AVCaptureFileOutputDelegate
- (void)                     captureOutput:(AVCaptureFileOutput *)captureOutput
        didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                           fromConnections:(NSArray *)connections
{
    if ([self.delegate respondsToSelector:@selector(onIPaAVCamControllerRecordingDidBegin:)]) {
        [self.delegate onIPaAVCamControllerRecordingDidBegin:self];
    }
}

- (void)                  captureOutput:(AVCaptureFileOutput *)captureOutput
    didFinishRecordingToOutputFileAtURL:(NSURL *)anOutputFileURL
                        fromConnections:(NSArray *)connections
                                  error:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(onIPaAVCamController:recordingDidFinishToOutputFileURL:error:)]) {
        [self.delegate onIPaAVCamController:self recordingDidFinishToOutputFileURL:anOutputFileURL error:error];
    }
}
@end
