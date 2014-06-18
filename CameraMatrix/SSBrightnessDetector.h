//
//  SSBrightnessDetector.h
//  Morse Torch
//
//  Created by Stevenson on 1/24/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//
//
// Rewritten by Steven Stevenson, but original concept by CFMagicEvents
//
//

#import <Foundation/Foundation.h>
@protocol SSBrightnessDetectorDelegate

- (void)newDetectedMatrix:(NSMutableArray*)lightMatrix;

@end

@interface SSBrightnessDetector : NSObject

//shared Manager for this singleton
+(SSBrightnessDetector*) sharedManager;

@property (unsafe_unretained) id<SSBrightnessDetectorDelegate> delegate;

-(BOOL)start;
-(BOOL)stop;
-(BOOL)isReceiving;

-(void)shouldUseSlowerSpeed:(BOOL)slowerSpeed;

@end
