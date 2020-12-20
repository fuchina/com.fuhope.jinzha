//
//  ARPersonController.m
//  myhome
//
//  Created by fudon on 2016/11/1.
//  Copyright © 2016年 fuhope. All rights reserved.
//

#import "ARPersonController.h"
#import "FSShare.h"
#import <StoreKit/StoreKit.h>
#import <FSUIKit.h>
#import "FSTrackKeys.h"
#import "FSUseGestureView+Factory.h"
#import "FSDBMaster.h"
#import "FSToast.h"
#import "FSMacro.h"
#import "FSCryptorSupport.h"
#import "FSSqlite3BroswerController.h"
#import <MessageUI/MessageUI.h>
#import "FSApp.h"
#import "FSAppConfig.h"
#import "FSTuple.h"
#import "FSCacheManager.h"
#import "FSTapCell.h"

@interface ARPersonController ()<SKStoreProductViewControllerDelegate>

@property (nonatomic,strong) FSTapCell      *feedbackCell;
@property (nonatomic,strong) FSTapCell      *aboutCell;
@property (nonatomic,strong) FSTapCell      *silenceCell;
@property (nonatomic,strong) FSTapCell      *clearCell;
@property (nonatomic,strong) FSTapCell      *pasteCell;
@property (nonatomic,strong) FSTapCell      *exportCell;

@end

@implementation ARPersonController {
    UISwitch    *_ttsSwitch;
    UISwitch    *_exportSwitch;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"我";
    [self personHandleDatas];
}

- (void)bbiAction{
    [FSUseGestureView verify:self.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
        [FSKit pushToViewControllerWithClass:@"FSSetController" navigationController:self.navigationController param:@{@"pwd":FSCryptorSupport.localUserDefaultsCorePassword?:@""} configBlock:nil];
    }];
}

- (void)birdClick{
    [FSUseGestureView verify:self.tabBarController.view password:FSCryptorSupport.localUserDefaultsCorePassword success:^(FSUseGestureView *view) {
        [self watchSQLite3];
    }];
}

- (void)watchSQLite3{
    FSSqlite3BroswerController *broswer = [[FSSqlite3BroswerController alloc] init];
    broswer.path = [FSDBMaster dbPath];
    [self.navigationController pushViewController:broswer animated:YES];
}

- (void)personHandleDatas{
    __weak typeof(self)this = self;
    if (!_feedbackCell) {
        UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"设置" style:UIBarButtonItemStylePlain target:self action:@selector(bbiAction)];
        bbi.tintColor = UIColor.blackColor;
        self.navigationItem.rightBarButtonItem = bbi;
        
        UIBarButtonItem *left = [[UIBarButtonItem alloc] initWithTitle:@"数据库" style:UIBarButtonItemStylePlain target:self action:@selector(birdClick)];
        self.navigationItem.leftBarButtonItem = left;
        
        _feedbackCell = [[FSTapCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        _feedbackCell.frame = CGRectMake(0, 10, WIDTHFC, 64);
        _feedbackCell.textLabel.text = @"反馈";
        _feedbackCell.backgroundColor = UIColor.whiteColor;
        [self.scrollView addSubview:_feedbackCell];
        _feedbackCell.block = ^(FSTapCell *bCell) {
            BOOL canSendMail = [MFMailComposeViewController canSendMail];
            if (!canSendMail) {
                [FSToast show:@"手机设置邮箱后才可以反馈信息"];
                return;
            }
            [FSTrack event:_UMeng_Event_feedback];
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            NSString *subject = [[NSString alloc] initWithFormat:@"%@iOS %@",[infoDictionary objectForKey:@"CFBundleDisplayName"],@"反馈"];
           
            [FSShare emailShareWithSubject:subject on:this messageBody:nil recipients:@[_feedback_Email] fileData:nil fileName:nil mimeType:nil];
        };
    }
        
    if (!self->_clearCell) {
        self->_clearCell = [[FSTapCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        self->_clearCell.frame = CGRectMake(0, self->_feedbackCell.bottom + 1, WIDTHFC, 64);
        self->_clearCell.textLabel.text = @"清除缓存";
        self->_clearCell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        self->_clearCell.backgroundColor = UIColor.whiteColor;
        [self.scrollView addSubview:self->_clearCell];
        self->_clearCell.block = ^(FSTapCell *bCell) {
            [this clearCache];
        };
    }
    
    _fs_dispatch_global_queue_sync(^{
        [FSCacheManager allCacheSize:^(NSUInteger bResult) {
            NSString *cache = _fs_KMGUnit(bResult);
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_clearCell.detailTextLabel.text = cache;
            });
        }];
    });
        
    if (!_silenceCell) {
        _silenceCell = [[FSTapCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        _silenceCell.frame = CGRectMake(0, _clearCell.bottom + 1, WIDTHFC, 64);
        _silenceCell.textLabel.text = @"静音模式";
        _silenceCell.backgroundColor = UIColor.whiteColor;
        [self.scrollView addSubview:_silenceCell];
        _silenceCell.block = ^(FSTapCell *bCell) {
            [this changeTTSSwitch];
        };
    }
    
    __block BOOL ttsClose = NO;
    _fs_dispatch_global_main_queue_async(^{
        NSString *ttsSwitch = [FSAppConfig objectForKey:_appCfg_speak];
        ttsClose = [ttsSwitch boolValue];
    }, ^{
        if (!self->_ttsSwitch) {
            self->_ttsSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(WIDTHFC - 61, 16.5, 51, 31)];
            [self->_ttsSwitch addTarget:self action:@selector(changeTTSSwitch) forControlEvents:UIControlEventValueChanged];
            [self->_silenceCell addSubview:self->_ttsSwitch];
        }
        self-> _ttsSwitch.on = !ttsClose;
    });
    
    if (!_exportCell) {
        _exportCell = [[FSTapCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        _exportCell.frame = CGRectMake(0, _silenceCell.bottom + 1, WIDTHFC, 64);
        _exportCell.textLabel.text = @"导出数据库弹窗";
        _exportCell.backgroundColor = UIColor.whiteColor;
        [self.scrollView addSubview:_exportCell];
        _exportCell.block = ^(FSTapCell *bCell) {
            [this changeExportSwitch];
        };
    }
    
    __block BOOL exportFile = NO;
    _fs_dispatch_global_main_queue_async(^{
        NSString *eSwitch = [FSAppConfig objectForKey:_appCfg_exportSwitch];
        exportFile = [eSwitch boolValue];
    }, ^{
        if (!self->_exportSwitch) {
            self->_exportSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(WIDTHFC - 61, 16.5, 51, 31)];
            [self->_exportSwitch addTarget:self action:@selector(changeExportSwitch) forControlEvents:UIControlEventValueChanged];
            [self->_exportCell addSubview:self->_exportSwitch];
        }
        self-> _exportSwitch.on = !exportFile;
    });
    
    if (!_aboutCell) {
        _aboutCell = [[FSTapCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        _aboutCell.frame = CGRectMake(0, _exportCell.bottom + 1, WIDTHFC, 64);
        _aboutCell.textLabel.text = @"关于念华";
        _aboutCell.backgroundColor = UIColor.whiteColor;
        [self.scrollView addSubview:_aboutCell];
        _aboutCell.block = ^(FSTapCell *bCell) {
            [FSKit pushToViewControllerWithClass:@"ARAboutController" navigationController:this.navigationController param:@{@"title":@"关于念华"} configBlock:nil];
        };
    }
    
    if (!_pasteCell) {
        _pasteCell = [[FSTapCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        _pasteCell.frame = CGRectMake(0, _aboutCell.bottom + 1, WIDTHFC, 64);
        _pasteCell.textLabel.text = @"清空剪切板";
        _pasteCell.backgroundColor = UIColor.whiteColor;
        [self.scrollView addSubview:_pasteCell];
        _pasteCell.block = ^(FSTapCell *bCell) {
            [FSKit copyToPasteboard:@""];
            [FSToast show:@"清空剪切板"];
        };
    }    
}

- (void)changeTTSSwitch {
    BOOL fp = [[FSAppConfig objectForKey:_appCfg_speak] boolValue];
    NSNumber *num = @(!fp);
    [FSAppConfig saveObject:num.stringValue forKey:_appCfg_speak];
    [self personHandleDatas];
}

- (void)changeExportSwitch {
    BOOL fp = [[FSAppConfig objectForKey:_appCfg_exportSwitch] boolValue];
    NSNumber *num = @(!fp);
    [FSAppConfig saveObject:num.stringValue forKey:_appCfg_exportSwitch];
    [self personHandleDatas];
}

- (void)clearCache {
    [self showWaitView:YES];
    [FSCacheManager clearAllCache:^{
        [self showWaitView:NO];
        self->_clearCell.detailTextLabel.text = @"0.00 K";
    }];
}

//- (void)evaluate{
//    [FSTrack event:_UMeng_Event_cent_start];
//    SKStoreProductViewController *storeVC = [[SKStoreProductViewController alloc] init];
//    storeVC.delegate = self;
//    [self presentViewController:storeVC animated:YES completion:nil];
//    __weak typeof(self)this = self;
//    [storeVC loadProductWithParameters:@{SKStoreProductParameterITunesItemIdentifier:@(1291692536)} completionBlock:^(BOOL result, NSError * error) {
//        if (error) {
//            [FSTrack event:_UMeng_Event_cent_fail];
//            [storeVC dismissViewControllerAnimated:YES completion:nil];
//            [FSUIKit showAlertWithMessage:error.localizedDescription controller:this];
//        }else{
//            [FSTrack event:_UMeng_Event_cent_success];
//        }
//    }];
//}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController{
    [self dismissViewControllerAnimated:YES completion:nil];
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
