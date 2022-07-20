//
//  BlocklyView.h
//  meeperBot
//
//  Created by Brandon Korth on 2/8/19.
//  Copyright © 2019 Jim Brandon. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "meeperBot-Swift.h"
#import "MeeperBot.h"
#import "BotCommand.h"
#import "MPR10ViewController.h"
#import "MeeperGlobals.h"
@class MPR10ViewController;

NS_ASSUME_NONNULL_BEGIN

@interface BlocklyView : UIViewController

@property (nonatomic, strong) MPR10ViewController *driveScreen;

@property (strong, nonatomic) IBOutlet UIView *mainView;

@property bool stopCode;
-(void) loadUserCode :(NSString*) code;
-(void) setDriveScreen :(MPR10ViewController*) screen;
-(instancetype)initWithDriveScreen:(MPR10ViewController *)driveScreen;
-(void) loadBots;

@end

NS_ASSUME_NONNULL_END
