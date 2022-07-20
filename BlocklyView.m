//
//  BlocklyView.m
//  meeperBot
//
//  Created by Brandon Korth on 2/8/19.
//  Copyright © 2019 Jim Brandon. All rights reserved.
//

#import "BlocklyView.h"
#import "meeperDB.h"
#import "BlocklyNameCell.h"
#import "ComicLaunchViewController.h"
#import "ActivityLaunchViewController.h"
#import "NewsLaunchViewController.h"
#import "ControlRoom.h"
#import "Reachability.h"
#import "userCell.h"
@import Firebase;
@import FirebaseDatabase;

@interface BlocklyView ()
@property (nonatomic) Boolean currentlyRunning;
@property (nonatomic) Boolean repeatForever;

@property (strong, nonatomic) IBOutlet UIButton *playButton;
@property (strong, nonatomic) IBOutlet UIImageView *playButtonImage;
@property (strong, nonatomic) IBOutlet UITextView *codeTextView;
@property (nonatomic) NSString *currentRequestUUID; //todo do i need this?
@property (strong, nonatomic) IBOutlet UIImageView *fullscreenImage;
@property (strong, nonatomic) IBOutlet UIView *textView;
@property (strong, nonatomic) IBOutlet UIView *topBar;

@property (strong, nonatomic) IBOutlet WKWebView *webView;

//save stuff
@property (strong, nonatomic) IBOutlet UIView *saveView;
@property (strong, nonatomic) IBOutlet UITextField *routineText;
@property (strong, nonatomic) IBOutlet UIView *saveBackgroundButton;

//load stuff
@property (strong, nonatomic) IBOutlet UIView *blocklyLoadView;
@property (strong, nonatomic) IBOutlet UITableView *nameTable;
@property (strong, nonatomic) IBOutlet UILabel *noCodeFound;
@property (strong, nonatomic) IBOutlet UIView *areYouSureView;

@property bool isFullscreen;
@property CGRect originalRect;
@property NSMutableArray *repeatList;
@property NSMutableArray *commandsToBeExecuted;
@property NSMutableArray *alwaysRepeatCommands;
@property int currentCmd;
@property NSMutableArray *blocklyList;

//flyout view
@property (strong, nonatomic) UIView *flyOutView;
@property BOOL flyOutViewIsOpen;

//cloud save view
@property (strong, nonatomic) IBOutlet UIView *cloudSaveLayout;
@property (strong, nonatomic) IBOutlet UILabel *codeLabel;

@property (strong, nonatomic) IBOutlet UIView *cloudLoadLayout;
@property (strong, nonatomic) IBOutlet UITextField *loadCodeLabel;
@property (strong, nonatomic) IBOutlet UIButton *cloudLoadBackgroundButton;

@property (strong, nonatomic) IBOutlet UIView *renameView;
@property (strong, nonatomic) IBOutlet UITextField *renameTextField;
@property (strong, nonatomic) IBOutlet UIButton *renameBackgroundButton;

@property (strong, nonatomic) FIRDatabaseReference *ref;
@property (strong, nonatomic) FIRDatabaseReference *userListener;

@property (strong, nonatomic) UIView *userListView;
@property (strong, nonatomic) IBOutlet UIImageView *userListImage;
@property NSMutableArray *userList;
@property (strong, nonatomic) UITableView *userListTable;
@property (nonatomic,strong) IBOutlet UILabel *hostCodeLabel;
@property (nonatomic,strong) IBOutlet UILabel *noUserLabel;

@end

static NSString *HOST_HTML = @"Blockly/webview.html";

BlocklyNameCell *nameCellToChange;
NSString *oldName;
Boolean firstTime = true;
id deleteId;

@implementation BlocklyView

-(instancetype)initWithDriveScreen:(MPR10ViewController *)driveScreen{
    self = [super init];
    if(self)
    {
        self.driveScreen = driveScreen;
    }
    return self;
}

-(void) viewDidLoad {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(processCurrentCommand)
                                                 name:@"processCurrentCommandBlockly"
                                               object:nil];
    
    _currentCmd = 0;
    
    _repeatList =  [[NSMutableArray alloc] init];
    
    _webView.UIDelegate = self;
    [self loadWebContent];
    
    
    if ([_routineText respondsToSelector:@selector(setAttributedPlaceholder:)]) {
        UIColor *color = [UIColor whiteColor];
        _routineText.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter Name" attributes:@{NSForegroundColorAttributeName: color}];
    } else {
        NSLog(@"Cannot set placeholder text's color, because deployment target is earlier than iOS 6.0");
    }
    
    _routineText.delegate = self;
    _loadCodeLabel.delegate = self;
    _renameTextField.delegate = self;
    
    self.codeTextView.editable = false;
    
    if ([self connected]) {
        _ref = [[FIRDatabase database] reference];
    }
    
    if(_driveScreen.hostCode != NULL){
        _userListImage.hidden = false;
        _userList = [[NSMutableArray alloc] init];
    }
    
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handleSingleTap:)];
    [_saveBackgroundButton addGestureRecognizer:singleFingerTap];
}

/// Load the root HTML page into the webview.
-(void) loadWebContent{
    
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc]
                                             init];
    WKUserContentController *controller = [[WKUserContentController alloc]
                                           init];
    [controller addScriptMessageHandler:self name:@"codeObserver"];
    configuration.userContentController = controller;
    
    _webView = [[WKWebView alloc] initWithFrame:_mainView.frame configuration:configuration];
    _webView.frame = CGRectMake(0, 0, _mainView.frame.size.width, _mainView.frame.size.height);
    _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _webView.UIDelegate = self;
    [_mainView addSubview:_webView];
    
    NSURL *htmlUrl = [[NSBundle bundleForClass:[self class]] URLForResource:@"webview" withExtension:@"html" subdirectory: @"Blockly"];
    
    if(htmlUrl){
        [_webView loadRequest: [NSURLRequest requestWithURL:htmlUrl]];
    }else{
        NSLog(@"Failed to load HTML.  Could not find resource.");
    }
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    
    NSArray *listItems = [message.body componentsSeparatedByString:@"~meep~"];
    if([listItems[0] isEqualToString:@"code"]){
        [self codeGenerationCompletionWithCode:listItems[1]];
        [_webView evaluateJavaScript:(@"autosaveCode()") completionHandler: nil];
    }else if([listItems[0] isEqualToString:@"saving"]){
        [self saveWorkspace: listItems[1] : false : NULL : false];
    }else if([listItems[0] isEqualToString:@"autosave"]){
        [self saveWorkspace: listItems[1] : true : NULL : false];
    }else if([listItems[0] isEqualToString:@"autoload"]){
        
        [self loadBots];
        
        NSMutableArray *autoload = [[meeperDB sharedInstance] loadBlockly:true];
        if(autoload.count >= 1){
            NSMutableArray *blockly = autoload[0];
            NSString *javascript = [NSString stringWithFormat:@"loadCode('%@')", blockly[1]];
            
            [_webView evaluateJavaScript:(javascript) completionHandler: nil];
        }
    }else if([listItems[0] isEqualToString:@"failure"]){
        _codeTextView.text = listItems[1];
    }else if([listItems[0] isEqualToString:@"cloudsave"]){
        [self saveWorkspace: listItems[1] : false : NULL : true];
    }else if([listItems[0] isEqualToString:@"savefromcloud"]){
        NSArray *listItems2 = [listItems[1] componentsSeparatedByString:@"~cloud~"];
        NSLog(@"XML: %@", listItems2[0]);
        [self saveWorkspace: listItems2[0] : false : listItems2[1] : false];
    }else if([listItems[0] isEqualToString:@"popup"]){
        if([listItems[1] isEqualToString:@"true"]){
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"Your code was loaded successfully." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
            } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Loading Error" message:@"There was an error loading your code..." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
            }
    }else if([listItems[0] isEqualToString:@"runuser"]){
        [self sendUserData:listItems[1]];
        [self codeGenerationCompletionWithCode:listItems[1]];
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (IBAction)didPressPlayButton:(UIButton *)sender {
    
    if (self.currentlyRunning) {
        if (_currentRequestUUID == nil) {
            NSLog(@"Error: The current request UUID is nil.");
            return;
        }
        [self resetRequests];
    } else {
        
        if(_driveScreen.joinCode == NULL){
            self.codeTextView.text = @"Generating code...";
            
            // Request code generation for the workspace
            [_webView evaluateJavaScript:(@"showCode()") completionHandler: nil];
        }else{
            [_webView evaluateJavaScript:@"runUserCode()" completionHandler:nil];
        }
    }
}

- (void)resetRequests {
    self.currentlyRunning = NO;
    self.currentRequestUUID = @"";
    self.playButton.enabled = YES;
    _repeatForever = false;
    _stopCode = true;
    [self.playButtonImage setImage:[UIImage imageNamed:@"play_arrow.png"]];
    [self.playButton setTitle:@"Run Code" forState:UIControlStateNormal];
    
    for(MeeperBot *bot in _driveScreen.connectedCircuits){
        [bot.keepOn removeAllObjects];
    }
    for(MeeperBot *bot in _driveScreen.sharedCircuits){
        [bot.keepOn removeAllObjects];
    }
    
    [_driveScreen stopBots];
}

- (void)saveWorkspace:(NSString *) xmlCode :(Boolean) isAutosave :(NSString*) loadCode : (Boolean) isCloudSave {
    if(loadCode == NULL && ![loadCode isEqualToString:@""]){
        if(!isAutosave){
            
            if(isCloudSave){
                
                NSString *code = [self generateRandomString];
                
                _codeLabel.text = code;
                if([self connected]){
                    _cloudSaveLayout.hidden = false;
                    
                    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
                    [dateFormatter setDateFormat:@"dd-MMM-yyyy"];
                    
                    [[[_ref child:@"Blockly"] child:code] setValue:@{@"code" : code, @"date" : [dateFormatter stringFromDate:[NSDate date]], @"id" : [[NSUUID UUID] UUIDString], @"xml": xmlCode}];
                    
                }else{
                    NSString *message = [NSString stringWithFormat:@"An internet connection is required to upload code. Your code was still saved locally on your device as %@.", code];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Internet" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                    [alert show];
                }
                [[meeperDB sharedInstance] saveBlockly:code :xmlCode];
            }else{
                [[meeperDB sharedInstance] saveBlockly:_routineText.text :xmlCode];
            }
            
        }else{
            [[meeperDB sharedInstance] saveBlockly:@"meeper_autoload_xml" :xmlCode];
        }
    }else{
        [[meeperDB sharedInstance] saveBlockly:loadCode :xmlCode];
    }
    
    [self closeSaveView];
}

- (void)loadWorkspace:(NSMutableArray*) blockly {
    NSLog(@"loadxml: %@", blockly[1]);
    
    NSString *javascript = [NSString stringWithFormat:@"loadCode('%@')", blockly[1]];
    
    [_webView evaluateJavaScript:(javascript) completionHandler:^(id result, NSError *error) {
        if (error == nil) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"Your code was loaded successfully." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Loading Error" message:@"There was an error loading your code..." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
            [alert show];
            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
        }
    }];
}

- (void)codeGenerationCompletionWithCode:(NSString *)code {

    NSMutableString *str = [code mutableCopy];
    
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"#\\?.+?!"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:NULL];
    
    [regex replaceMatchesInString:str
                          options:0
                            range:NSMakeRange(0, [str length])
                     withTemplate:@""];
    
    _codeTextView.text = str;
    
    _currentRequestUUID = @"";
    if(_driveScreen.joinCode == NULL){
        [self runCode: code];
    }
}

- (void)runCode:(NSString *)code {
    
    // Run the generated code in the web view by calling `Turtle.execute(<code>)`
    NSString *escapedString = [self escapedJSString:code];
    
    NSArray *listItems = [escapedString componentsSeparatedByString:@"~"];

    [self processCode: listItems];
}

- (NSString *)escapedJSString:(NSString *)string {
    return [[[[[[string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
                stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
               stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"]
              stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"]
             stringByReplacingOccurrencesOfString:@"\n" withString:@"~"]
            stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
}

-(IBAction)switchFullScreen{
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    if(firstTime){
    _originalRect = CGRectMake(_textView.frame.origin.x, _textView.frame.origin.y, _textView.frame.size.width, _textView.frame.size.height);
        firstTime = false;
    }
    
    if(_isFullscreen){
        _isFullscreen = false;
        [_fullscreenImage setImage:[UIImage imageNamed:@"ic_fullscreen"]];
        _textView.frame = _originalRect;
    }else{
        _isFullscreen = true;
        [_fullscreenImage setImage:[UIImage imageNamed:@"ic_fullscreen_close"]];
        _textView.frame = CGRectMake(0,_topBar.bounds.size.height,_textView.frame.size.width,screenHeight-_topBar.bounds.size.height);
    }
}

-(void) processCode:(NSArray*) commandList{
    if(_repeatForever || _currentlyRunning){
        [self resetRequests];
    }else{
        
        _commandsToBeExecuted = [[NSMutableArray alloc] init];
        _alwaysRepeatCommands = [[NSMutableArray alloc] init];
        _repeatForever = false;
        _currentCmd = 0;
        for(int i = 0; i < commandList.count; i++){
            [self createCommand:[commandList[i] stringByTrimmingCharactersInSet:
                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]] :i :commandList :true];
        }
        
        if(_repeatForever){
            NSLog(@"repeatList: %@", _repeatList);
            for(int i = 0; i < _repeatList.count; i++){
                [self createCommand:[_repeatList[i] stringByTrimmingCharactersInSet:
                                     [NSCharacterSet whitespaceAndNewlineCharacterSet]] :i :_repeatList :false];
            }
        }
        
        if(_commandsToBeExecuted.count > 0)
        {
            BotCommand *command = [_commandsToBeExecuted objectAtIndex:0];
            _currentCmd++;
            command.currentCommand = YES;
            
            _currentlyRunning = true;
            self.playButton.enabled = YES;
            _stopCode = false;
            [self.playButtonImage setImage:[UIImage imageNamed:@"ic_stop_image"]];
            [self.playButton setTitle:@"Stop Turtle" forState:UIControlStateNormal];
            
            [self postCommand:command];
        }
    }
}

-(void) createCommand:(NSString*) command : (int) index : (NSMutableArray*) commandList : (Boolean) nonRepeating{
    NSString *botCommand = @"";
    int duration = 0;
    int iterations = 0;
    long ordinal = 0;
    NSString *speed = @"Fast";
    NSMutableArray *botList = [[NSMutableArray alloc] init];
    
    if(![command isEqualToString:@""]){
        if([command containsString:@"{"]){
            if([command containsString:@"for"]){
                NSArray *seperated = [command componentsSeparatedByString:@"<"];
                NSArray *seperated2 = [command componentsSeparatedByString:@";"];
                
                int loopCount = 0;
                NSMutableArray *cloneList = [[NSMutableArray alloc] init];
                
                for(int i = index+1; i < commandList.count; i++){
                    if([[commandList[i] stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"}"]){
                        //if no nested loops
                        if(loopCount == 0){
                            //cone commands x amount of times
                            NSArray *seperated3 = [seperated2[1] componentsSeparatedByString:@"<"];
                            NSLog(@"j string: %@, j int: %lu, seperated2[1] %@", seperated3[1], [[seperated3[1]stringByTrimmingCharactersInSet:
                                                     [NSCharacterSet whitespaceAndNewlineCharacterSet]] integerValue], seperated2[1]);
                            for(int j = 0; j <
                                [[seperated3[1]stringByTrimmingCharactersInSet:
                                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]] integerValue] - 1;
                                j++){
                                //for(int k = cloneList.count; k > 0; k--){
                                for(int k = 0; k < cloneList.count; k++){
                                    [commandList insertObject:cloneList[k] atIndex:i];
                                }
                            }
                            break;
                        }else{
                            loopCount--;
                            [cloneList insertObject:[commandList[i] stringByTrimmingCharactersInSet:
                                                     [NSCharacterSet whitespaceAndNewlineCharacterSet]]atIndex:0];
                        }
                    } else if([[commandList[i] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"Forever"] ||
                              [[commandList[i] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"while"] ||
                              [[commandList[i] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"else if"] ||
                              [[commandList[i] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"else"] ||
                              [[commandList[i] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"if"] ||
                              [[commandList[i] stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"for"]){
                        loopCount++;
                        [cloneList insertObject:[commandList[i] stringByTrimmingCharactersInSet:
                                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]]atIndex:0];
                    }else{
                        [cloneList insertObject:[commandList[i] stringByTrimmingCharactersInSet:
                                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]]atIndex:0];
                    }
                }
            }else if([command containsString:@"Forever"]){
                int loopCount = 0;
                NSMutableArray *cloneList = [[NSMutableArray alloc] init];
                
                for(int i = index+1; i < commandList.count; i++){
                    if([[commandList[i] stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"}"]){
                        //if no nested loops
                        if(loopCount == 0){
                            [_repeatList removeAllObjects];
                            for(int k = 0; k < cloneList.count; k++){
                                [_repeatList insertObject:cloneList[k] atIndex:0];
                            }
                            
                            int removeAfter = index + cloneList.count;
                            for(int k = commandList.count - 1; k > removeAfter; k--){
                                [commandList removeObjectAtIndex:k];
                            }
                            
                            break;
                        }else{
                            loopCount--;
                            [cloneList insertObject:[commandList[i] stringByTrimmingCharactersInSet:
                                                     [NSCharacterSet whitespaceAndNewlineCharacterSet]]atIndex:0];
                        }
                    }else if([[commandList[i] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"Forever"]){
                        [cloneList removeAllObjects];
                    }else if([[commandList[i] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"while"] ||
                             [[commandList[i] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"else if"] ||
                             [[commandList[i] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"else"] ||
                             [[commandList[i] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"if"] ||
                             [[commandList[i] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]] containsString:@"for"]){
                        
                        loopCount++;
                        [cloneList insertObject:[commandList[i] stringByTrimmingCharactersInSet:
                                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]]atIndex:0];
                    }else{
                        [cloneList insertObject:[commandList[i] stringByTrimmingCharactersInSet:
                                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]]atIndex:0];
                    }
                    NSLog(@"cloneList: %@, commandList: %@", cloneList, commandList);
                    _repeatForever = true;
                }
            }else if([command containsString:@"while"]){
                //will do later
            }else if([command containsString:@"else if"]){
                //will do later
            }else if([command containsString:@"else"]){
                //will do later
            }else if([command containsString:@"if"]){
                //will do later
            }
        }else if([command containsString:@"}"]){
            //will do later
        }else if([command containsString:@"("]){
            if(![command containsString:@"wait"] && ![[command uppercaseString]containsString:@"TOGGLE"]){
                NSLog(@"command: %@", command);
                NSArray *seperated = [command componentsSeparatedByString:@"("];
                NSArray *seperated2 = [seperated[1] componentsSeparatedByString:@","];
                
                for(int i = 2; i < seperated.count; i++){
                    
                    NSString *botAddress;
                    if([seperated[i] containsString:@"#?"]){
                        NSRange r1 = [seperated[i] rangeOfString:@"#?"];
                        NSRange r2 = [seperated[i] rangeOfString:@"!"];
                        NSRange rSub = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
                        botAddress = [seperated[i] substringWithRange:rSub];
                    }else{
                        botAddress = seperated[i];
                    }
                    
                    if([botAddress containsString:@"-"]){
                        for(MeeperBot *bot in _driveScreen.items){
                            NSLog(@"bot.UUID: %@, botAddress: %@", bot.UUID, botAddress);
                            if([bot.UUID isEqualToString:botAddress] && ![botList containsObject:bot]){
                                [botList addObject:bot];
                            }
                        }
                        for(MeeperBot *bot in _driveScreen.sharedBots){
                            if([bot.UUID isEqualToString:botAddress] && ![botList containsObject:bot]){
                                [botList addObject:bot];
                            }
                        }
                        for(MeeperBot *bot in _driveScreen.connectedCircuits){
                            if([bot.UUID isEqualToString:botAddress] && ![botList containsObject:bot]){
                                [botList addObject:bot];
                            }
                        }
                        for(MeeperBot *bot in _driveScreen.sharedCircuits){
                            if([bot.UUID isEqualToString:botAddress] && ![botList containsObject:bot]){
                                [botList addObject:bot];
                            }
                        }
                        for(MeeperBot *bot in _driveScreen.connectedMotors){
                            if([bot.UUID isEqualToString:botAddress] && ![botList containsObject:bot]){
                                [botList addObject:bot];
                            }
                        }
                    }else{
                        if([[botAddress uppercaseString] containsString:@"BOT"]){
                            [botList removeAllObjects];
                            [botList addObjectsFromArray:_driveScreen.items];
                            [botList addObjectsFromArray:_driveScreen.sharedBots];
                            //botList = _driveScreen.items;
                        }
                        if([[botAddress uppercaseString] containsString:@"CIRCUIT"]){
                            //botList = _driveScreen.connectedCircuits;
                            [botList removeAllObjects];
                            [botList addObjectsFromArray:_driveScreen.connectedCircuits];
                            [botList addObjectsFromArray:_driveScreen.sharedCircuits];
                        }
                        if([[botAddress uppercaseString] containsString:@"MOTOR"]){
                            botList = _driveScreen.connectedMotors;
                        }
                    }
                }
                if(seperated2.count > 1){
                    botCommand = seperated[0];
                    duration = [seperated2[0] integerValue];
                    speed = [seperated2[1] stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                }
            } else if([[command uppercaseString]containsString:@"TOGGLE"]){
                NSArray *seperated = [command componentsSeparatedByString:@"("];
                NSArray *seperated2 = [seperated[1] componentsSeparatedByString:@","];
                
                for(int i = 2; i < seperated.count; i++){
                    
                    NSString *botAddress;
                    if([seperated[i] containsString:@"#?"]){
                        NSRange r1 = [seperated[i] rangeOfString:@"#?"];
                        NSRange r2 = [seperated[i] rangeOfString:@"!"];
                        NSRange rSub = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
                        botAddress = [seperated[i] substringWithRange:rSub];
                    }else{
                        botAddress = seperated[i];
                    }
                    
                    if([botAddress containsString:@"-"]){
                        for(MeeperBot *bot in _driveScreen.connectedCircuits){
                            if([bot.UUID isEqualToString:botAddress] && ![botList containsObject:bot]){
                                [botList addObject:bot];
                            }
                        }
                        for(MeeperBot *bot in _driveScreen.sharedCircuits){
                            if([bot.UUID isEqualToString:botAddress] && ![botList containsObject:bot]){
                                [botList addObject:bot];
                            }
                        }
                        
                    }else{
                        //botList = _driveScreen.connectedCircuits;
                        [botList removeAllObjects];
                        [botList addObjectsFromArray:_driveScreen.connectedCircuits];
                        [botList addObjectsFromArray:_driveScreen.sharedCircuits];
                    }
                }
                
                botCommand = seperated[0];
                if([seperated2[0] containsString:@"true"]){
                    duration = 9898;
                }else{
                    duration = 0;
                }
                speed = [seperated2[1] stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else{
                NSArray *seperated = [command componentsSeparatedByString:@"("];
                NSArray *seperated2 = [seperated[1] componentsSeparatedByString:@")"];
                
                for(int i = 2; i < seperated.count; i++){
                    NSLog(@"%@", seperated[i]);
                    NSArray *botAddressSeperator = [seperated[i] componentsSeparatedByString:@","];
                    NSString *refinedList = [botAddressSeperator[1] stringByTrimmingCharactersInSet:
                                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];

                    for(MeeperBot *bot in _driveScreen.items){
                        if([bot.UUID isEqualToString:refinedList]){
                            [botList addObject:bot];
                        }
                    }
                    
                    for(MeeperBot *bot in _driveScreen.sharedBots){
                        if([bot.UUID isEqualToString:refinedList]){
                            [botList addObject:bot];
                        }
                    }
                }
                botCommand = seperated[0];
                duration = [seperated2[0] integerValue];
            }
            
            BotCommand *cloneCmd = [[BotCommand alloc] init];
            cloneCmd.command = botCommand;
            cloneCmd.duration = [NSNumber numberWithInteger:duration];
            cloneCmd.iterations = [NSNumber numberWithInteger:iterations];
            cloneCmd.botList = botList;
            cloneCmd.listOrdinal = ordinal;
            cloneCmd.speed = speed;
            
            if(nonRepeating){
                [_commandsToBeExecuted insertObject:cloneCmd atIndex:_commandsToBeExecuted.count];
            }else{
                [_alwaysRepeatCommands insertObject:cloneCmd atIndex:_alwaysRepeatCommands.count];
            }
            NSLog(@"alwaysRepeatCommands: %@, commandsExecuted: %@", _alwaysRepeatCommands, _commandsToBeExecuted);
        }
    }
}

-(void) postCommand :(BotCommand*) botCommand
{
    
    bool isBlockly = true;
    NSDictionary *cmdInfo;
    
    
    NSLog(@"posting command %@",botCommand.command);
    
    cmdInfo = [[NSDictionary alloc] initWithObjectsAndKeys:botCommand.command,@"command",botCommand.duration,@"duration", botCommand.botList, @"botlist", botCommand.speed, @"speed", @"true",@"isblockly", nil];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"botCommand"
     object:self
     userInfo:cmdInfo
     ];
}

-(void) processCurrentCommand
{
    BotCommand *command = [self getNextCommand];
    
    [self processCurrentCommand:command];
}

-(BotCommand*) getNextCommand {
    
    //return next command for execution
    
    if(_currentCmd < _commandsToBeExecuted.count )
    {
        BotCommand *cmd = [_commandsToBeExecuted objectAtIndex:_currentCmd];
        _currentCmd++;
        return cmd;
    } else {
        return nil;
    }
    
    
}

-(void) processCurrentCommand :(BotCommand*) command
{
    //this function is called by a notification after previous command is finished (after pioStop is issued)
    
    if(!_stopCode)
    {
        if(command)
        {
            //post command
            [self postCommand:command];
        }
        else
        {
            if(_repeatForever){
                _commandsToBeExecuted = _alwaysRepeatCommands;
                
                _currentCmd = 0;
                BotCommand *command = [_commandsToBeExecuted objectAtIndex:0];
                _currentCmd++;
                command.currentCommand = YES;
                
                [self postCommand:command];
                
            }else{
                [self resetRequests];
            }
        }
    }
    
    
}

- (IBAction) openSaveView{
    if(_saveView.isHidden){
        _saveView.hidden = false;
    }
}

- (IBAction) closeSaveView{
    if(!_saveView.isHidden){
        _saveView.hidden = true;
        _routineText.text = @"";

        [_routineText resignFirstResponder];
    }
}

- (IBAction) saveRoutine{
    if(_routineText.text.length > 0){
        [_webView evaluateJavaScript:(@"saveCode()") completionHandler: nil];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid Name" message:@"Please enter a name for your code." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }
}

- (IBAction) saveRoutineCloud{
    [_webView evaluateJavaScript:(@"cloudSaveCode()") completionHandler: nil];
}

-(IBAction)openLoadView{
    if(_blocklyLoadView.isHidden){
        _blocklyList = [[meeperDB sharedInstance] loadBlockly :false];
        [_nameTable reloadData];
        _blocklyLoadView.hidden = false;
    }
}

-(IBAction)closeLoadView{
    if(!_blocklyLoadView.isHidden){
        _blocklyLoadView.hidden = true;
    }
}

-(IBAction) deleteRoutine :(id) sender
{
    if(sender)
    {
        UIButton *deleteButton = (UIButton*) sender;
        NSMutableArray *blockly = _blocklyList[deleteButton.tag];
        NSString *name = blockly[0];
        [_blocklyList removeObjectAtIndex:deleteButton.tag];
        
        [[meeperDB sharedInstance] deleteBlockly: name];
        
        [_nameTable reloadData];
    }
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - tableView stuff
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    if([tableView isEqual:_userListTable]){
        return _userList.count;
    }else{
        if(_blocklyList.count > 0){
            _nameTable.hidden = false;
            _noCodeFound.hidden = true;
        }else{
            _nameTable.hidden = true;
            _noCodeFound.hidden = false;
        }
        
        return _blocklyList.count;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if(![tableView isEqual:_userListTable]){
        [self loadWorkspace:[_blocklyList objectAtIndex:indexPath.row]];
        [self closeLoadView];
    }
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    if([tableView isEqual:_userListTable]){
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
    }else{
        BlocklyNameCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
        
        if(!cell){
            UIViewController *temporaryController = [[UIViewController alloc] initWithNibName:@"BlocklyNameCell" bundle:nil];
            // Grab a pointer to the custom cell.
            cell = (BlocklyNameCell *)temporaryController.view;
        }
        
        NSMutableArray *blockly = [_blocklyList objectAtIndex:indexPath.row];
        cell.blocklyName.text = blockly[0];
        cell.backgroundColor = [UIColor clearColor];
        cell.deleteButton.tag = indexPath.row;
        return cell;
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 40;
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

-(IBAction) showBlocklyView
{
    [self resetRequests];
    [self closeFlyOutView];
}

-(IBAction) showCodeView
{
    [self resetRequests];
    [_driveScreen setBlocklyOpen:false];
    [self showBotCode];
}

-(IBAction)showComicView{
    [self resetRequests];
    [_driveScreen setBlocklyOpen:false];
    [self showComic];
}

-(IBAction) showActivitiesView{
    [self resetRequests];
    [_driveScreen setBlocklyOpen:false];
    [self showActivity];
}

-(IBAction) showNewsView{
    [self resetRequests];
    [_driveScreen setBlocklyOpen:false];
    [self showNews];
}

-(IBAction) showControllerView{
    [self resetRequests];
    [_driveScreen setBlocklyOpen:false];
    [self showController];
}

-(void) showBotCode{
    
    [self dismissViewControllerAnimated:NO completion:^{
        BotCommand *beginLoop = [[BotCommand alloc] init];
        beginLoop.command = kBEGIN_LOOP;
        beginLoop.iterations = @2;
        
        CGRect frame = self->_driveScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        self->_driveScreen.botCodeVC = [[BotCodeViewController alloc] initWithDriveScreen:_driveScreen];
        self->_driveScreen.botCodeVC.driveScreen = self->_driveScreen;
        //vc.driveScreen = self;
        self->_driveScreen.botCodeVC.view.frame = frame;
        [self->_driveScreen.botCodeVC clearCode];
        self->_driveScreen.botCodeVC.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_driveScreen presentViewController:self->_driveScreen.botCodeVC animated:NO completion:nil];
        
    }];
}


-(IBAction) showComic
{
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closeFlyOutView];
        
        ComicLaunchViewController *vc;
        
        CGRect frame = self->_driveScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[ComicLaunchViewController alloc] initWithDriveScreen:_driveScreen];
        
        vc.view.frame = frame;
        vc.drivingScreen = self->_driveScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_driveScreen presentViewController:vc animated:NO completion:nil];
    }];
}

-(IBAction) showActivity
{
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closeFlyOutView];
        
        ActivityLaunchViewController *vc;
        
        CGRect frame = self->_driveScreen.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[ActivityLaunchViewController alloc] initWithDriveScreen:_driveScreen];
        
        vc.view.frame = frame;
        vc.drivingScreen = self->_driveScreen;
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 0;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionPush;
        transition.subtype = kCATransitionFade;
        [self->_driveScreen.view.window.layer addAnimation:transition forKey:nil];
        [self->_driveScreen presentViewController:vc animated:NO completion:nil];
    }];
}

-(IBAction)showNews{
    [self dismissViewControllerAnimated:NO completion:^{
        NewsLaunchViewController *vc;
        
        CGRect frame = self.view.frame;
        frame.size.height = frame.size.height/2;
        frame.size.width = frame.size.width/2;
        
        vc.view.frame = CGRectMake(0,0,0,0);
        vc = [[NewsLaunchViewController alloc] initWithDriveScreen:_driveScreen];
        vc.view.frame = frame;
        vc.drivingScreen = self->_driveScreen;
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

-(IBAction)showController{
    
    [self dismissViewControllerAnimated:NO completion:^{
        [self closeFlyOutView];
        
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

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait; // or Right of course
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

/// Handle window.prompt() with a native dialog.
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *result))completionHandler{
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:prompt message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = defaultText;
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    NSString *okTitle = NSLocalizedString(@"OK", @"OK button title");
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:(okTitle) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        UITextField *textInput = alert.textFields[0];
        
        completionHandler(textInput.text);
        NSLog(@"textInput.text: %@", textInput.text);
    }];
    [alert addAction:okAction];
    
    NSString *cancelTitle = NSLocalizedString(@"Cancel", @"Cancel button title");
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:(cancelTitle) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
}

- (BOOL)connected
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    return networkStatus != NotReachable;
}

-(IBAction) cloudSave{
    [_webView evaluateJavaScript:(@"cloudSaveCode()") completionHandler: nil];
}

-(NSString*) generateRandomString{
    NSString *data = @"23456789ABCDEFGHJKMNPQRSTUVWXYZ";
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity: 4];
    
    for (int i=0; i<4; i++) {
        [randomString appendFormat: @"%C", [data characterAtIndex: arc4random_uniform([data length])]];
    }
    
    FIRDatabaseReference *overviewRef = [_ref child:@"Blockly"];
    
    NSMutableArray *blocklyList = [[NSMutableArray alloc] init];
    
    [overviewRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        NSDictionary *postDict = snapshot.value;
        
        bool foundCode = false;
        for (NSString *key in postDict) {
            NSDictionary *value = postDict[key];
            [blocklyList addObject:value];
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
    
    return randomString;
}

-(IBAction) closeCloudSaveView{
    _cloudSaveLayout.hidden = true;
    [self closeSaveView];
}

-(IBAction) openCloudDownloadView{
    _cloudLoadLayout.hidden = false;
    
}

-(IBAction) searchDatabase{
    if([self connected]){
        FIRDatabaseReference *overviewRef = [_ref child:@"Blockly"];
        
        NSMutableArray *blocklyList = [[NSMutableArray alloc] init];
        
        [overviewRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
            NSDictionary *postDict = snapshot.value;
            
            NSString *xml;
            
            bool foundCode = false;
            for (NSString *key in postDict) {
                NSDictionary *value = postDict[key];
                [blocklyList addObject:value];
                for(NSString *Itemp in value){
                    id value2 = value[Itemp];
                    if([[Itemp uppercaseString] isEqualToString:@"CODE"]){
                        if([[value2 uppercaseString] isEqualToString:[self->_loadCodeLabel.text uppercaseString]]){
                            foundCode = true;
                            break;
                        }
                    }
                }
                if(foundCode){
                    for(NSString *Itemp in value){
                        if([[Itemp uppercaseString] isEqualToString:@"XML"]){
                            xml = value[Itemp];
                            break;
                        }
                    }
                    break;
                }
            }
            
            if(foundCode){
                NSString *message = [NSString stringWithFormat:@"cloudLoadCode('%@','%@')", xml, [self->_loadCodeLabel.text uppercaseString]];
                [self->_webView evaluateJavaScript:(message) completionHandler: nil];
                [self closeCloudLoadView];
            }else{
                NSString *message = [NSString stringWithFormat:@"No Blockly code was found with code %@", self->_loadCodeLabel.text];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Code Not Found" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
                [alert show];
            }
        }];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Internet" message:@"An internet connection is required to download code." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
    }
}

-(IBAction)closeCloudLoadView{
    _loadCodeLabel.text = @"";
    _cloudLoadLayout.hidden = true;
    [_loadCodeLabel resignFirstResponder];
}

-(IBAction) openRenameView : (id)sender{
    nameCellToChange = (UITableViewCell *)[[(UIView *)sender superview] superview];
    _renameTextField.text = nameCellToChange.blocklyName.text;
    oldName = nameCellToChange.blocklyName.text;
    _blocklyLoadView.hidden = true;
    _renameView.hidden = false;
}

-(IBAction)closeRenameView{
    _renameView.hidden = true;
    _renameTextField.text = @"";
    [_renameTextField resignFirstResponder];
}

-(IBAction)renameCode{
    if(_renameTextField.text.length > 0){
        [[meeperDB sharedInstance] renameBlocklyRoutine:_renameTextField.text :oldName];
        [self closeRenameView];
    }
}

-(IBAction) openAreYouSure : (id)sender{
    deleteId = sender;
    //_blocklyLoadView.hidden = true;
    _areYouSureView.hidden = false;
}

-(IBAction)closeAreYouSure{
    _areYouSureView.hidden = true;
    deleteId = NULL;
}

-(IBAction)yesDelete{
    if(deleteId)
    {
        UIButton *deleteButton = (UIButton*) deleteId;
        NSMutableArray *blockly = _blocklyList[deleteButton.tag];
        NSString *name = blockly[0];
        [_blocklyList removeObjectAtIndex:deleteButton.tag];
        
        [[meeperDB sharedInstance] deleteBlockly: name];
        
        [_nameTable reloadData];
    }
    [self closeAreYouSure];
}

-(void)loadUserCode:(NSString *)code{
    NSString *message = [NSString stringWithFormat:@"cloudLoadCode('%@','%@')", code, NULL];
    [self->_webView evaluateJavaScript:(message) completionHandler: nil];
}

-(void)setDriveScreen:(MPR10ViewController *)screen{
    _driveScreen = screen;
    [_driveScreen setBlocklyOpen:true];
    [_driveScreen setBlocklyView:self];
}

-(void)sendUserData:(NSString*)data{

    self.codeTextView.text = @"Generating code...";
    
    // Request code generation for the workspace
    [_webView evaluateJavaScript:(@"showCode()") completionHandler: nil];
    
    if([self connected]){
        
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd-MMM-yyyy"];
        
        if(_driveScreen.userIsActive){
            [[[[_ref child:@"ControllerV2"] child:_driveScreen.joinCode] child:@"codeInfo"] setValue:@{@"code" : _driveScreen.joinCode, @"id" : [[NSUUID UUID] UUIDString], @"info": data, @"mode": @"blockly", @"date" : [dateFormatter stringFromDate:[NSDate date]]}];
        }
    }
}

- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}


- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    [_routineText resignFirstResponder];
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

-(void) loadBots{
    
    NSMutableArray *botNameList = [[NSMutableArray alloc] init];
    NSMutableArray *botUUIDList = [[NSMutableArray alloc] init];
    NSMutableArray *circuitNameList = [[NSMutableArray alloc] init];
    NSMutableArray *circuitUUIDList = [[NSMutableArray alloc] init];
    NSMutableArray *motorNameList = [[NSMutableArray alloc] init];
    NSMutableArray *motorUUIDList = [[NSMutableArray alloc] init];
    
    for(MeeperBot *bot in _driveScreen.items){
        NSString *botName = [[@"'" stringByAppendingString:bot.name] stringByAppendingString:@"'"];
        NSString *botUUID = [[@"" stringByAppendingString:[bot.peripheral.identifier UUIDString]] stringByAppendingString:@""];
        [botNameList addObject:botName];
        [botUUIDList addObject:botUUID];
    }
    
    for(MeeperBot *bot in _driveScreen.sharedBots){
        NSString *botName = [[@"'" stringByAppendingString:bot.name] stringByAppendingString:@"'"];
        NSString *botUUID = [[@"" stringByAppendingString:bot.UUID] stringByAppendingString:@""];
        [botNameList addObject:botName];
        [botUUIDList addObject:botUUID];
    }
    
    for(MeeperBot *circuit in _driveScreen.connectedCircuits){
        NSString *circuitName = [[@"'" stringByAppendingString:circuit.name] stringByAppendingString:@"'"];
        NSString *circuitUUID = [[@"" stringByAppendingString:[circuit.peripheral.identifier UUIDString]] stringByAppendingString:@""];
        [circuitNameList addObject:circuitName];
        [circuitUUIDList addObject:circuitUUID];
    }
    
    for(MeeperBot *circuit in _driveScreen.sharedCircuits){
        NSString *circuitName = [[@"'" stringByAppendingString:circuit.name] stringByAppendingString:@"'"];
        NSString *circuitUUID = [[@"" stringByAppendingString:circuit.UUID] stringByAppendingString:@""];
        [circuitNameList addObject:circuitName];
        [circuitUUIDList addObject:circuitUUID];
    }
    
    for(MeeperBot *motor in _driveScreen.connectedMotors){
        NSString *motorName = [[@"'" stringByAppendingString:motor.name] stringByAppendingString:@"'"];
        NSString *motorUUID = [[@"" stringByAppendingString:[motor.peripheral.identifier UUIDString]] stringByAppendingString:@""];
        [motorNameList addObject:motorName];
        [motorUUIDList addObject:motorUUID];
    }
    NSLog(@"botName: %@, botUUID: %@", botNameList, botUUIDList);
    NSString *justBotListString = [NSString stringWithFormat:@"%@,%@,%@,%@,%@,%@", botNameList, botUUIDList,circuitNameList,circuitUUIDList,motorNameList,motorUUIDList];
    NSString *firstReplace = [justBotListString stringByReplacingOccurrencesOfString:@"(" withString:@"["];
    NSString *lastReplace = [firstReplace stringByReplacingOccurrencesOfString:@")" withString:@"]"];
    NSString *showBotJavascript = [[@"showBots(" stringByAppendingString:lastReplace] stringByAppendingString:@")"];
    NSString *finalString = [showBotJavascript stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    [_webView evaluateJavaScript:(finalString) completionHandler:nil];
}
@end
