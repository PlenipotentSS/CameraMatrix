//
//  SSBrightnessDetector.m
//  Morse Torch
//
//  Created by Stevenson on 1/24/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//
//
// Rewritten by Steven Stevenson, but original concept by CFMagicEvents
//
//

#import "SSBrightnessDetector.h"
#import <AVFoundation/AVFoundation.h>

#define NORMALIZE_MAX 25
#define BRIGHTNESS_THRESHOLD 115
#define MIN_BRIGHTNESS_THRESHOLD 95

#define LOW_LIGHT_CONDITIONS_MAX 
#define AVG_LIGHT_CONDITIONS_MAX
#define HIGH_LIGHT_CONDITIONS_MAX

@interface SSBrightnessDetector() <AVCaptureAudioDataOutputSampleBufferDelegate>

//session to capture brightness
@property (nonatomic) AVCaptureSession *captureSession;

//bool containing session hasStarted
@property (nonatomic) BOOL hasStarted;

//the matrix of brightness RGB values in the given camera view
@property (nonatomic) NSMutableArray *brightnessMatrix;

@property (nonatomic) int currentSpeed;

@end

@implementation SSBrightnessDetector

+(SSBrightnessDetector*) sharedManager {
    static dispatch_once_t pred;
    static SSBrightnessDetector *shared;
    
    dispatch_once(&pred, ^{
        shared = [[SSBrightnessDetector alloc] init];
        if (!shared.brightnessMatrix) {
            [shared setup];
        }
    });
    return shared;
}

- (void)setup
{
    self.hasStarted = NO;
    [NSThread detachNewThreadSelector:@selector(initCapture) toTarget:self withObject:nil];
}

- (void)initCapture {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSError *error = nil;
    
    AVCaptureDevice *captureDevice = [self getBackCamera];
//    [self configureCameraForHighestFrameRate:captureDevice];
    if ([captureDevice isExposureModeSupported:AVCaptureExposureModeLocked]) {
        [captureDevice lockForConfiguration:nil];
        [captureDevice setExposureMode:AVCaptureExposureModeLocked];
        [captureDevice unlockForConfiguration];
    } else {
        NSLog(@"device doesn't support exposure lock");
    }
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if ( ! videoInput)
    {
        NSLog(@"Could not get video input: %@", error);
        return;
    }
    //  the capture session is where all of the inputs and outputs tie together.
    _captureSession = [[AVCaptureSession alloc] init];
    
    //  sessionPreset governs the quality of the capture. we don't need high-resolution images,
    //  so we'll set the session preset to low quality.
    
    _captureSession.sessionPreset = AVCaptureSessionPresetLow;
    
    [_captureSession addInput:videoInput];
    
    //  create the thing which captures the output
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    //  pixel buffer format
    // YUV (iOS 7 Chroma/Luminance standard) --- NOT INCLUDED
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
                              kCVPixelBufferPixelFormatTypeKey, nil];
    videoDataOutput.videoSettings = settings;
    [settings release];
    
    //  we need a serial queue for the video capture delegate callback
    dispatch_queue_t queue = dispatch_queue_create("com.zuckerbreizh.cf", NULL);

    [videoDataOutput setSampleBufferDelegate:(id)self queue:queue];
    [_captureSession addOutput:videoDataOutput];
    [videoDataOutput release];
    
    dispatch_release(queue);
    [pool release];
    
}

-(BOOL)start
{
    if(!self.hasStarted){
        [self.captureSession startRunning];
        self.hasStarted = YES;
    }
    return self.hasStarted;
}

-(BOOL)isReceiving {
    return self.hasStarted;
}

-(BOOL)stop
{
    if(self.hasStarted){
        [self.captureSession stopRunning];
        self.hasStarted = NO;
    }
    return self.hasStarted;
}


- (AVCaptureDevice *)getBackCamera
{
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionBack)
        {
            return device;
        }
    }
    return nil;
}

-(void)shouldUseSlowerSpeed:(BOOL)slowerSpeed
{
    if (slowerSpeed) {
        self.currentSpeed = 500000;
    } else {
        self.currentSpeed = 10000;
    }
}

#pragma mark - AVCaptureAudioDataOutputSampleBuffer getBrightness and send Notification (hybridized)
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess)
    {
        
        self.brightnessMatrix = [[NSMutableArray alloc] init];
        UInt8 *base = (UInt8 *)CVPixelBufferGetBaseAddress(imageBuffer);
        
        //  calculate average brightness in a simple way
        
        size_t bytesPerRow      = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width            = CVPixelBufferGetWidth(imageBuffer);
        size_t height           = CVPixelBufferGetHeight(imageBuffer);
        
        int counter_row=0;
        BOOL firstRun = NO;
        
        if ([self.brightnessMatrix count] == 0) {
            firstRun = YES;
        }
        
        for (UInt8 *rowStart = base; counter_row < height; rowStart += bytesPerRow, counter_row++){
            
            //get last brightness at row if possible
            NSMutableArray *row;
            row = [NSMutableArray new];
            
            //cycle through columns at row
            int counter_column = 0;
            for (UInt8 *p = rowStart; counter_column<width; p += 4, counter_column++){
                Float32 thisBrightness = (.299*p[0] + .587*p[1] + .116*p[2]);
                [row addObject:@(thisBrightness)];
            }
            [self.brightnessMatrix insertObject:row atIndex:counter_row];
            //put row values intro matrix
        }
        if (self.delegate) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self.delegate newDetectedMatrix:self.brightnessMatrix];
            }];
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        usleep(self.currentSpeed);
    }
}

#pragma mark -John Clem amazingness
- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
            device.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration;
            [device unlockForConfiguration];
        }
    }
}
@end
