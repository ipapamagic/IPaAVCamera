//
//  IPaAVCamController.h
//  IPaAVCamController
//
//  Created by IPaPa on 12/7/27.
//  Copyright (c) 2012年 IPaPa. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import UIKit;
@protocol IPaAVCamControllerDelegate;
@interface IPaAVCamController : NSObject
@property (nonatomic,assign) id <IPaAVCamControllerDelegate> delegate;
@property (nonatomic,readonly) NSUInteger cameraCount;
@property (nonatomic,readonly) NSUInteger micCount;
@property (nonatomic,readonly) BOOL isRecording;
-(id)initWithCameraPositoin:(AVCaptureDevicePosition)devicePosition;
//video
- (void) startRecording;
- (void) stopRecording;
//
- (void) captureStillImage;
- (BOOL) toggleCamera;

- (void)setupCaptureStillImage;
- (void)setupRecordVideo;
#pragma mark - Focus

// Perform an auto focus at the specified point. The focus mode will automatically change to locked once the auto focus is complete.
- (void) autoFocusAtPoint:(CGPoint)point;
// Switch to continuous auto focus mode at the specified point
- (void) continuousFocusAtPoint:(CGPoint)point;
#pragma mark - Preview View
- (UIView*) createPreviewViewWithSize:(CGSize)size;
- (void)setPreviewView:(UIView*) view;

#pragma mark - Flash and Torch


/** set device flash mode
 @param position device position ,on ios it could only be AVCaptureDevicePositionFront or AVCaptureDevicePositionBack
 @param flashMode flash mode you want to set
 */
- (void) setDeviceOnPosition:(AVCaptureDevicePosition)position withFlashMode:(AVCaptureFlashMode)flashMode;
/** set back camera flash mode
 @param flashMode flash mode you want to set
*/
-(void) setBackCameraFlashMode:(AVCaptureFlashMode)flashMode;
/** set device torch mode
 @param position device position ,on ios it could only be AVCaptureDevicePositionFront or AVCaptureDevicePositionBack
 @param torchMode torch mode you want to set
 */
- (void) setDeviceOnPosition:(AVCaptureDevicePosition)position withTorchMode:(AVCaptureTorchMode)torchMode;
/** set back camera torch mode
 @param torchMode torch mode you want to set
 */
-(void) setBackCameraTorchMode:(AVCaptureTorchMode)torchMode;
@end


@protocol IPaAVCamControllerDelegate <NSObject>
@optional
-(void) IPaAVCamControllerDeviceConfigurationChanged:(IPaAVCamController *)controller;
-(void) IPaAVCamController:(IPaAVCamController*)controller didFailWithError:(NSError *)error;
-(void) IPaAVCamControllerRecordingDidBegin:(IPaAVCamController*)controller;
-(void) IPaAVCamController:(IPaAVCamController*)controller recordingDidFinishToOutputFileURL:(NSURL*)fileURL error:(NSError*)error;
-(void) IPaAVCamController:(IPaAVCamController*)controller didCaptureImage:(UIImage*)image;

@end