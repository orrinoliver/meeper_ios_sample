//
//  ControlRoom.m
//  meeperBot
//
//  Created by Orrin Oliver on 5/4/20.
//  Copyright © 2020 Jim Brandon. All rights reserved.
//

#import "ControlRoom.h"
#import "BotCommand.h"
#import "MeeperGlobals.h"
#import "BotCodeViewController.h"
#import "ComicLaunchViewController.h"
#import "BlocklyView.h"
#import "ActivityLaunchViewController.h"
#import "NewsLaunchViewController.h"
#import "userCell.h"
#import "Reachability.h"
@import Firebase;
@import FirebaseDatabase;

@interface ControlRoom()

//master controller
@property (nonatomic,strong) IBOutlet UIView *controllerMainView;
@property (nonatomic,strong) IBOutlet UIView *hostView;
@property (nonatomic,strong) IBOutlet UIView *joinView;
@property (nonatomic,strong) IBOutlet UIView *joinedView;
@property (nonatomic,strong) IBOutlet UILabel *joinedText;
@property (nonatomic,strong) IBOutlet UILabel *hostText;
@property (nonatomic,strong) IBOutlet UILabel *headerText;
@property (nonatomic,strong) IBOutlet UITextField *joinInput;
@property (nonatomic,strong) IBOutlet UITextField *joinNameInput;
@property (strong, nonatomic) FIRDatabaseReference *ref;
@property (nonatomic, strong) FIRDatabaseReference *userListener;
@property (strong, nonatomic) UIView *userListView;
@property (strong, nonatomic) IBOutlet UIImageView *userListImage;

@property (strong, nonatomic) UIView *flyOutView;
@property BOOL flyOutViewIsOpen;

@property NSMutableArray *userList;
@property (strong, nonatomic) UITableView *userListTable;
@property (nonatomic,strong) IBOutlet UILabel *hostCodeLabel;
@property (nonatomic,strong) IBOutlet UILabel *noUserLabel;

@end

@implementation ControlRoom

-(instancetype)initWithDriveScreen:(MPR10ViewController *)driveScreen{
    self = [super init];
    if(self)
    {
        self.drivingScreen = driveScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    _userList = [[NSMutableArray alloc] init];
    
    _ref = [[FIRDatabase database] reference];
    if(_drivingScreen.hostCode != NULL){
        _userListImage.hidden = false;
        _hostView.hidden = false;
        _hostText.text = [NSString stringWithFormat: @"Congratulations! You have set up Control Room %@.", _drivingScreen.hostCode];
        _headerText.text = @"CONTROL ROOM";
    }else if(_drivingScreen.joinCode != NULL){
        [_drivingScreen showSpeedView:false];
        _joinedView.hidden = false;
        _joinedText.text = [NSString stringWithFormat:@"Welcome to Control Room %@!", self->_drivingScreen.joinCode];
        _headerText.text = @"CONTROL ROOM";
     }else{
         _userListImage.hidden = true;
        _controllerMainView.hidden = false;
        _headerText.text = @"CONTROL CENTER";
     }
    
    _joinInput.delegate = self;
    _joinNameInput.delegate = self;
    
    if ([_joinInput respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:@"#85D5F7"];
        [scanner setScanLocation:1]; // bypass '#' character
        [scanner scanHexInt:&rgbValue];
        UIColor *color = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
        _joinInput.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"CODE" attributes:@{NSForegroundColorAttributeName: color}];
    } else {
        NSLog(@"Cannot set placeholder text's color, because deployment target is earlier than iOS 6.0");
        // TODO: Add fall-back code to set placeholder color.
    }
    
    if ([_joinNameInput respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:@"#85D5F7"];
        [scanner setScanLocation:1]; // bypass '#' character
        [scanner scanHexInt:&rgbValue];
        UIColor *color = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
        _joinNameInput.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"NAME" attributes:@{NSForegroundColorAttributeName: color}];
    } else {
        NSLog(@"Cannot set placeholder text's color, because deployment target is earlier than iOS 6.0");
        // TODO: Add fall-back code to set placeholder color.
    }
}

-(IBAction)hostRoom{
    
    if([self connected]){
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd-MMM-yyyy"];
        
        //_ref = [[FIRDatabase database] reference];
        NSString *code = [self generateRandomString];
        //create room
        [[[[_ref child:@"ControllerV2"] child:code] child:@"codeInfo"] setValue:@{@"code" : code, @"id" : [[NSUUID UUID] UUIDString], @"info": @"", @"mode": @"manual", @"date" : [dateFormatter stringFromDate:[NSDate date]]}
         withCompletionBlock:^(NSError *error, FIRDatabaseReference *ref) {
          if (error) {
              NSString *message = @"An error occured while trying to create a room.  Please try again later.";
              UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
              [alert show];
          } else {
              
              NSString *botList = @"";
              
              for(MeeperBot *bot in self->_drivingScreen.items){
                  botList = [NSString stringWithFormat: @"%@%@%@\%%meep%%%@@meep@", botList,bot.prefix,bot.name,bot.UUID];
              }
              
              for(MeeperBot *bot in self->_drivingScreen.connectedCircuits){
                  botList = [NSString stringWithFormat: @"%@%@%@\%%meep%%%@@meep@", botList,bot.prefix,bot.name,bot.UUID];
              }
              
              [[[[_ref child:@"ControllerV2"] child:code] child:@"botInfo"] setValue:botList];
              
              self->_userListImage.hidden = false;
              self->_controllerMainView.hidden = true;
              self->_hostText.text = [NSString stringWithFormat: @"Congratulations! You have set up Control Room %@.", code];
              _headerText.text = @"CONTROL ROOM";
              self->_drivingScreen.hostCode = code;
              self->_hostView.hidden = false;
              [self->_drivingScreen createHostListener];
          }
        }];
        
    }else{
        NSString *message = @"An internet connection is required to use the Control Room.";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Internet" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }
}

-(IBAction)closeRoom{
    
    [_drivingScreen removeHostListener];
    [[[_ref child:@"ControllerV2"] child:_drivingScreen.hostCode] removeValue];
    
    _drivingScreen.hostCode = NULL;
    _userListImage.hidden = true;
    _hostView.hidden = true;
    _controllerMainView.hidden = false;
    _headerText.text = @"CONTROL CENTER";
}

-(IBAction)joinRoom{
    _controllerMainView.hidden = true;
    _joinInput.text = @"";
    _joinView.hidden = false;
}

-(IBAction)searchForRoom{
    if([self connected]){
        if(_joinNameInput.text.length <= 0){
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Please enter name" message:@"Please enter a name that the host will be able to easily recognize you with." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
        }else{
            FIRDatabaseReference *overviewRef = [_ref child:@"ControllerV2"];
            
            [overviewRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
                NSDictionary *postDict = snapshot.value;
                
                bool foundCode = false;
                for (NSString *key in postDict) {
                    NSLog(@"key: %@", key);
                    //key should be room code
                    if([[key uppercaseString] isEqualToString:[self->_joinInput.text uppercaseString]]){
                        foundCode = true;
                    }
                    /*NSDictionary *value = postDict[key];
                    [blocklyList addObject:value];
                    for(NSString *Itemp in value){
                        id value2 = value[Itemp];
                        if([[Itemp uppercaseString] isEqualToString:@"CODE"]){
                            if([[value2 uppercaseString] isEqualToString:[self->_joinInput.text uppercaseString]]){
                                foundCode = true;
                                break;
                            }
                        }
                    }*/
                }
                
                if(foundCode){
                    NSString *botInfoList = @"";
                    for (NSString *key in postDict) {
                        if([[key uppercaseString] isEqualToString:[self->_joinInput.text uppercaseString]]){
                            NSLog(@"key: %@", key);
                            NSDictionary *value = postDict[key];
                            for(NSString *Itemp in value){
                                if([Itemp isEqualToString:@"botInfo"]){
                                    botInfoList = value[Itemp];
                                }
                            }
                        }
                    }
                    
                    /*if(![botInfoList isEqual: @""]){
                        _drivingScreen.sharedBots = [[NSMutableArray alloc] init];
                        _drivingScreen.sharedCircuits = [[NSMutableArray alloc] init];
                        
                        NSArray *botList = [botInfoList componentsSeparatedByString:@"@meep@"];
                        if(botList.count >0){
                            for(int i = 0; i < botList.count; i++){
                                MeeperBot *bots = [[MeeperBot alloc] init];
                                bots.isSharedBot = true;
                                NSArray *botInfo = [botList[i] componentsSeparatedByString:@"%meep%"];
                                NSLog(@"botinfo count: %lu, botinfo: %@", (unsigned long)botInfo.count, botInfo);
                                if(botInfo.count > 1){
                                    bots.prefix = [botInfo[0] substringToIndex:3];
                                    bots.name = [botInfo[0] substringFromIndex:3];
                                    bots.UUID = botInfo[1];
                                    if([[bots.prefix uppercaseString] isEqualToString:@"MCC"]){
                                        bots.botIcon = [UIImage imageNamed:@"shared_circuit_icon"];
                                        bots.iconKey = @"sharedCircuit";
                                        [self->_drivingScreen.sharedCircuits addObject:bots];
                                    }else{
                                        bots.botIcon = [UIImage imageNamed:@"shared_bot_icon"];
                                        bots.iconKey = @"sharedBot";
                                        [self->_drivingScreen.sharedBots addObject:bots];
                                    }
                                }
                            }
                        } 
                    }*/
            
                    NSString *id = [[NSUUID UUID] UUIDString];
                    
                    [[[[[self->_ref child:@"ControllerV2"] child:[self->_joinInput.text uppercaseString]] child:@"people"] child:id] setValue:@{@"id" : id, @"name": self->_joinNameInput.text, @"isActive": @"false"}];
                    
                    [self->_joinInput resignFirstResponder];
                    [self->_joinNameInput resignFirstResponder];
                    self->_drivingScreen.userId = id;
                    self->_drivingScreen.joinCode = [self->_joinInput.text uppercaseString];
                    self->_joinView.hidden = true;
                    self->_headerText.text = @"CONTROL ROOM";
                    self->_joinedText.text = [NSString stringWithFormat:@"Welcome to Control Room %@!", self->_drivingScreen.joinCode];
                    self->_joinedView.hidden = false;
                    [self->_drivingScreen createJoinListener:id];
                    [self->_drivingScreen showSpeedView:false];
                    [self->_drivingScreen.botView reloadData];
                }else{
                    NSString *message = [NSString stringWithFormat:@"Control Room with code %@ could not be found. Please check with your friend or teacher to ensure it is set up.", self->_joinInput.text];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Control Room Not Found" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                    [alert show];
                }
                [overviewRef removeAllObservers];
            }];
        }
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Internet" message:@"An internet connection is required to use the Control Room." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }
}

-(IBAction)leaveRoom{
    if(_drivingScreen.userId != NULL && _drivingScreen.joinCode != NULL){
        [[[[[_ref child:@"ControllerV2"] child:_drivingScreen.joinCode] child:@"people"] child:_drivingScreen.userId] removeValue];
    }
    _drivingScreen.joinCode = NULL;
    _joinedView.hidden = true;
    _controllerMainView.hidden = false;
    _headerText.text = @"CONTROL CENTER";
    NSLog(@"code: %@, userId: %@", _drivingScreen.joinCode, _drivingScreen.userId);
    
    [_drivingScreen removeJoinListener];
    [_drivingScreen showSpeedView:true];
}

-(IBAction)closeJoin{
    _joinView.hidden = true;
    _joinInput.text = @"";
    _controllerMainView.hidden = false;
    _headerText.text = @"CONTROL CENTER";
    [_joinInput resignFirstResponder];
    [_joinNameInput resignFirstResponder];
}

-(IBAction)showDrivingScreen{
    [_drivingScreen showDriveView];
}

- (BOOL)connected
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    return networkStatus != NotReachable;
}

-(NSString*) generateRandomString{
    //snorlax
    NSString *data = @"23456789ABCDEFGHJKMNPQRSTUVWXYZ";
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity: 4];
    
    for (int i=0; i<4; i++) {
        [randomString appendFormat: @"%C", [data characterAtIndex: arc4random_uniform([data length])]];
    }
    
    FIRDatabaseReference *overviewRef = [_ref child:@"ControllerV2"];
    
    NSMutableArray *controllerList = [[NSMutableArray alloc] init];
    
    [overviewRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        NSDictionary *postDict = snapshot.value;
        
        bool foundCode = false;
        for (NSString *key in postDict) {
            NSDictionary *value = postDict[key];
            [controllerList addObject:value];
            for(NSString *Itemp in value){
                id value2 = value[Itemp];
                if([[Itemp uppercaseString] isEqualToString:@"CODE"]){
                    if([[value2 uppercaseString] isEqualToString:[randomString uppercaseString]]){
                        foundCode = true;
                        break;
                    }
                }
            }
            if(foundCode){
                break;
            }
        }
        
        if(foundCode){
            NSString *newString = [self generateRandomString];
            
            [randomString deleteCharactersInRange:NSMakeRange(0,3)];
            [randomString appendString:newString];
        }
    }];
    
    [overviewRef removeAllObservers];
    
    return randomString;
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

-(IBAction) showFlyOutView
{
    if(!_flyOutViewIsOpen)
    {
        _flyOutViewIsOpen = YES;
        
        _flyOutView = [[[NSBundle mainBundle]
                        loadNibNamed:@"FlyOutView"
                        owner:self options:nil]
                       firstObject];
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        _flyOutView.frame = CGRectMake(screenWidth *-1,0,screenWidth,screenHeight);
        
        [self.view addSubview:_flyOutView];
        
        
        [UIView animateWithDuration:1.0 animations:^{
            
            self->_flyOutView.frame = CGRectMake(0, 0, screenWidth, screenHeight);
        }
                         completion:^(BOOL finished) {
                             
                         }];
    }
    
}

-(IBAction) closeFlyOutView
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenHeight = screenRect.size.height;
    CGFloat screenWidth = screenRect.size.width;
    [UIView animateWithDuration:1.0 animations:^{
        self->_flyOutView.frame = CGRectMake(screenWidth *-1, 0, screenWidth, screenHeight);
    } completion:^(BOOL finished) {
        [self->_flyOutView removeFromSuperview];
        self->_flyOutViewIsOpen = NO;
        self->_flyOutView = nil;
    }];
}

-(IBAction) showControllerView{
    [self closeFlyOutView];
}

-(IBAction) showActivitiesView
{
    [self dismissViewControllerAnimated:NO completion:^{
        [self closeFlyOutView];
        
        ActivityLaunchViewController *vc;
        
        CGRect frame = self->_drivingScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[ActivityLaunchViewController alloc] initWithDriveScreen:_drivingScreen];
        
        vc.view.frame = frame;
        vc.drivingScreen = self->_drivingScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_drivingScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_drivingScreen presentViewController:vc animated:NO completion:nil];
    }];
}

-(IBAction)showComicView{
    
    [self closeFlyOutView];
    [self dismissViewControllerAnimated:NO completion:^{
        ComicLaunchViewController *vc;
        
        CGRect frame = self.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[ComicLaunchViewController alloc] initWithDriveScreen:_drivingScreen];
        
        vc.view.frame = frame;
        vc.drivingScreen = self->_drivingScreen;
        vc.botCodeVC = self->_botCodeVC;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 1.0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_drivingScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_drivingScreen presentViewController:vc animated:NO completion:nil];
    }];
}

-(IBAction) showCodeView
{
    [self closeFlyOutView];
    [self dismissViewControllerAnimated:NO completion:^{
        BotCommand *beginLoop = [[BotCommand alloc] init];
        beginLoop.command = kBEGIN_LOOP;
        beginLoop.iterations = @2;
        
        BotCommand *forward = [[BotCommand alloc] initWithCommand:kFORWARD];
        
        BotCommand *reverse = [[BotCommand alloc] initWithCommand:kREVERSE];
        
        BotCommand *left = [[BotCommand alloc] initWithCommand:kLEFT];
        
        BotCommand *fastLeft = [[BotCommand alloc] initWithCommand:kFAST_LEFT];
        
        BotCommand *right = [[BotCommand alloc] initWithCommand:kRIGHT];
        
        BotCommand *fastRight = [[BotCommand alloc] initWithCommand:kFAST_RIGHT];
        
        
        NSArray *sourceData = [NSArray arrayWithObjects:beginLoop, forward,reverse,left,fastLeft,right,fastRight, nil];
        
        NSArray *destData = [[NSArray alloc] init];
        
        CGRect frame = _drivingScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        _drivingScreen.botCodeVC = [[BotCodeViewController alloc] initWithDriveScreen:_drivingScreen];
        _drivingScreen.botCodeVC.driveScreen = _drivingScreen;
        //vc.driveScreen = self;
        _drivingScreen.botCodeVC.view.frame = frame;
        [_drivingScreen.botCodeVC clearCode];
        _drivingScreen.botCodeVC.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [_drivingScreen.view.window.layer addAnimation:transition forKey:nil];
        [_drivingScreen presentViewController:_drivingScreen.botCodeVC animated:NO completion:nil];
        
    }];
}

-(IBAction) showBlocklyView
{
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closeFlyOutView];
        
        BlocklyView *vc;
        
        CGRect frame = self->_drivingScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[BlocklyView alloc] initWithDriveScreen:_drivingScreen];
        
        vc.view.frame = frame;
        vc.driveScreen = self->_drivingScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_drivingScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_drivingScreen presentViewController:vc animated:NO completion:^{
            [vc setDriveScreen:self->_drivingScreen];
        }];
    }];
}

-(IBAction)showNewsView{
    [self dismissViewControllerAnimated:NO completion:^{
        NewsLaunchViewController *vc;
        
        CGRect frame = self.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[NewsLaunchViewController alloc] initWithDriveScreen:_drivingScreen];
        vc.view.frame = frame;
        vc.drivingScreen = _drivingScreen;
        vc.botCodeVC = _botCodeVC;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 1.0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [_drivingScreen.view.window.layer addAnimation:transition forKey:nil];
        [_drivingScreen presentViewController:vc animated:NO completion:nil];
    }];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait; // or Right of course
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

-(IBAction) showUserList{
    
    if(!_userListImage.isHidden){
        
        _userListView = [[[NSBundle mainBundle]
                          loadNibNamed:@"UserListView"
                          owner:self options:nil]
                         firstObject];
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        _userListView.frame = CGRectMake(0,0,screenWidth,screenHeight);
        
        [self.view addSubview:_userListView];
        _hostCodeLabel.text = [@"Room Code: " stringByAppendingString:_drivingScreen.hostCode];
        
        _userListener = [[[_ref child:@"ControllerV2"] child:_drivingScreen.hostCode] child:@"people"];
        [_userListener observeEventType:(FIRDataEventTypeValue) withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
            NSDictionary *postDict = snapshot.value;
            [self->_userList removeAllObjects];
            
            if(postDict != [NSNull null] && [postDict count] > 0){
                for(NSString *key in postDict){
                    [self->_userList addObject: postDict[key]];
                }
            }
            [self->_userListTable reloadData];
            
            if(self->_userList.count > 0){
                self->_noUserLabel.hidden = true;
                self->_userListTable.hidden = false;
            }else{
                self->_userListTable.hidden = true;
                self->_noUserLabel.hidden = false;
            }
        }];
    }
}

-(IBAction) closeUserListView{
    [_userListener removeAllObservers];
    [_userListView removeFromSuperview];
    _userListView = nil;
}

-(IBAction) changeControl:(id)sender{
    if(sender){
        UIButton *deleteButton = (UIButton*) sender;
        NSIndexPath *index = [NSIndexPath indexPathForRow:deleteButton.tag inSection:0];
        userCell *cell = [_userListTable cellForRowAtIndexPath:index];
        if(cell.hasControlCheckbox.isSelected){
            [cell.controlCheckboxImage setImage:[UIImage imageNamed:@"empty_checkbox.png"]];
            [cell.hasControlCheckbox setSelected:NO];
            
            [[[[[_ref child:@"ControllerV2"] child:_drivingScreen.hostCode] child:@"people"] child:cell.userCellId.text] setValue:@{@"id" : cell.userCellId.text, @"name": cell.userCellName.text, @"isActive": @"false"}];
        } else {
            [cell.controlCheckboxImage setImage:[UIImage imageNamed:@"checkedbox.png"]];
            [cell.hasControlCheckbox setSelected:YES];
            
            [[[[[_ref child:@"ControllerV2"] child:_drivingScreen.hostCode] child:@"people"] child:cell.userCellId.text] setValue:@{@"id" : cell.userCellId.text, @"name": cell.userCellName.text, @"isActive": @"true"}];
            
            for(int i = 0; i < _userList.count; i++){
                NSIndexPath *index = [NSIndexPath indexPathForRow:i inSection:0];
                userCell *cell = [_userListTable cellForRowAtIndexPath:index];
                
                if(i != deleteButton.tag){
                    if(cell.hasControlCheckbox.isSelected){
                        [cell.controlCheckboxImage setImage:[UIImage imageNamed:@"empty_checkbox.png"]];
                        [cell.hasControlCheckbox setSelected:NO];
                        
                        [[[[[_ref child:@"ControllerV2"] child:_drivingScreen.hostCode] child:@"people"] child:cell.userCellId.text] setValue:@{@"id" : cell.userCellId.text, @"name": cell.userCellName.text, @"isActive": @"false"}];
                    }
                }
            }
        }
    }
}

-(void) kickedFromRoom{
    _joinedView.hidden = true;
    _controllerMainView.hidden = false;
    _headerText.text = @"CONTROL CENTER";
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self animateTextField: textField up: YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self animateTextField: textField up: NO];
}

- (void) animateTextField: (UITextField*) textField up: (BOOL) up
{
    const int movementDistance = 80; // tweak as needed
    const float movementDuration = 0.3f; // tweak as needed

    int movement = (up ? -movementDistance : movementDistance);

    [UIView beginAnimations: @"anim" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration: movementDuration];
    _joinView.frame = CGRectOffset(_joinView.frame, 0, movement);
    [UIView commitAnimations];
}

#pragma mark - tableView stuff
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _userList.count;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"index path: %@", indexPath);
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    userCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    if(!cell){
        UIViewController *temporaryController = [[UIViewController alloc] initWithNibName:@"userCell" bundle:nil];
        // Grab a pointer to the custom cell.
        cell = (userCell *)temporaryController.view;
    }
    
    //cell.userCellName.text = @"bob";
    NSDictionary *user = [_userList objectAtIndex:indexPath.row];
    for(NSString *Itemp in user){
        if([Itemp isEqualToString:@"name"]){
            cell.userCellName.text = user[Itemp];
        }else if([Itemp isEqualToString:@"id"]){
            cell.userCellId.text = user[Itemp];
        }else if([Itemp isEqualToString:@"isActive"]){
            NSString *isActive = user[Itemp];
            if([isActive isEqualToString:@"true"]){
                [cell.controlCheckboxImage setImage:[UIImage imageNamed:@"checkedbox.png"]];
                [cell.hasControlCheckbox setSelected:YES];
            }else{
                [cell.controlCheckboxImage setImage:[UIImage imageNamed:@"empty_checkbox.png"]];
                [cell.hasControlCheckbox setSelected:NO];
            }
        }
    }
    
    cell.backgroundColor = [UIColor clearColor];
    cell.hasControlCheckbox.tag = indexPath.row;
    return cell;
    
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 40;
}

@end
