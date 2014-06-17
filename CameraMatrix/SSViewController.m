//
//  SSViewController.m
//  CameraMatrix
//
//  Created by Stevenson on 6/16/14.
//  Copyright (c) 2014 Steven Stevenson. All rights reserved.
//

#import "SSViewController.h"
#import  "SSBrightnessDetector.h"

@interface SSViewController () <SSBrightnessDetectorDelegate>

@property (nonatomic) NSMutableArray *viewArray;

@property (nonatomic) BOOL areViewsSetup;

//first derivative values of light function
@property (nonatomic) NSMutableArray *firstDegreeLightValues;

//second derivative values of light function
@property (nonatomic) NSMutableArray *secondDegreeLightValues;

@property (nonatomic,weak) NSMutableArray *lastLightMatrix;

@property (nonatomic) CGFloat averageAcceleration;

@end

@implementation SSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [[SSBrightnessDetector sharedManager] setDelegate:self];
    
}
- (IBAction)startCapture:(id)sender {
    [[SSBrightnessDetector sharedManager] start];
}

- (IBAction)stopCapture:(id)sender {
    [[SSBrightnessDetector sharedManager] stop];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)newDetectedMatrix:(NSMutableArray *)lightMatrix
{
    NSLog(@"starting loading");
    
    if ( !self.areViewsSetup) {
        [self setupViews:lightMatrix];
        self.areViewsSetup = YES;
    }
    
    for (NSInteger i = 0; i<[lightMatrix count]; i++) {
        
        NSMutableArray *row = [lightMatrix objectAtIndex:i];
        NSMutableArray *viewRow = [self.viewArray objectAtIndex:i];
        for (NSInteger j = 0; j<[row count]; j++) {
            
            CGFloat thisBrightness = [[row objectAtIndex:j] floatValue];
            if (self.lastLightMatrix) {
                CGFloat lastBrightness = [[[self.lastLightMatrix objectAtIndex:i] objectAtIndex:j] floatValue];
                
                CGFloat brightnessChange = (thisBrightness-lastBrightness);    //change of brightness
                CGFloat oldBrightnessChange = [[[self.firstDegreeLightValues objectAtIndex:i] objectAtIndex:j] floatValue];
                [[self.firstDegreeLightValues objectAtIndex:i] replaceObjectAtIndex:j withObject:@(brightnessChange)];
                
                CGFloat brightnessAcceleration = brightnessChange-oldBrightnessChange;
                [[self.secondDegreeLightValues objectAtIndex:i] replaceObjectAtIndex:j withObject:@(brightnessAcceleration)];
                
                UIView *thisSector = [viewRow objectAtIndex:j];
                [thisSector setBackgroundColor:[UIColor colorWithWhite:brightnessAcceleration alpha:1.f]];
            }

        }
        
    }
    self.lastLightMatrix = lightMatrix;
    NSLog(@"done loading!");
}

- (void)setupViews:(NSMutableArray*)lightMatrix
{
    NSLog(@"setting up views...");
    self.viewArray = [[NSMutableArray alloc] init];
    self.firstDegreeLightValues = [[NSMutableArray alloc] init];
    self.secondDegreeLightValues = [[NSMutableArray alloc] init];
    CGFloat xPos = CGRectGetWidth(self.view.frame)-50;
    for (NSInteger i = 0; i<[lightMatrix count]; i++) {
        if ([self.viewArray count] == i ) {
            [self.viewArray addObject:[NSMutableArray new]];
            [self.firstDegreeLightValues addObject:[NSMutableArray new]];
            [self.secondDegreeLightValues addObject:[NSMutableArray new]];
        }
        
        CGFloat viewHeight = CGRectGetWidth(self.view.frame)/[lightMatrix count];
        CGFloat yPos = 50;
        NSMutableArray *row = [lightMatrix objectAtIndex:i];
        
        CGFloat viewWidth = CGRectGetWidth(self.view.frame)/[row count];
        xPos -= viewWidth;
        
        for (NSInteger j = 0; j<[row count]; j++) {
            UIView *thisSector = [[UIView alloc] initWithFrame:CGRectMake(xPos, yPos, viewWidth, viewHeight)];
            [self.view addSubview:thisSector];
            
            [[self.viewArray objectAtIndex:i] addObject:thisSector];
            [[self.firstDegreeLightValues objectAtIndex:i] addObject:@(0)];
            [[self.secondDegreeLightValues objectAtIndex:i] addObject:@(0)];
            
            yPos += viewWidth;
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
