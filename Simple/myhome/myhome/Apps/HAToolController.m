//
//  HAToolController.m
//  myhome
//
//  Created by FudonFuchina on 2016/12/3.
//  Copyright © 2016年 fuhope. All rights reserved.
//

#import "HAToolController.h"
#import "FSImageLabelView.h"
#import "FSHardwareInfoController.h"
#import "FSAccessController.h"
#import "FSMoveLabel.h"
#import "FSBirthdayController.h"
#import "FSHTMLController.h"
#import "FSPdf.h"
#import "FSDBMaster.h"
#import "FSAccountConfiger.h"
#import "FSCryptor.h"
#import "FSAccountsController.h"
#import "FSDiaryController.h"
#import "FSPwdBookController.h"
#import "FSDBTool.h"
#import "FSShare.h"
#import "FSAddDiaryController.h"
#import "FSAddPwdBookController.h"
#import "FSCryptorSupport.h"
#import "FSPasswordController.h"
#import "FSJZAPP.h"
#import "FSTransferDatabaseController.h"
#import "FSReceiveDatabaseController.h"
#import "FSRestartAppController.h"
#import "FSAppConfig.h"
#import "FSCommonGroupController.h"
#import "FSDBCardsController.h"
#import "FSAddCardsController.h"
#import "FSABOverviewController.h"
#import <FSUIKit.h>
#import <FSDate.h>
#import "AppDelegate.h"
#import "FSBestAccountController.h"
#import "FSAlertAPI.h"
#import "FSDiaryAPI.h"
#import "FSInventoryController.h"
#import "FSTrack.h"
#import "FSTrackKeys.h"
#import "FSKitDuty.h"
#import "FSUseGestureView+Factory.h"
#import "FSKeyValueCryptor.h"
#import "FSBoardView.h"
#import "UIView+Tap.h"
#import "FSRouter.h"
#import "FSPwdModel.h"
#import "FSApp.h"
#import "FSJZStartPageView.h"
#import "FSWebKitController.h"
#import <MessageUI/MessageUI.h>
#import "FSBirthAPI.h"

//#import "FSEmptyView.h"

@interface HAToolController ()

@property (nonatomic,strong) FSMoveLabel                    *moveLabel;
@property (nonatomic,assign) NSInteger                      alerts;
@property (nonatomic,assign) NSInteger                      births;
@property (nonatomic,strong) Tuple3                         *diaryTuple;
@property (nonatomic,assign) BOOL                           isCurrentShow;

@end

@implementation HAToolController{
    BOOL                _haveUnlockedGesture;
    BOOL                _justOneTime;
    NSInteger           _delaySeconds;
    BOOL                _shouldOutput;
    UILabel             *_timeLabel;
    FSBoardView         *_boardView;
    UIView              *_diaryView;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isCurrentShow = YES;
        
        [NSNotificationCenter.defaultCenter addObserverForName:FSAppManagerLockScreenNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            UITabBarController *tab = self.navigationController.tabBarController;
            BOOL needLock = NO;
            for (UINavigationController *v in tab.viewControllers) {
                if (v.viewControllers.count > 1) {
                    needLock = YES;
                }
            }
            
            if (needLock == NO) {
                return;
            }

            [FSUseGestureView verify:self.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:nil cancel:^{
                for (UINavigationController *v in tab.viewControllers) {
                    [v popToRootViewControllerAnimated:YES];
                }
            }];
        }];
        
        [NSNotificationCenter.defaultCenter addObserverForName:@"JZChangeDelaySecondsNotification" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [self delaySecondsEvent];
        }];
        
        [NSNotificationCenter.defaultCenter addObserverForName:@"HomeHandleForShowViewNotification" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
            NSString *obj = note.object;
            [self showFullView:obj];
        }];
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(shouldOutput) name:_Notifi_sendSqlite3 object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:_Notifi_registerLocalNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(needUnlock) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boardViewNotification:) name:FSBoardViewClickNotification object:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)systemStartConfigs{
    AppDelegate *app = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [app handleViews];
    [app handleParts];    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if (self.navigationController.navigationBarHidden) {
        self.navigationController.navigationBarHidden = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    UITabBar.appearance.translucent = NO;// iOS12，UITabBar跳动的bug
    _isCurrentShow = YES;
    
    if (!_justOneTime) {
        _justOneTime = YES;
        [self systemStartConfigs];
    }else{
        [UIView animateWithDuration:.3 animations:^{
            self.scrollView.contentOffset = CGPointZero;
        }];
        
        [self mustSeeOneDiaryEveryday:NO];
    }
    
    _fs_dispatch_global_queue_async(^{
        [self checkFutureAlerts];
    });
    
    UIApplication *application = [UIApplication sharedApplication];
    if (application.applicationIconBadgeNumber) {
        application.applicationIconBadgeNumber = 0;
    }
    
    if (_shouldOutput) {
        _shouldOutput = NO;
        
        __block BOOL notExport = NO;
        _fs_dispatch_global_main_queue_async(^{
            NSString *eSwitch = [FSAppConfig objectForKey:_appCfg_exportSwitch];
            notExport = [eSwitch boolValue];
        }, ^{
            if (notExport == NO) {
                [self exportFile];
            }
        });
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _isCurrentShow = NO;
}

- (void)showFullView:(NSString *)value {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 60)];
    label.backgroundColor = FS_GreenColor;
    label.text = value;
    label.userInteractionEnabled = YES;
    label.numberOfLines = 2;
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    [UIApplication.sharedApplication.delegate.window addSubview:label];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapFullEvent:)];
    [label addGestureRecognizer:tap];
    
    [UIView animateWithDuration:.3 animations:^{
        label.top = self.view.frame.size.height - FS_TabBar_Height;
    }];
}

- (void)tapFullEvent:(UITapGestureRecognizer *)tap {
    UIView *label = tap.view;
    [label removeFromSuperview];
    return;
//    [FSUIKit alert:UIAlertControllerStyleAlert controller:self title:@"隐藏此视图" message:nil actionTitles:@[@"确定"] styles:@[@(UIAlertActionStyleDefault)] handler:^(UIAlertAction *action) {
//        UIView *label = tap.view;
//        [UIView animateWithDuration:.3 animations:^{
//            label.top = self.view.frame.size.height;
//        } completion:^(BOOL finished) {
//            [label removeFromSuperview];
//        }];
//    }];
}

- (void)shouldOutput{
    _shouldOutput = YES;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    // 显示启动页
    __weak typeof(self)this = self;
    [self showStartPage:^{
        __strong typeof(this)self = this;
        _fs_dispatch_global_main_queue_async(^{
            [self delaySecondsEvent];
        }, ^{
            [self checkCorePasswordExist];
            [self mustSeeOneDiaryEveryday:NO];
        });
    }];
}

- (void)showStartPage:(void(^)(void))startPageWillDismiss {
    FSJZStartPageView *pView = [[FSJZStartPageView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.tabBarController.view addSubview:pView];
    
    pView.willDissmiss = ^(FSJZStartPageView * _Nonnull bView) {
        if (startPageWillDismiss) {
            startPageWillDismiss();
        }
    };
}

- (void)delaySecondsEvent{
    NSInteger t = [FSAppConfig objectForKey:_appCfg_lockTime].integerValue;
    if (t < 0) {
        t = 0;
    }else if (t > 120){
        t = 120;
    }
    self -> _delaySeconds = t;
    FSAppManager.sharedInstance.delay = t;
}

- (void)checkCorePasswordExist{
    __block NSString *password = nil;
    _fs_dispatch_global_main_queue_async(^{
        NSString *v = _fs_userDefaults_objectForKey(_UDKey_ImportNewDB);
        BOOL importNewDB = [v boolValue];
        if (importNewDB) {
            [self toSetCorePassword];
            return;
        }
        password = [FSCryptorSupport localUserDefaultsCorePassword];
    }, ^{
        if (!_fs_isValidateString(password)) { // 这是没有数据库的情况
            [self toSetCorePassword];
        }else{
            [self homeDesignViews];
        }
    });
}

- (void)toSetCorePassword{
    dispatch_async(dispatch_get_main_queue(), ^{
        FSPasswordController *password = [[FSPasswordController alloc] init];
        password.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [self presentViewController:password animated:YES completion:nil];
        __weak typeof(self)this = self;
        password.callback = ^(FSPasswordController *bVC) {
            [bVC dismissViewControllerAnimated:YES completion:nil];
            [this homeDesignViews];
        };
    });
}

- (void)restartApp{
    _fs_userDefaults_setObjectForKey(@"1", _UDKey_ImportNewDB);
    [self restartAppPage];
}

- (void)restartAppPage{
    FSRestartAppController *rs = [[FSRestartAppController alloc] init];
    rs.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [self presentViewController:rs animated:YES completion:nil];
}

- (void)usersAnalyze{
    NSString *key = [[NSString alloc] initWithFormat:@"%@_UserAnalyze",NSStringFromClass(self.class)];
    NSString *value = _fs_userDefaults_objectForKey(key);
    if (_fs_isValidateString(value)) {
        [FSTrack event:_UMeng_Event_old_user];
    }else{
        [FSTrack event:_UMeng_Event_start];
        _fs_userDefaults_setObjectForKey(key, key);
    }
    BOOL isHans = [FSKit isChineseEnvironment];
    if (isHans) {
        [FSTrack event:_UMeng_Event_envir_hans];
    }else{
        [FSTrack event:_UMeng_Event_envir_english];
    }
}

- (void)nearbyAction{
//    BOOL wifi = FSKitDuty.isWiFiEnabled;
//    if (!wifi) {
//        [FSUIKit showAlertWithMessage:@"请打开手机WIFI功能" controller:self];
//        return;
//    }
    
    NSString *send = @"我是发送方";
    NSString *rece = @"我是接收方";
    NSNumber *type = @(UIAlertActionStyleDefault);
    [FSUIKit alert:UIAlertControllerStyleActionSheet controller:self title:nil message:nil actionTitles:@[send,rece] styles:@[type,type] handler:^(UIAlertAction *action) {
        if ([action.title isEqualToString:send]) {
            FSTransferDatabaseController *m = [[FSTransferDatabaseController alloc] init];
            [self.navigationController pushViewController:m animated:YES];
        }else if ([action.title isEqualToString:rece]){
            FSReceiveDatabaseController *r = [[FSReceiveDatabaseController alloc] init];
            [self.navigationController pushViewController:r animated:YES];
            __weak typeof(self)this = self;
            r.hasReceivedData = ^(FSReceiveDatabaseController *bVC) {
                [bVC.navigationController popToViewController:this animated:YES];
                [this restartApp];
            };
        }
    }];
}

- (void)needUnlock{
    if (self.navigationController.viewControllers.count == 1) {
        _haveUnlockedGesture = NO;
    }
}

- (void)homeDesignViews{
    _fs_dispatch_main_queue_async(^{
        [self homeDesignViewsInMainThread];
    });    
}

- (void)showNotice{
    [FSRouter routeClass:@"FSNoticeViewController" params:nil completion:nil];
}

- (void)homeDesignViewsInMainThread{
//    [self monthTipsToAppStoreToGrade];
    
    UIBarButtonItem *nearby = [[UIBarButtonItem alloc] initWithTitle:@"说明" style:UIBarButtonItemStylePlain target:self action:@selector(showNotice)];
    self.navigationItem.leftBarButtonItem = nearby;
    
    self.title = FSKit.appName;
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"数据库" style:UIBarButtonItemStylePlain target:self action:@selector(bbiAction)];
    self.navigationItem.rightBarButtonItem = bbi;
    
    _boardView = [[FSBoardView alloc] initWithFrame:CGRectMake(0, 40, self.view.frame.size.width, 0)];
    [self.scrollView addSubview:_boardView];
    [self showTimeLabel];
    _fs_dispatch_main_queue_async(^{
        [self poet];        
    });
}

- (void)showTimeLabel{
    __block NSString *s = nil;
    _fs_dispatch_global_main_queue_async(^{
        NSArray *dateArray = [FSDate chineseCalendarForDate:[NSDate date]];
        NSString *nl = [[NSString alloc] initWithFormat:@"%@%@",dateArray[1],dateArray[2]];
       
        NSDateComponents *c = [FSDate componentForDate:[NSDate date]];
        NSString *xl = [[NSString alloc] initWithFormat:@"%@-%@-%@\n",@(c.year),[FSKit twoChar:c.month],[FSKit twoChar:c.day]];
        s = [[NSString alloc] initWithFormat:@"%@%@・%@",xl,nl,[FSDate ChineseWeek:c.weekday]];
    }, ^{
        if (!self->_timeLabel) {
            self ->_timeLabel = [[UILabel alloc] init];
            self ->_timeLabel.textAlignment = NSTextAlignmentCenter;
            self ->_timeLabel.font = [UIFont systemFontOfSize:18];
            CGFloat rgb = 228 / 255.0;
            self ->_timeLabel.textColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:1.0];
            self ->_timeLabel.numberOfLines = 0;
        }
        self->_timeLabel.frame = CGRectMake(0, self->_boardView.frame.origin.y + self->_boardView.frame.size.height + 50, WIDTHFC, 80);
        self ->_timeLabel.text = s;
        [self.scrollView addSubview:self ->_timeLabel];
    });
}

- (void)boardViewNotification:(NSNotification *)notification{
    Tuple3 *t = notification.object;
    [self actionForType:t];
}

- (void)poet{
    UIView *top = [[UIView alloc] initWithFrame:CGRectMake(0, - 45, WIDTHFC, 45)];
    [self.scrollView addSubview:top];
    
    UILabel *poet = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, WIDTHFC, 40)];
    poet.text = @"勿以恶小而为之\n勿以善小而不为";
    poet.textAlignment = NSTextAlignmentCenter;
    poet.font = [UIFont systemFontOfSize:16];
    CGFloat rgb = 228 / 255.0;
    poet.textColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:1.0];
    poet.numberOfLines = 0;
    [top addSubview:poet];
}

- (void)handleAppBecomeActive{
    if (self.isCurrentShow) {
        [self checkFutureAlerts];
        [self showTimeLabel];
    }
}

- (void)checkFutureAlerts{
    NSDate *today = [NSDate date];
    NSInteger t = [_fs_userDefaults_objectForKey(_UDKey_FirstPageShow) integerValue];
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:t];
    BOOL isTheSameDay = [FSDate isTheSameDayA:date b:today];
    if (isTheSameDay)
        return;
    
    [FSAlertAPI todoAlertsOnlyCount:YES password:FSCryptorSupport.localUserDefaultsCorePassword callback:^(NSArray *list, NSInteger count) {
        self.alerts = count;
        [self checkBirthday];
    }];
}

- (void)checkBirthday {
    [FSBirthAPI todayBirthdaysCount:^(NSInteger count) {
        self.births = count;
        [self showMessage];
    }];
}

- (void)showMessage{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSMutableString *message = [[NSMutableString alloc] init];
        if (self.alerts) {
            [message appendFormat:@"你的'待办'有%ld件事需要处理",self.alerts];
        }
        
        if (self.births) {
            if (self.alerts) {
                [message appendFormat:@"，还有%ld个朋友过生日，快去祝TA生日快乐吧!",self.births];
            } else {
                [message appendFormat:@"今天有%ld个朋友过生日，快去祝TA生日快乐吧!",self.births];
            }
        }
        
        static NSString *sMessage = nil;
        if ([sMessage isEqualToString:message]) {
            if (self.moveLabel.hidden) {
                self.moveLabel.hidden = NO;
            }
            return;
        }
        sMessage = message;
        self.moveLabel.text = message;
        [self.moveLabel start];
        self.moveLabel.hidden = NO;
    });
}

- (FSMoveLabel *)moveLabel {
    if (!_moveLabel) {
        _moveLabel = [[FSMoveLabel alloc] initWithFrame:CGRectMake(0, _fs_statusAndNavigatorHeight(), WIDTHFC, 50)];
        _moveLabel.textColor = HAAPPCOLOR;
        [self.view addSubview:_moveLabel];
        __weak typeof(self)this = self;
        _moveLabel.tapBlock = ^(FSMoveLabel *bLabel) {
            if (this.alerts && (this.births == 0)) {    // 只有提醒
                [FSUseGestureView verify:this.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
                    [this pushToAlerts];
                }];
                return;
            }
            if (this.births && (this.alerts == 0)) {    // 只有生日
                [FSUseGestureView verify:this.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
                    [this pushToBirth];
                }];
                return;
            }
            
            if (self.births > 0 && self.alerts > 0) {
                NSMutableArray *titles = [[NSMutableArray alloc] initWithObjects:@"今天不再显示", nil];
                if (this.alerts) {
                    [titles insertObject:@"待办" atIndex:0];
                }
                if (this.births) {
                    [titles insertObject:@"生日" atIndex:0];
                }
                
                NSMutableArray *types = [[NSMutableArray alloc] init];
                for (int x = 0; x < titles.count; x ++) {
                    if (x == titles.count - 1) {
                        [types addObject:@(UIAlertActionStyleDestructive)];
                    }else{
                        [types addObject:@(UIAlertActionStyleDefault)];
                    }
                }
                [FSUIKit alert:UIAlertControllerStyleActionSheet controller:this title:nil message:nil actionTitles:titles styles:types handler:^(UIAlertAction *action) {
                    [FSUseGestureView verify:this.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
                        [this flowEvent:action.title];
                    }];
                }];
            }
        };
    }
    return _moveLabel;
}

- (void)pushToAlerts{
    [FSKit pushToViewControllerWithClass:@"FSFutureAlertController" navigationController:self.navigationController param:@{@"password":FSCryptorSupport.localUserDefaultsCorePassword?:@""} configBlock:nil];
}

- (void)flowEvent:(NSString *)title{
    if ([title isEqualToString:@"待办"]) {
        [self pushToAlerts];
    }else if ([title isEqualToString:@"生日"]){
        [self pushToBirth];
    }else if ([title isEqualToString:@"今天不再显示"]){
        [FSUIKit alert:UIAlertControllerStyleActionSheet controller:self title:@"今天不再显示" message:nil actionTitles:@[@"确认"] styles:@[@(UIAlertActionStyleDestructive)] handler:^(UIAlertAction *action) {
            _fs_userDefaults_setObjectForKey(@(_fs_integerTimeIntevalSince1970()), _UDKey_FirstPageShow);
            self->_moveLabel.hidden = YES;
            [FSToast show:@"今天不再显示"];
        }];
    }
}

- (void)pushToBirth{
    FSBirthdayController *b = FSBirthdayController.alloc.init;
    b.password = FSCryptorSupport.localUserDefaultsCorePassword;
    b.showButton = (self.births > 0);
    [self.navigationController pushViewController:b animated:YES];
}

- (void)bbiAction{
    [FSUseGestureView verify:self.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
        [self bbiActionEvent];
    }];
}

- (void)bbiActionEvent{
    //    BOOL noNet = [FSKitDuty noNet];
    //    if (noNet) {
    //        [FSKit showAlertWithMessage:(@"Please open your net to export file", nil) controller:self];
    //        return;
    //    }
    
    NSString *transfer = @"转给其他手机";
    NSString *all = @"转给其他应用";
    NSString *file = @"导出文件";

    NSNumber *type = @(UIAlertActionStyleDefault);
    [FSUIKit alert:UIAlertControllerStyleActionSheet controller:self title:nil message:@"您可将数据库转移到其他渠道" actionTitles:@[transfer,all,file] styles:@[type,type,type] handler:^(UIAlertAction *action) {
        if ([action.title isEqualToString:transfer]) {
            [self nearbyAction];
        }else if ([action.title isEqualToString:all]){
            [self exportSQLite3];
            [FSTrack event:_UMeng_Event_savesql];
        }else if ([action.title isEqualToString:file]){
            [self fileOutputEvent];
        }
    }];
}

- (void)fileOutputEvent{
    NSString *password = @"密码";
    NSString *diary = @"日记";
    NSString *contacts = @"通讯录";
    
    NSNumber *type = @(UIAlertActionStyleDefault);
    [FSUIKit alert:UIAlertControllerStyleActionSheet controller:self title:@"导出文件" message:@"把数据导出到安全的渠道，注意防止泄露" actionTitles:@[password,diary,contacts] styles:@[type,type,type] handler:^(UIAlertAction *action) {
        if ([action.title isEqualToString:password]) {
            [FSDBTool sendPasswords:FSCryptorSupport.localUserDefaultsCorePassword];
            [FSTrack event:_UMeng_Event_export_password];
        }else if ([action.title isEqualToString:diary]){
            [FSDBTool sendDiary:FSCryptorSupport.localUserDefaultsCorePassword];
            [FSTrack event:_UMeng_Event_export_diary];
        }else if ([action.title isEqualToString:contacts]){
            [FSDBTool sendContacts:FSCryptorSupport.localUserDefaultsCorePassword];
            [FSTrack event:_UMeng_Event_export_contact];
        }
    }];
}

- (void)exportSQLite3{
    NSString *system = @"其他应用打开";
    NSString *wechat = @"发到微信";
    NSString *email = @"发到邮箱";
    
    NSArray *titles = @[system,wechat,email];
    NSNumber *type = @(UIAlertActionStyleDefault);
    [FSUIKit alert:UIAlertControllerStyleActionSheet controller:self title:@"导出数据库" message:nil actionTitles:titles styles:@[type,type,type] handler:^(UIAlertAction *action) {
        if ([action.title isEqualToString:wechat]) {
            [self shareToWechat];
        }else if ([action.title isEqualToString:email]){
            [self sendEmail];
        }else if ([action.title isEqualToString:system]){
            [self exportFile];
        }
    }];
}

- (void)sendEmail{
    BOOL canSendMail = [MFMailComposeViewController canSendMail];
    if (!canSendMail) {
        [FSToast show:@"手机设置邮箱后才可以反馈信息"];
        return;
    }
    NSString *path = [FSDBMaster dbPath];
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:path]){
        [FSToast show:@"没有数据"];
        return;
    }
    NSString *email = [FSAppConfig objectForKey:_appCfg_receivedEmail];
    if (!_fs_isValidateString(email)) {
        [FSToast show:@"请去【设置】里配置邮件地址"];
    }
    
    NSMutableString *body = [[NSMutableString alloc] initWithString:@"\n\t可以在邮件里转存到微云的\"QQ邮箱\"内"];
    NSString *bz = [FSJZAPP theNewestMessage];
    if (_fs_isValidateString(bz)) {
        [body insertString:[[NSString alloc] initWithFormat:@"\n\t(%@:%@)\n",@"最近",bz] atIndex:0];
    }
    long long size = [FSKit fileSizeAtPath:path];
    NSString *str = _fs_KMGUnit((NSInteger)size);
    [body appendFormat:@" (文件大小:%@)",str];
    
    NSString *date = [FSDate stringWithDate:[NSDate date] formatter:nil];
    NSString *name = [[NSString alloc] initWithFormat:@"%@.db",date];
    NSData *myData = [NSData dataWithContentsOfFile:path];
    
    [FSShare emailShareWithSubject:date on:self messageBody:body recipients:email?@[email]:nil fileData:myData fileName:name mimeType:@"db"];
}

- (void)shareToWechat{
    NSString *path = [FSDBMaster dbPath];
    [FSShare wxFileShareActionWithPath:path fileName:[[NSString alloc] initWithFormat:@"%@",[FSDate stringWithDate:[NSDate date] formatter:nil]] extension:@"db" result:^(NSString *bResult) {
        [FSToast show:bResult];
    }];
}

- (void)actionForType:(Tuple3 *)t{
    NSInteger type = [t._3 integerValue];
    if (type == FSActionTypeCalculator) {
        [self pushToMakeImages];
    } else if (type == FSActionTypeOther) {
#if DEBUG
        [FSKit pushToViewControllerWithClass:@"FSToolKitController" navigationController:self.navigationController param:nil configBlock:nil];
        
#else
        FSWebKitController *webController = [[FSWebKitController alloc] init];
        webController.urlString = @"https://m.baidu.com";
        [self.navigationController pushViewController:webController animated:YES];
#endif
    } else if (type == FSActionTypeQRCode) {
//            [self QRAction];
        [FSKit pushToViewControllerWithClass:@"FSAES256Controller" navigationController:self.navigationController param:nil configBlock:nil];
    } else{
        [FSUseGestureView verify:self.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
            [self actionForTypeExec:t type:type];
        }];
    }
}

- (void)actionForTypeExec:(Tuple3 *)t type:(NSInteger)actionType{
    switch (actionType) {
        case FSActionTypeLoanCounter:{
            [self pushToCounter];
        }break;
        case FSActionTypeBestAccount:{
            [self pushToAccounts:4];
        }break;
        case FSActionTypeTODO:{
            [self pushToAlerts];
        }break;
        case FSActionTypeBirthday:{
            [self pushToBirth];
        }break;
        case FSActionTypePassword:{
            [self seePasswords];
        }break;
        case FSActionTypeMakePassword:{
            [self cardsPush];
        }break;
        case FSActionTypeDiary:{
            [self diaryPush];
        }break;
        case FSActionTypeLocation:{
            [self pushToAccounts:3];
        }break;
        case FSActionTypeContact:{
            [FSKit pushToViewControllerWithClass:@"FSSafeContactController" navigationController:self.navigationController param:@{@"password":FSCryptorSupport.localUserDefaultsCorePassword?:@""} configBlock:nil];
        } break;
            case FSActionTypeLast:{
                FSAccessController *access = [[FSAccessController alloc] init];
                access.title = @"工具";
                access.datas = @[@{Text_Name:@"手机信息"},
                                 @{Text_Name:@"借条・欠条"},
                                 @{Text_Name:@"目录"},
                                 @{Text_Name:@"农历"},
                                 ];
                WEAKSELF(this);
                access.selectBlock = ^ (FSAccessController *bController,NSIndexPath *bIndexPath){
                    NSArray *classArray = @[@"FSHardwareInfoController",@"FSLoanReceipController",@"FSAppDocumentController",@"FSBorrowArrowController",@"FSCalculatorController",@"FSChineseCalendarController"];
                    [FSKit pushToViewControllerWithClass:classArray[bIndexPath.row] navigationController:this.navigationController param:nil configBlock:nil];
                };
                [self.navigationController pushViewController:access animated:YES];
            }break;
        default:
            break;
    }
}

- (void)pushToMakeImages {
    
}

- (void)pushToCounter{
    NSArray *datas = @[
              @{Text_Name:@"贷款计算器"},
              @{Text_Name:@"加减计算器"},
            ];
    [self pushToAccesses:@"计算工具" datas:datas classArray:nil click:^(NSInteger n) {
        if (n) {
            [self pushToAccounts:100];
        }else{
            [FSKit pushToViewControllerWithClass:@"FSLoanCounterController" navigationController:self.navigationController param:nil configBlock:nil];
        }
    }];
}

- (void)pushToAccounts:(NSInteger)type{
    FSAccountsController *acc = [[FSAccountsController alloc] init];
    acc.type = type;
    [self.navigationController pushViewController:acc animated:YES];
    __weak typeof(self)this = self;
    acc.push = ^(NSString *table, NSString *name) {
        if (type == 2) {
            FSABOverviewController *door = [[FSABOverviewController alloc] init];
            door.accountName = table;
            door.title = name;
            [this.navigationController pushViewController:door animated:YES];
        }else if (type == 4){
            FSBestAccountController *i = [[FSBestAccountController alloc] init];
            i.table = table;
            i.title = name;
            [this.navigationController pushViewController:i animated:YES];
        }else if (type == 3){
            FSInventoryController *i = [[FSInventoryController alloc] init];
            i.table = table;
            i.title = name;
            [this.navigationController pushViewController:i animated:YES];
        }else if (type == 100){
            [FSKit pushToViewControllerWithClass:@"FSASCalculatorController" navigationController:this.navigationController param:@{@"table":table} configBlock:nil];
        }
    };
}

- (void)pushToAccesses:(NSString *)title datas:(NSArray *)datas classArray:(NSArray * (^)(void))classArray click:(void (^)(NSInteger n))custom{
    FSAccessController *access = [[FSAccessController alloc] init];
    access.title = title;
    access.datas = datas;
    WEAKSELF(this);
    access.selectBlock = ^ (FSAccessController *bController,NSIndexPath *bIndexPath){
        if (custom) {
            custom(bIndexPath.row);
        }else{
            NSArray *classes = classArray();
            [FSKit pushToViewControllerWithClass:classes[bIndexPath.row] navigationController:this.navigationController param:nil configBlock:nil];
        }
    };
    [self.navigationController pushViewController:access animated:YES];
}

- (void)diaryPush{
    __weak typeof(self)this = self;
    FSCommonGroupController *group = [[FSCommonGroupController alloc] init];
    group.table = _tb_diary;
    group.isSearchShow = YES;
    group.searchPH = @"日记里的关键字";
    [self.navigationController pushViewController:group animated:YES];
    group.addData = ^ (NSString *zone,NSString *name){
        FSAddDiaryController *add = [[FSAddDiaryController alloc] init];
        add.tableName = _tb_diary;
        add.zone = zone;
        add.pwd = FSCryptorSupport.localUserDefaultsCorePassword;
        [this.navigationController pushViewController:add animated:YES];
        add.backCall = ^(FSAddDiaryController *bVC, FSDiaryModel *bModel) {
            [bVC.navigationController popViewControllerAnimated:YES];
            [this pushToDiary:zone name:name];
        };
    };
    group.seeData = ^(NSString *zone,NSString *name) {
        [this pushToDiary:zone name:name];
    };
    group.searchResult = ^(NSString *text) {
        __block NSMutableArray *results = nil;
        _fs_dispatch_global_main_queue_async(^{
            results = [FSDiaryAPI searchText:text password:FSCryptorSupport.localUserDefaultsCorePassword];
        }, ^{
            if (results.count == 0) {
                [FSToast show:@"没有搜到数据"];
                return;
            }
            FSDiaryController *diary = [[FSDiaryController alloc] init];
            diary.isSearchMode = YES;
            diary.searchResults = results;
            [this.navigationController pushViewController:diary animated:YES];
        });
    };
}

- (void)pushToDiary:(NSString *)zone name:(NSString *)name{
    FSDiaryController *diary = [[FSDiaryController alloc] initWithZone:zone name:name password:[FSCryptorSupport localUserDefaultsCorePassword]];
    [self.navigationController pushViewController:diary animated:YES];
}

- (void)seePasswords{
    FSCommonGroupController *group = [[FSCommonGroupController alloc] init];
    group.table = _tb_password;
    group.isSearchShow = YES;
    group.searchPH = @"搜索关键信息";
    [self.navigationController pushViewController:group animated:YES];
    WEAKSELF(this);
    group.seeData = ^(NSString *zone,NSString *name) {
        [this pushToPwdBook:zone name:name];
    };
    group.addData = ^(NSString *bZone,NSString *name) {
        FSAddPwdBookController *add = [[FSAddPwdBookController alloc] init];
        add.password = FSCryptorSupport.localUserDefaultsCorePassword;
        add.zone = bZone;
        [this.navigationController pushViewController:add animated:YES];
        add.addCallback = ^(FSAddPwdBookController *bVC) {
            [bVC.navigationController popViewControllerAnimated:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:_Notifi_refreshZone object:nil];
            [this pushToPwdBook:bZone name:name];
        };
    };
    
    group.searchResult = ^(NSString *text) {
        __block NSMutableArray *results = nil;
        _fs_dispatch_global_main_queue_async(^{
            results = [FSPwdModel searchText:text password:FSCryptorSupport.localUserDefaultsCorePassword];
        }, ^{
            if (results.count == 0) {
                [FSToast show:@"没有搜到数据"];
                return;
            }
            FSPwdBookController *pwd = [[FSPwdBookController alloc] init];
            pwd.isSearchMode = YES;
            pwd.searchResults = results;
            pwd.password = FSCryptorSupport.localUserDefaultsCorePassword;
            [this.navigationController pushViewController:pwd animated:YES];
        });
    };
}

- (void)pushToPwdBook:(NSString *)zone name:(NSString *)name{
    FSPwdBookController *pwd = [[FSPwdBookController alloc] init];
    pwd.zone = zone;
    pwd.name = name;
    pwd.password = FSCryptorSupport.localUserDefaultsCorePassword;
    [self.navigationController pushViewController:pwd animated:YES];
}

- (void)cardsPush{
    __weak typeof(self)this = self;
    FSCommonGroupController *group = [[FSCommonGroupController alloc] init];
    group.table = _tb_card;
    [self.navigationController pushViewController:group animated:YES];
    group.addData = ^ (NSString *zone,NSString *name){
        FSAddCardsController *add = [[FSAddCardsController alloc] init];
        add.zone = zone;
        add.password = FSCryptorSupport.localUserDefaultsCorePassword;
        [this.navigationController pushViewController:add animated:YES];
        add.callback = ^ (NSString *zone) {
            [this.navigationController popViewControllerAnimated:YES];
            [this pushToCard:zone name:name];
        };
    };
    group.seeData = ^(NSString *zone,NSString *name) {
        [this pushToCard:zone name:name];
    };
}

- (void)pushToCard:(NSString *)zone name:(NSString *)name{
    FSDBCardsController *pwd = [[FSDBCardsController alloc] init];
    pwd.zone = zone;
    pwd.name = name;
    pwd.password = FSCryptorSupport.localUserDefaultsCorePassword;
    [self.navigationController pushViewController:pwd animated:YES];
}

//- (void)monthTipsToAppStoreToGrade{
//    __block BOOL _need_show = NO;
//    _fs_dispatch_global_main_queue_async(^{
//        NSDate *today = [NSDate date];
//        NSDateComponents *c = [FSDate componentForDate:today];
//        if (c.day == 26) {
//            NSString *key = NSStringFromSelector(_cmd);
//
//            NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
//            NSString *s = [ud objectForKey:key];
//            NSTimeInterval t = [s doubleValue];
//            NSDate *latest = [[NSDate alloc] initWithTimeIntervalSince1970:t];
//            NSDateComponents *ct = [FSDate componentForDate:latest];
//            if (ct.month == c.month) {
//                return;
//            }
//            [ud setObject:@([today timeIntervalSince1970]).stringValue forKey:key];
//            [ud synchronize];
//            _need_show = YES;
//        }
//    }, ^{
//        if (_need_show) {
//            [FSUIKit alert:UIAlertControllerStyleAlert controller:self title:nil message:@"欢迎评分" actionTitles:@[@"评论"] styles:@[@(UIAlertActionStyleDefault)] handler:^(UIAlertAction *action) {
//                NSString *urlStr = @"itms-apps://itunes.apple.com/app/id1291692536";
//                UIApplication *app = [UIApplication sharedApplication];
//                NSURL *url = [NSURL URLWithString:urlStr];
//                if ([app canOpenURL:url]) {
//                    [app openURL:url];
//                    [FSTrack event:_UMeng_Event_cent_home];
//                }
//            } cancelTitle:@"下次再说" cancel:nil completion:nil];
//        }
//    });
//}

- (void)exportFile{
    NSString *filePath = [FSDBMaster dbPath];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL fileExist = [manager fileExistsAtPath:filePath];
    if (fileExist == NO) return;
    NSString *date = [FSDate stringWithDate:[NSDate date] formatter:nil];
    NSString *name = [[NSString alloc] initWithFormat:@"%@.db",date];
    NSData *myData = [NSData dataWithContentsOfFile:filePath];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    BOOL success = [myData writeToFile:path atomically:YES];
    if (!success) {
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    [[FSShare sharedInstance] openUIDocumentInteractionController:url inController:self];
}

// 每日一温
NSString *_key_day = @"everyDiary_day";
- (void)mustSeeOneDiaryEveryday:(BOOL)useAlertShowContent {
    __block NSInteger today = 0;
    __block BOOL needStep = NO;
    _fs_dispatch_global_main_queue_async(^{
        NSDate *now = [NSDate date];
        NSDateComponents *c = [FSDate componentForDate:now];
        today = c.day;
        NSInteger saved = [_fs_userDefaults_objectForKey(_key_day) integerValue];
        if (today == saved) {
            return;
        }
        needStep = YES;
        self.diaryTuple = [FSDiaryAPI everydayReadADiary:FSCryptorSupport.localUserDefaultsCorePassword];
    }, ^{
        if (needStep == NO) {
            [self diaryViewDismiss];
            return;
        }
        if (![self.diaryTuple._1 isKindOfClass:NSString.class]) {
            [self diaryViewDismiss];
            return;
        }
        
        if (useAlertShowContent) {
            [self showDiary];
            return;
        }

        // 只显示一次
//        self->_emptyView = [[FSEmptyView alloc] initWithFrame:self.tabBarController.view.bounds];
////        emptyView.backgroundColor = [[UIColor alloc] initWithRed:20.0 / 255 green:20 / 255.0 blue:20 / 155.0 alpha:0.28];
//        [self.tabBarController.view addSubview:self->_emptyView];
//        __weak typeof(self)this = self;
//        self->_emptyView.click = ^(FSEmptyView * _Nonnull eView) {
//            [this removeEmptyView];
//        };
        
        if (!self->_diaryView) {
            CGFloat diaryHeight = 50;
            self->_diaryView = [[UIView alloc] initWithFrame:CGRectMake(20, HEIGHTFC, WIDTHFC - 40, diaryHeight)];
            self->_diaryView.backgroundColor = UIColor.whiteColor;
            self->_diaryView.layer.cornerRadius = 6;
            [self.view addSubview:self->_diaryView];
            [UIView animateWithDuration:1 animations:^{
                self->_diaryView.frame = CGRectMake(20, HEIGHTFC - _fs_tabbarHeight() - diaryHeight - 10, WIDTHFC - 40, diaryHeight);
            }];
            
            UILabel *label = [[UILabel alloc] initWithFrame:self->_diaryView.bounds];
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont boldSystemFontOfSize:16];
            label.textColor = [UIColor colorWithRed:0x20/255.0 green:0xbf/255.0 blue:0x66/255.0 alpha:1];
            label.text = @"看看过去写的日记...";
            [self->_diaryView addSubview:label];
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showDiary)];
            [self->_diaryView addGestureRecognizer:tap];
        }
    });
}

- (void)diaryViewDismiss {
    if (self->_diaryView) {
        [UIView animateWithDuration:1 animations:^{
            self->_diaryView.frame = CGRectMake(20, HEIGHTFC, WIDTHFC - 40, self->_diaryView.frame.size.height);
        } completion:^(BOOL finished) {
            [self->_diaryView removeFromSuperview];
            self->_diaryView = nil;
        }];
    }
}

- (void)showDiary {
    [FSUseGestureView verify:self.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
        Tuple3 *data = self.diaryTuple;
        if (data) {
            if (![data._1 isKindOfClass:NSString.class]) {
                return;
            }
            NSString *notToday = @"今天不再提醒";
            NSString *readed = @"已读";
            NSString *copy = @"复制";
            NSNumber *type = @(UIAlertActionStyleDefault);

            int count = [data._3 intValue];
            NSString *nextOne = nil;
            NSArray *titles = nil;
            NSArray *styles = nil;
            if (count > 1) {
                nextOne = [[NSString alloc] initWithFormat:@"下一篇（%d）",count - 1];
                titles = @[readed,nextOne,copy,notToday];
                styles = @[type,type,type,type];
            } else {
                titles = @[readed,copy,notToday];
                styles = @[type,type,type];
            }

            [FSUIKit alert:UIAlertControllerStyleAlert controller:self title:@"每日一温" message:data._1 actionTitles:titles styles:styles handler:^(UIAlertAction *action) {
                if ([action.title isEqualToString:notToday]) {
                    NSDate *now = [NSDate date];
                    NSDateComponents *c = [FSDate componentForDate:now];
                    [self todayWontShowDiary:c.day];
                }else if ([action.title isEqualToString:readed]){
                    [FSDiaryAPI updateRereadedTime:data._2];
                    [self mustSeeOneDiaryEveryday:NO];
                }else if ([action.title isEqualToString:nextOne]){
                    _fs_dispatch_global_main_queue_async(^{
                        [FSDiaryAPI updateRereadedTime:data._2];
                    }, ^{
                        [self mustSeeOneDiaryEveryday:YES];
                    });
                } else if ([action.title isEqualToString:copy]) {
                    [FSKit copyToPasteboard:data._1];
                    [FSToast show:@"已复制"];
                }
            } cancelTitle:@"取消" cancel:nil completion:nil];
        }
    }];
}

- (void)todayWontShowDiary:(NSInteger)today{
    [FSUIKit alert:UIAlertControllerStyleActionSheet controller:self title:nil message:nil actionTitles:@[@"今日不再提示"] styles:@[@(UIAlertActionStyleDestructive)] handler:^(UIAlertAction *action) {
        _fs_userDefaults_setObjectForKey(@(today), _key_day);
        [self diaryViewDismiss];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

