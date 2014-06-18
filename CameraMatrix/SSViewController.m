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

@property (nonatomic,strong) NSMutableArray *lastLightMatrix;

@property (nonatomic) CGFloat averageAcceleration;

@property (weak, nonatomic) IBOutlet UILabel *brightnessLabel;

@property (weak, nonatomic) IBOutlet UISwitch *imageSwitch;

@property (nonatomic) BOOL peakFlag;

@property (nonatomic) NSOperationQueue *processQueue;

@end

@implementation SSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [SSBrightnessDetector sharedManager];
    
    [self.imageSwitch addTarget:self action:@selector(changedImageShown:) forControlEvents:UIControlEventValueChanged];
    
    self.processQueue = [NSOperationQueue new];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveLightDetected:) name:@"OnReceiveLightDetected" object:nil];
}
- (IBAction)startCapture:(id)sender {
    NSLog(@"starting Capture...");
    [[SSBrightnessDetector sharedManager] start];
}

- (IBAction)stopCapture:(id)sender {
    NSLog(@"stopping Capture...");
    [self.processQueue cancelAllOperations];
    [[SSBrightnessDetector sharedManager] stop];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)changedImageShown:(UISwitch*)theSwitch
{
    [[SSBrightnessDetector sharedManager] shouldUseSlowerSpeed:theSwitch.on];
    if (theSwitch.on) {
        [[SSBrightnessDetector sharedManager] setDelegate:self];
    } else {
        [[SSBrightnessDetector sharedManager] setDelegate:nil];
    }
}

- (void)receiveLightDetected:(id)sender
{
    NSLog(@"--------------------> light detected!");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - SSBrightnessDetectorDelegate
- (void)newDetectedMatrix:(NSMutableArray *)lightMatrix
{
    if ( !self.areViewsSetup ) {
        [self setupViews:lightMatrix];
        self.areViewsSetup = YES;
    }
    NSInteger totalIncreasedValues = 0;
    CGFloat totalAccelerationChange = 0;
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
                totalIncreasedValues = (brightnessAcceleration > 0 && brightnessChange > 0) ? totalIncreasedValues+1 : totalIncreasedValues;
                
                [[self.secondDegreeLightValues objectAtIndex:i] replaceObjectAtIndex:j withObject:@(brightnessAcceleration)];
                totalAccelerationChange += brightnessChange;
                
                if (self.imageSwitch.on) {
                    UIView *thisSector = [viewRow objectAtIndex:j];
                    [thisSector setBackgroundColor:[UIColor colorWithWhite:brightnessAcceleration alpha:1.f]];
                }
            }

        }
        
    }
//    NSLog(@"avg: %f with total: %ld",self.averageAcceleration, totalIncreasedValues);
//    NSInteger totalIncreasedValues = [self.secondDegreeLightValues count] * [[self.secondDegreeLightValues objectAtIndex:0] count];

    self.averageAcceleration = totalAccelerationChange/totalIncreasedValues;
    if (self.averageAcceleration < 1 && self.peakFlag) {
        //hit a peak - possible light detected
        self.brightnessLabel.text = [NSString stringWithFormat:@"light detected!"];
//        [self receiveLightDetected:self];
        
        self.peakFlag = NO;
    } else if (self.averageAcceleration < 1) {
        //just normal
        self.brightnessLabel.text = [NSString stringWithFormat:@""];
        
        self.peakFlag = NO;
    } else {
        self.peakFlag = YES;
    }

    self.lastLightMatrix = lightMatrix;
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
        CGFloat yPos = 100;
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


@end
