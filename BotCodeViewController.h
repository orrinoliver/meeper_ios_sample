//
//  BotCodeViewController.h
//  meeperBot
//
//  Created by Jim Brandon on 12/26/16.
//  Copyright © 2016 Jim Brandon. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BotCodeOutputView.h"
#import "MPR10ViewController.h"
#import "TronView.h"
@class MPR10ViewController;
@interface BotCodeViewController : UIViewController<UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, CloseView>

@property (nonatomic, strong) MPR10ViewController *driveScreen;

@property NSMutableArray *virtualBots;
@property NSMutableArray *circuits;
@property NSMutableArray *motors;
@property NSMutableArray *boards;
@property (nonatomic,strong) IBOutlet UICollectionView *defaultBots;

@property NSMutableArray *dstData;
@property (nonatomic,strong) IBOutlet UITableView *dstTableView;

@property NSMutableArray *routineData;
@property (nonatomic,strong) IBOutlet UITableView *routineTableView;

@property NSMutableArray *commandButtons;
@property NSMutableArray *commandButtonsV2;
@property (nonatomic,strong) IBOutlet UICollectionView  *commandView;

@property (nonatomic,strong) IBOutlet TronView *tronView;
@property (nonatomic,strong) IBOutlet UIView *tronViewContainer;

-(void) toggleTron;

@property (nonatomic,strong) IBOutlet UIView* topView;

@property (nonatomic,strong) IBOutlet UIButton *startButton;
@property (nonatomic,strong) IBOutlet UIButton *stopButton;

@property (nonatomic,strong) IBOutlet UIView *cloudLoadLayout;
@property (nonatomic,strong) IBOutlet UITextField *cloudLoadTextField;

@property (nonatomic,strong) IBOutlet UIView *reassginLayout;

-(void)didEditTextField :(NSString*) duration :(long) tag;
-(void)newSpeedSelected :(NSString*) speed :(long) tag : (UIImage*) image;
-(void)newComment :(NSString*) speed :(long) tag;
-(void)changedBots :(NSString*) botCount :(long) tag;
-(IBAction) clearCode;

@property (nonatomic,strong) IBOutlet UILabel *defaultBotLabel;

@property (nonatomic, copy) NSString* selectedCellText;

-(IBAction) runCommands;
-(IBAction) stopExecution;
-(IBAction) loopCommands;

-(void) showBotSelector :(long) tag;
-(void) showPickView :(id) sender :(long) tag;
-(void) saveRoutine :(NSString*) name :(NSMutableArray*) cloudData;
-(void) saveToCloud :(NSString*) code;
-(void) deleteRoutine :(NSString*) name;
-(void) renameRoutine :(NSString*) newName :(NSString*) oldName;
-(void) controllerLoad:(NSString*)code;
-(IBAction)closeFlyOutView;
-(instancetype)initWithDriveScreen:(MPR10ViewController *)driveScreen;
-(void) setBots;
-(void) removeBot: (MeeperBot*) removeBot;

@end
