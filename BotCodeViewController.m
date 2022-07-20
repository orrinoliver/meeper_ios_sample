//
//  BotCodeViewController.m
//  meeperBot
//
//  Created by Jim Brandon on 12/26/16.
//  Copyright © 2016 Jim Brandon. All rights reserved.
//

#import "BotCodeViewController.h"
#import "BotCommand.h"
#import "MeeperGlobals.h"
#import "BotCell.h"
#import "BotCommandHeaderView.h"
#import "BotCodeUIHelper.h"
#import "CodeExCell.h"
#import "Tron.h"
#import "BotCode.h"
#import "BotCodeEditView.h"
#import "EditNumberView.h"
#import "EditBotsOnly.h"
#import "EditBoth.h"
#import "BotPickView.h"
#import "BotCodeSaveView.h"
#import "BotCodeEditRoutine.h"
#import "meeperDB.h"
#import "BlocklyView.h"
#import "ComicLaunchViewController.h"
#import "ActivityLaunchViewController.h"
#import "NewsLaunchViewController.h"
#import "ControlRoom.h"
#import "Reachability.h"
#import "userCell.h"
@import Firebase;
@import FirebaseDatabase;

#import "CodeLineCell.h"

@interface BotCodeViewController ()


@property (strong, nonatomic) UIView *flyOutView;
@property BOOL flyOutViewIsOpen;
@property (strong,nonatomic) UITextField *localCodeSaveTextField;
@property (strong,nonatomic) UITextField *localCodeRenameTextField;
@property (strong, nonatomic) FIRDatabaseReference *ref;
@property (strong, nonatomic) FIRDatabaseReference *userListener;

@property (strong, nonatomic) UIView *userListView;
@property (strong, nonatomic) IBOutlet UIImageView *userListImage;
@property NSMutableArray *userList;
@property (strong, nonatomic) UITableView *userListTable;
@property (nonatomic,strong) IBOutlet UILabel *hostCodeLabel;
@property (nonatomic,strong) IBOutlet UILabel *noUserLabel;

@end

@implementation BotCodeViewController

@synthesize selectedCellText = _selectedCellText;

BotCodeUIHelper *botCodeUIHelper;
BotCode *botCode;
EditNumberView *keyPad;
//NSString *codeOutputController = @"";
NSString *previousName;

-(instancetype)initWithDriveScreen:(MPR10ViewController *)driveScreen{
    self = [super init];
    if(self)
    {
        self.driveScreen = driveScreen;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processCurrentCommand)
                                                 name:@"processCurrentCommand"
                                               object:nil];
    
    // setup helpers for collection and table formatting
    // and gesture handling
    
    _dstData = [[NSMutableArray alloc] init];
    _virtualBots = [[NSMutableArray alloc] init];
    _circuits = [[NSMutableArray alloc] init];
    _motors = [[NSMutableArray alloc] init];
    _boards = [[NSMutableArray alloc] init];
    
    botCodeUIHelper = [[BotCodeUIHelper alloc] init];
    botCodeUIHelper.botCODEVC = self;
    
    botCode = [[BotCode alloc] init];
    botCode.botCODEVC = self;
    
    [botCodeUIHelper setupView];
    
    _ref = [[FIRDatabase database] reference];
    _cloudLoadTextField.delegate = self;
    
    [_driveScreen setBotCodeOpen:true];
    
    if(_driveScreen.hostCode != NULL){
        _userListImage.hidden = false;
        _userList = [[NSMutableArray alloc] init];
    }
   
}

-(void) viewDidAppear:(BOOL)animated
{
    
    _tronView = [[TronView alloc] initWithFrameNoAnimate:CGRectMake(0,0,_tronViewContainer.frame.size.width,_tronViewContainer.frame.size.height)];
    [_tronViewContainer addSubview:_tronView];
    
    _tronView.botCODEVC = self;
     botCode.tronView = _tronView;
}

-(void) showPickView :(id) sender :(long) tag
{
    CGRect myFrame = botCodeUIHelper.botCODEVC.view.frame;
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    BotCommand *cmd = [_dstData objectAtIndex:tag];
    if([cmd.command isEqualToString:kBEGIN_LOOP] || [cmd.command isEqualToString:kPAUSE] || [cmd.commandType isEqualToString:@"Boards"]){
        
        if([keyPad isDescendantOfView:self.view])
        {
            [keyPad removeFromSuperview];
        }
        
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        UILabel *displayLabel;
        if(![cmd.commandType isEqualToString:@"Boards"]){
            displayLabel = cell.valLabel;
        }else{
            displayLabel = cell.boardTimeLabel;
        }
        
        keyPad = [[EditNumberView alloc] initWithParentFrameTall:myFrame];
        
        keyPad.frame = CGRectMake(0,0,screenWidth,screenHeight);
        
        keyPad.botCodeVC = self;
        
        bool isLoop = false;
        if([cmd.command isEqualToString:kBEGIN_LOOP]){
            isLoop = true;
        }
        
        [keyPad setupView:(UIButton*)sender :displayLabel :isLoop];
        [self.view addSubview:keyPad];

    }else{
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        EditBoth *editView = [[EditBoth alloc] initWithParentFrameTall:myFrame];
        
        editView.botCodeVC = self;
        
        editView.frame = CGRectMake(0,0,screenWidth,screenHeight);
        
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        UIButton *displayButton = cell.valButton;
        UILabel *displayLabel = cell.valLabel;
        UIImageView *displaySpeed = cell.speedImage;
        UILabel *botCountLabel = cell.multiBotLabel;
        
        if([cmd.command isEqualToString:kLEFT_FORWARD] || [cmd.command isEqualToString:kLEFT_REVERSE] || [cmd.command isEqualToString:kRIGHT_FORWARD] || [cmd.command isEqualToString:kRIGHT_REVERSE]){
            [editView setupBots: cmd :_motors :displayButton : displayLabel : displaySpeed : botCountLabel];
        }else if([cmd.command isEqualToString:kD1ON] || [cmd.command isEqualToString:kD2ON] || [cmd.command isEqualToString:kD3ON] || [cmd.command isEqualToString:kD4ON]){
            [editView setupBots: cmd :_circuits :displayButton : displayLabel : displaySpeed : botCountLabel];
        }else if([cmd.command isEqualToString:kSINGLE_CIRCUIT_ON]){
            [editView setupBots: cmd :_circuits :displayButton : displayLabel : displaySpeed : botCountLabel];
        }else{
            [editView setupBots: cmd :_virtualBots :displayButton : displayLabel : displaySpeed : botCountLabel];
        }
        
        [self.view addSubview:editView];
    }
    
}


-(void) showBotSelector :(long) tag
{
    CGRect myFrame = self.view.frame;
    int height = myFrame.size.height;
    int width = myFrame.size.width;
    
    CGRect frame = CGRectMake(0, 0, width, height);
    
    BotCommand *cmd = [_dstData objectAtIndex:tag];

    if([cmd.command isEqualToString:kLEFT90] || [cmd.command isEqualToString:kLEFT180] || [cmd.command isEqualToString:kLEFT270] || [cmd.command isEqualToString:kLEFT360] || [cmd.command isEqualToString:kRIGHT90] || [cmd.command isEqualToString:kRIGHT180] || [cmd.command isEqualToString:kRIGHT270] || [cmd.command isEqualToString:kRIGHT360] || [cmd.command isEqualToString:kFAST_LEFT90] || [cmd.command isEqualToString:kFAST_LEFT180] || [cmd.command isEqualToString:kFAST_LEFT270] || [cmd.command isEqualToString:kFAST_LEFT360] || [cmd.command isEqualToString:kFAST_RIGHT90] || [cmd.command isEqualToString:kFAST_RIGHT180] || [cmd.command isEqualToString:kFAST_RIGHT270] || [cmd.command isEqualToString:kFAST_RIGHT360])
    {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        EditBotsOnly *editView = [[EditBotsOnly alloc] initWithParentFrameTall:frame];
        editView.frame = CGRectMake(0,0,screenWidth,screenHeight);
        
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        editView.botCODEVC = self;
        UIImageView *displaySpeed = cell.speedImage;
        
        UIButton *displayButton = cell.valButton;
        UILabel *multiBotLabel = cell.multiBotLabel;
        
        [editView setupBots: cmd :_virtualBots :displayButton :displaySpeed :multiBotLabel];
        
        [self.view addSubview:editView];

    } else {
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        CGFloat screenHeight = screenRect.size.height;
        
        EditBoth *editView = [[EditBoth alloc] initWithParentFrameTall:frame];
        
        editView.botCodeVC = self;
        
        editView.frame = CGRectMake(0,0,screenWidth,screenHeight);
        
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        UIButton *displayButton = cell.valButton;
        UILabel *displayLabel = cell.valLabel;
        UIImageView *displaySpeed = cell.speedImage;
        UILabel *botCountLabel = cell.multiBotLabel;
        
        if([cmd.command isEqualToString:kLEFT_FORWARD] || [cmd.command isEqualToString:kLEFT_REVERSE] || [cmd.command isEqualToString:kRIGHT_FORWARD] || [cmd.command isEqualToString:kRIGHT_REVERSE]){
            [editView setupBots: cmd :_motors :displayButton : displayLabel : displaySpeed : botCountLabel];
        }else if([cmd.command isEqualToString:kD1ON] || [cmd.command isEqualToString:kD2ON] || [cmd.command isEqualToString:kD3ON] || [cmd.command isEqualToString:kD4ON]){
            [editView setupBots: cmd :_circuits :displayButton : displayLabel : displaySpeed : botCountLabel];
        }else if([cmd.command isEqualToString:kSINGLE_CIRCUIT_ON]){
            [editView setupBots: cmd :_circuits :displayButton : displayLabel : displaySpeed : botCountLabel];
        }else{
            [editView setupBots: cmd :_virtualBots :displayButton : displayLabel : displaySpeed : botCountLabel];
        }
        
        [self.view addSubview:editView];
    }
}

-(IBAction) showSaveView:(id)sender
{
    bool foundSpace = false;
    if(_dstData.count <= 3){
        for(BotCommand *cmd in _dstData){
            if([cmd.commandType isEqualToString:@"Space"]){
                foundSpace = true;
            }
        }
    }
    
    if(!foundSpace){
        //CGRect myFrame = [[UIScreen mainScreen] bounds];
        
        CGRect myFrame = botCodeUIHelper.botCODEVC.view.frame;
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        int height = screenRect.size.height;
        int width = screenRect.size.width;
        
        BotCodeSaveView *codeSave = [[BotCodeSaveView alloc] initWithParentFrameTall:myFrame];
        codeSave.codeVC = self;
        
        codeSave.frame = CGRectMake(0,0,width,height);
        
        [self.view addSubview:codeSave];
        
        
        UITapGestureRecognizer *singleFingerTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(handleSingleTapSave:)];
        [codeSave.backgroundView addGestureRecognizer:singleFingerTap];
        _localCodeSaveTextField = codeSave.routineName;
    }
}

- (void)handleSingleTapSave:(UITapGestureRecognizer *)recognizer {
    [_localCodeSaveTextField resignFirstResponder];
}

-(void) saveToCloud:(NSString *)code{
    
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd-MMM-yyyy"];
    
    NSString *codeString = @"";
    
    for(BotCommand *cmd in _dstData)
    {
        if(![cmd.commandType isEqualToString:kSTART_COMMAND] && ![cmd.commandType isEqualToString:kEND_COMMAND] )
        {
            if(cmd.comment == NULL || [cmd.comment isEqualToString:@""]){
                cmd.comment = @"~null~";
            }
            
            if(cmd.speed == NULL || [cmd.speed isEqualToString:@"(null)"]){
                cmd.speed = @"Fast";
            }
            
            if(cmd.commandType == NULL || [cmd.commandType isEqualToString:@"(null)"]){
                cmd.commandType = kSTRUCTURE_COMMAND;
            }
            
            if(cmd.iterations == NULL || [[cmd.iterations stringValue] isEqualToString:@"(null)"] || [cmd.iterations stringValue].length < 1){
                cmd.iterations = @0;
            }
            
            //NSString *string = [NSString stringWithFormat:@"~meep~%@~@~%ld~@~%@~@~%@~@~%ld~@~%@~@~%@", cmd.command, ([cmd.duration integerValue] * 1000), cmd.speed,  cmd.iterations, cmd.listOrdinal - 1, cmd.commandType, cmd.comment];
            //NSLog(@"CHECK: %@", string);
            codeString = [NSString stringWithFormat:@"%@~meep~%@~@~%ld~@~%@~@~%@~@~%ld~@~%@~@~%@",codeString, cmd.command, ([cmd.duration integerValue] * 1000), cmd.speed,  cmd.iterations, cmd.listOrdinal - 1, cmd.commandType, cmd.comment];
            
        }
    }
    
    [[[_ref child:@"BotCode"] child:code] setValue:@{@"code" : code, @"date" : [dateFormatter stringFromDate:[NSDate date]], @"id" : [[NSUUID UUID] UUIDString], @"botCodeString": codeString}];
    [self saveRoutine:code:NULL];
}

-(void) saveRoutine :(NSString*) name :(NSMutableArray*) cloudData
{
    if(cloudData == NULL){
        [[meeperDB sharedInstance] saveRoutine :name :_dstData];
    }else{
        [[meeperDB sharedInstance] saveRoutine :name :cloudData];
    }
    
    [botCodeUIHelper setupRoutines];
}

-(void) deleteRoutine :(NSString*) name
{
    [[meeperDB sharedInstance] deleteRoutine :name];
    
    [botCodeUIHelper setupRoutines];
}

-(void) renameRoutine :(NSString*) newName :(NSString*) oldName{
    bool success = true;
    
    //delete any routine with this name
    success = [[meeperDB sharedInstance] renameRoutine:newName : oldName];
    
    [botCodeUIHelper setupRoutines];

}

-(IBAction) toggleTron
{
    [_tronView toggleTron];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Code here will execute before the rotation begins.
    // Equivalent to placing it in the deprecated method -[willRotateToInterfaceOrientation:duration:]
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // Place code here to perform animations during the rotation.
        // You can pass nil or leave this block empty if not necessary.
        
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // Code here will execute after the rotation has finished.
        // Equivalent to placing it in the deprecated method -[didRotateFromInterfaceOrientation:]
        
        if([keyPad isDescendantOfView:self.view])
        {
            [keyPad animatePosition];
        }
        
    }];
}

-(IBAction) runCommands
{
    bool foundSpace = false;
    if(_dstData.count <= 3){
        for(BotCommand *cmd in _dstData){
            if([cmd.commandType isEqualToString:@"Space"]){
                foundSpace = true;
            }
        }
    }
    
    if(!foundSpace){
        _driveScreen.currentBot = @"";
        _driveScreen.currentBoardCommand = @"";
        if(_driveScreen.joinCode == NULL){
            self.startButton.hidden = true;
            self.stopButton.hidden = false;
            [botCode runCommands];
        }else{
            [botCode saveToRoom];
        }
    }
}

-(IBAction) stopExecution
{
    _driveScreen.currentBot = @"";
    _driveScreen.currentBoardCommand = @"";
    self.startButton.hidden = false;
    self.stopButton.hidden = true;
    [botCode resetDstTable];
    botCode.stopCode = YES;
    botCode.keepLooping = false;
    [_driveScreen stopBots];
    
}

-(IBAction) loopCommands
{
    if(!botCode.keepLooping && !_startButton.hidden){
        bool foundSpace = false;
        if(_dstData.count <= 3){
            for(BotCommand *cmd in _dstData){
                if([cmd.commandType isEqualToString:@"Space"]){
                    foundSpace = true;
                }
            }
        }
        
        if(!foundSpace){
            self.startButton.hidden = true;
            self.stopButton.hidden = false;
            botCode.keepLooping = true;
            [botCode runCommands];
        }
    }
}

-(void) processCurrentCommand
{
    BotCommand *command = [botCode getNextCommand];
    
    [botCode processCurrentCommand:command];
}

-(IBAction) clearCode
{
    self.stopExecution;
    [_dstData removeAllObjects];
    [botCodeUIHelper addStartEndCommands];
    [_dstTableView reloadData];
    
}

#pragma mark collection view selector

//number of command button sections in command view collection
-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    if([collectionView isEqual:_commandView]){
        //blargo
        return 4 + _driveScreen.connectedBoards.count + _driveScreen.sharedBoards.count;
    } else {
        return 1;
    }
}


//number of command buttons in section
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section;
{
    if([view isEqual:_commandView]) {
        //blargo
        return [botCodeUIHelper getSectionCount:section];
    } else {
        return _virtualBots.count;
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionView *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    if([collectionView isEqual:_commandView]){
        if ( [(NSString*)[UIDevice currentDevice].model hasPrefix:@"iPad"] ) {
            return 10;
        }else{
            return 5;
        }
    }else{
        return 0;
    }
}

//render cell for command buttons
- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath;
{
    //blargo
    if([cv isEqual:_commandView]) {
        return [botCodeUIHelper commandViewCellAtIndexPath:cv cellForItemAtIndexPath:indexPath];
    //}else {//if([cv isEqual:]){
    //    return [EditBotsOnly defaultBotViewCellAtIndexPath:cv cellForItemAtIndexPath:indexPath];
    } else {
        return [botCodeUIHelper defaultBotViewCellAtIndexPath:cv cellForItemAtIndexPath:indexPath];
    }
}


//render header for command buttons section
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    //blargo
    if([collectionView isEqual:_commandView]) {
        return [botCodeUIHelper commandViewViewForSupplementaryElementOfKind:collectionView viewForSupplementaryElementOfKind:kind atIndexPath:indexPath];
    }
    else
    {
        return nil;
    }
}

//toggle default bot icons
 - (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if([cv isEqual:_defaultBots])
    {
        [botCodeUIHelper collectionView:cv defaultBotViewDidSelectItemAtIndexPath:indexPath];
    }
}


#pragma mark -
#pragma mark UITableView stuff
//dest table view handlers

//call back for picker entry
- (void)didEditTextField :(NSString*) value :(long) tag
{
    if(tag < _dstData.count && value)
    {
        BotCommand *cmd = [_dstData objectAtIndex:tag];
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        f.numberStyle = NSNumberFormatterDecimalStyle;
        
        if([cmd.command isEqualToString:kBEGIN_LOOP])
        {
            cmd.iterations = [f numberFromString:value];
            //[cell.valLabel setText:value];
        } else {
            if(![value isEqualToString:@"\u221E"]){
                cmd.duration = [f numberFromString:value];
            }else{
                cmd.duration = [f numberFromString:@"9898"];
            }
            //[cell.valLabel setText:value];
        }
        
        [_dstTableView reloadData];
        
    }
}

-(void)newSpeedSelected :(NSString*) value :(long) tag : (UIImage*) image
{
    if(tag < _dstData.count && value)
    {
        BotCommand *cmd = [_dstData objectAtIndex:tag];
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        cell.speedImage.image = image;
        
        cmd.speed = value;
        
        [_dstTableView reloadData];
        
    }
}

-(void)changedBots :(NSString*) botCount :(long) tag
{
    if(tag < _dstData.count && botCount)
    {
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        cell.multiBotLabel.text = botCount;
        
        [_dstTableView reloadData];
    }
}

-(void)newComment :(NSString*) value :(long) tag
{
    if(tag < _dstData.count && value)
    {
        BotCommand *cmd = [_dstData objectAtIndex:tag];
        NSIndexPath *path = [NSIndexPath indexPathForRow:tag inSection:0];
        CodeExCell *cell = (CodeExCell*) [_dstTableView cellForRowAtIndexPath:path];
        
        cmd.comment = value;
        
        //[_dstTableView reloadData];
        
    }
}

- (UITableViewCell*)dstTableCellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    return [botCodeUIHelper dstTableCellForRowAtIndexPath:indexPath];
}


- (BOOL)tableView:(UITableView*)tableView canMoveRowAtIndexPath:(NSIndexPath*)indexPath
{
    // disable build in reodering functionality
    return NO;
}

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [botCodeUIHelper tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    if([tableView isEqual:_userListTable]){
        return _userList.count;
    }else{
        return [botCodeUIHelper tableView:tableView numberOfRowsInSection:section];
    }
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([tableView isEqual:_userListTable]){
        return 40;
    }else{
        return [botCodeUIHelper tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    if([tableView isEqual:_dstTableView])
    {
        return [botCodeUIHelper tableView:tableView cellForRowAtIndexPath:indexPath];//last one goes here twice
    } else if([tableView isEqual:_userListTable]){
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
    }else {
        return [botCodeUIHelper routineTableCellForRowAtIndexPath:indexPath];
    }
}

-(IBAction) showBlockly
{
    
    [self clearCode];
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closingScreen];
        [self closingMask];
        [self closeFlyOutView];
        [_driveScreen setBotCodeOpen:false];
        
        BlocklyView *vc;
        
        CGRect frame = self->_driveScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[BlocklyView alloc] initWithDriveScreen:_driveScreen];
        vc.view.frame = frame;
        vc.driveScreen = self->_driveScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_driveScreen presentViewController:vc animated:NO completion:^{
            [vc setDriveScreen:self->_driveScreen];
        }];
    }];
}

-(IBAction) showComic
{
    
    [self clearCode];
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closingScreen];
        [self closingMask];
        [self closeFlyOutView];
        [_driveScreen setBotCodeOpen:false];
        
        ComicLaunchViewController *vc;
        
        CGRect frame = _driveScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[ComicLaunchViewController alloc] initWithDriveScreen:_driveScreen];
        
        vc.view.frame = frame;
        vc.drivingScreen = _driveScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [_driveScreen presentViewController:vc animated:NO completion:nil];
    }];
}

-(IBAction) showActivity
{
    [self clearCode];
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closingScreen];
        [self closingMask];
        [self closeFlyOutView];
        [_driveScreen setBotCodeOpen:false];
        
        ActivityLaunchViewController *vc;
        
        CGRect frame = _driveScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[ActivityLaunchViewController alloc] initWithDriveScreen:_driveScreen];
        
        vc.view.frame = frame;
        vc.drivingScreen = _driveScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [_driveScreen presentViewController:vc animated:NO completion:nil];
    }];
}

-(IBAction)showNews{
    [self dismissViewControllerAnimated:NO completion:^{
        [self closingScreen];
        [self closingMask];
        [self closeFlyOutView];
        [_driveScreen setBotCodeOpen:false];
        
        NewsLaunchViewController *vc;
        
        CGRect frame = self.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[NewsLaunchViewController alloc] initWithDriveScreen:_driveScreen];
        vc.view.frame = frame;
        vc.drivingScreen = _driveScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 1.0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [_driveScreen presentViewController:vc animated:NO completion:nil];
    }];
}

-(IBAction)showController{
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closingScreen];
        [self closingMask];
        [self closeFlyOutView];
        [_driveScreen setBotCodeOpen:false];
        
        ControlRoom *vc;
        
        CGRect frame = self.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[ControlRoom alloc] initWithDriveScreen:_driveScreen];
        vc.view.frame = frame;
        vc.drivingScreen = self->_driveScreen;
        _driveScreen.controlRoom = vc;
        //vc.botCodeVC = _botCodeVC;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 1.0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_driveScreen presentViewController:vc animated:NO completion:nil];
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeLeft; // or Right of course
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)closingScreen {
    return UIInterfaceOrientationPortrait;
}


- (UIInterfaceOrientationMask)closingMask {
    return UIInterfaceOrientationMaskPortrait;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if(tableView == _routineTableView){
        
        CodeLineCell *cell = [_routineTableView cellForRowAtIndexPath:indexPath];
        
        for(int i = 0; i < _routineData.count; i++){
            Routine *routine = [_routineData objectAtIndex:i];
            if([cell.codeLbl.text isEqualToString: routine.name]){
                previousName = routine.name;
                break;
            }
        }
        [self showRoutineEdit : previousName];
    }
}

-(void) showRoutineEdit :(NSString*) currentName
{
    CGRect myFrame = [[UIScreen mainScreen] bounds];
    int height = myFrame.size.height;
    int width = myFrame.size.width;
    
    BotCodeEditRoutine *editRoutine = [[BotCodeEditRoutine alloc] initWithFrame:myFrame];
    editRoutine.codeVC = self;
    editRoutine.currentRoutineName = currentName;
    editRoutine.renameTextField.text = currentName;
    
    editRoutine.frame = CGRectMake(0,0,width,height);
    
    [self.view addSubview:editRoutine];
    
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handleSingleTapRename:)];
    [editRoutine.backgroundImage addGestureRecognizer:singleFingerTap];
    _localCodeRenameTextField = editRoutine.renameTextField;
}

- (void)handleSingleTapRename:(UITapGestureRecognizer *)recognizer {
    [_localCodeRenameTextField resignFirstResponder];
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
            
            _flyOutView.frame = CGRectMake(0, 0, screenWidth, screenHeight);
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
        _flyOutView.frame = CGRectMake(screenWidth *-1, 0, screenWidth, screenHeight);
    } completion:^(BOOL finished) {
        [_flyOutView removeFromSuperview];
        _flyOutViewIsOpen = NO;
        _flyOutView = nil;
    }];
}

-(IBAction) showCodeView
{
    [self closeFlyOutView];
}

-(IBAction)showComicView{
    
    [self clearCode];
    [self showComic];
}

-(IBAction) showActivitiesView{
    [self clearCode];
    [self showActivity];
}

-(IBAction) showNewsView{
    [self clearCode];
    [self showNews];
}

-(IBAction)showBlocklyView{
    [self clearCode];
    [self showBlockly];
}

-(IBAction) showControllerView{
    [self clearCode];
    [self showController];
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

-(IBAction)reassignBots{
    
    bool foundSpace = false;
    if(_dstData.count <= 3){
        for(BotCommand *cmd in _dstData){
            if([cmd.commandType isEqualToString:@"Space"]){
                foundSpace = true;
            }
        }
    }
    
    if(!foundSpace){
        _reassginLayout.hidden = false;
        [self stopExecution];
        [botCode reassignBots];
        
    }
    
    [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(closeReassign) userInfo:nil repeats:NO];
}

-(void) closeReassign{
    _reassginLayout.hidden = true;
}

-(IBAction) openCloudLoadLayout{
    [self setPlaceholderText];
    _cloudLoadLayout.hidden = false;
}

-(IBAction) closeCloudLoadLayout{
    if(![_cloudLoadTextField isFirstResponder]){
        _cloudLoadLayout.hidden = true;
        _cloudLoadTextField.text = @"";
        [_cloudLoadTextField resignFirstResponder];
    }else{
        [_cloudLoadTextField resignFirstResponder];
    }
}

-(IBAction)loadFromCloud{
    if([self connected]){
        FIRDatabaseReference *overviewRef = [_ref child:@"BotCode"];
        
        NSMutableArray *botCodeList = [[NSMutableArray alloc] init];
        
        [overviewRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
            NSDictionary *postDict = snapshot.value;
            
            NSString *botCodeString;
            
            bool foundCode = false;
            for (NSString *key in postDict) {
                NSDictionary *value = postDict[key];
                [botCodeList addObject:value];
                for(NSString *Itemp in value){
                    id value2 = value[Itemp];
                    if([[Itemp uppercaseString] isEqualToString:@"CODE"]){
                        if([[value2 uppercaseString] isEqualToString:[self->_cloudLoadTextField.text uppercaseString]]){
                            foundCode = true;
                            break;
                        }
                    }
                }
                if(foundCode){
                    [_cloudLoadTextField resignFirstResponder];
                    for(NSString *Itemp in value){
                        if([[Itemp uppercaseString] isEqualToString:@"BOTCODESTRING"]){
                            botCodeString = value[Itemp];
                            break;
                        }
                    }
                    break;
                }
            }
            
            if(foundCode){
                [_cloudLoadTextField resignFirstResponder];
                                    
                [botCodeUIHelper insertCodeFromCloud :botCodeString :[self->_cloudLoadTextField.text uppercaseString]];
                [self closeCloudLoadLayout];
            }else{
                NSString *message = [NSString stringWithFormat:@"No BotCode code was found with code %@", self->_cloudLoadTextField.text];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Code Not Found" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                [alert show];
            }
        }];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Internet" message:@"An internet connection is required to download code." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }
}

- (BOOL)connected
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    return networkStatus != NotReachable;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

-(void) setPlaceholderText{
    if ([_cloudLoadTextField respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:@"#85D5F7"];
        [scanner setScanLocation:1]; // bypass '#' character
        [scanner scanHexInt:&rgbValue];
        UIColor *color = [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
        _cloudLoadTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter Code Here" attributes:@{NSForegroundColorAttributeName: color}];
    } else {
        NSLog(@"Cannot set placeholder text's color, because deployment target is earlier than iOS 6.0");
        // TODO: Add fall-back code to set placeholder color.
    }
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
    _cloudLoadLayout.frame = CGRectOffset(_cloudLoadLayout.frame, 0, movement);
    [UIView commitAnimations];
}

-(void) controllerLoad:(NSString*)code{
    [self clearCode];
    [botCodeUIHelper insertCodeFromCloud :code :NULL];
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
        _hostCodeLabel.text = [@"Room Code: " stringByAppendingString:_driveScreen.hostCode];
        
        _userListener = [[[_ref child:@"ControllerV2"] child:_driveScreen.hostCode] child:@"people"];
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
            
            [[[[[_ref child:@"ControllerV2"] child:_driveScreen.hostCode] child:@"people"] child:cell.userCellId.text] setValue:@{@"id" : cell.userCellId.text, @"name": cell.userCellName.text, @"isActive": @"false"}];
        } else {
            [cell.controlCheckboxImage setImage:[UIImage imageNamed:@"checkedbox.png"]];
            [cell.hasControlCheckbox setSelected:YES];
            
            [[[[[_ref child:@"ControllerV2"] child:_driveScreen.hostCode] child:@"people"] child:cell.userCellId.text] setValue:@{@"id" : cell.userCellId.text, @"name": cell.userCellName.text, @"isActive": @"true"}];
            
            for(int i = 0; i < _userList.count; i++){
                NSIndexPath *index = [NSIndexPath indexPathForRow:i inSection:0];
                userCell *cell = [_userListTable cellForRowAtIndexPath:index];
                
                if(i != deleteButton.tag){
                    if(cell.hasControlCheckbox.isSelected){
                        [cell.controlCheckboxImage setImage:[UIImage imageNamed:@"empty_checkbox.png"]];
                        [cell.hasControlCheckbox setSelected:NO];
                        
                        [[[[[_ref child:@"ControllerV2"] child:_driveScreen.hostCode] child:@"people"] child:cell.userCellId.text] setValue:@{@"id" : cell.userCellId.text, @"name": cell.userCellName.text, @"isActive": @"false"}];
                    }
                }
            }
        }
    }
}

-(void) setBots{
    [botCodeUIHelper setupVirtualBots];
}

-(void) removeBot: (MeeperBot*) removeBot{
    
    NSMutableArray *vBots = [[meeperDB sharedInstance] selectVirtualBots];
    
    for(int i = 0; i < _dstData.count; i++){
        NSMutableArray *removeList = [[NSMutableArray alloc] init];
        BotCommand *command = [_dstData objectAtIndex:i];
        if(command.command != NULL){
            for(MeeperBot *bot in command.botList){
                if([[bot.UUID uppercaseString] isEqualToString:[removeBot.UUID uppercaseString]]){
                    [removeList addObject:bot];
                }
            }
            
            for(MeeperBot *tempBot in removeList){
                [command.botList removeObject:tempBot];
            }
            
            if(command.botList.count <= 0){
                
                if(vBots.count >=1)
                {
                    MeeperBot *bot = [vBots objectAtIndex:0];
                    bot.activeBot = YES;
                    [command.botList addObject:bot];
                }
            }
        }
    }

    for(MeeperBot *bot in _circuits){
        if([[bot.UUID uppercaseString] isEqualToString:[removeBot.UUID uppercaseString]]){
            [_circuits removeObject:bot];
            break;
        }
    }
    
    if(_circuits.count <= 0){
        if(vBots.count >=1)
        {
            MeeperBot *bot = [vBots objectAtIndex:0];
            bot.activeBot = YES;
            [_circuits addObject:bot];
        }
    }
    
    for(MeeperBot *bot in _motors){
        if([[bot.UUID uppercaseString] isEqualToString:[removeBot.UUID uppercaseString]]){
            [_motors removeObject:bot];
            break;
        }
    }
    
    if(_motors.count <= 0){
        if(vBots.count >=1)
        {
            MeeperBot *bot = [vBots objectAtIndex:0];
            bot.activeBot = YES;
            [_motors addObject:bot];
        }
    }
    
    for(MeeperBot *bot in _virtualBots){
        if([[bot.UUID uppercaseString] isEqualToString:[removeBot.UUID uppercaseString]]){
            [_virtualBots removeObject:bot];
            break;
        }
    }
    
    if(_virtualBots.count <= 0){
        if(vBots.count >=1)
        {
            MeeperBot *bot = [vBots objectAtIndex:0];
            bot.activeBot = YES;
            [_virtualBots addObject:bot];
        }
    }
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(reloadTable) userInfo:nil repeats:NO];
}

-(void) reloadTable{
    [_dstTableView reloadData];
}
@end
