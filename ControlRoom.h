//
//  ControlRoom.h
//  meeperBot
//
//  Created by Orrin Oliver on 5/4/20.
//  Copyright © 2020 Jim Brandon. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MPR10ViewController.h"
#import "BotCodeViewController.h"
@class MPR10ViewController;
@class BotCodeViewController;
@class ComicLaunchViewController;

NS_ASSUME_NONNULL_BEGIN

@interface ControlRoom : UIViewController

-(IBAction)closeFlyOutView;
-(void) kickedFromRoom;
@property (nonatomic, strong) MPR10ViewController *drivingScreen;
@property (nonatomic, strong) BotCodeViewController *botCodeVC;
@property (nonatomic, strong) ComicLaunchViewController *comicVC;
-(instancetype)initWithDriveScreen:(MPR10ViewController *)driveScreen;
@end

NS_ASSUME_NONNULL_END
