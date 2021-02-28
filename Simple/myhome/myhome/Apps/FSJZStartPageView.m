//
//  FSJZStartPageView.m
//  myhome
//
//  Created by FudonFuchina on 2020/12/6.
//  Copyright © 2020 fuhope. All rights reserved.
//

#import "FSJZStartPageView.h"
#import "FSApp.h"
#import "FSKit.h"
#import "FSDate.h"
#import "FSTTS.h"
#import "FSAppConfig.h"
#import "FSTrack.h"

@implementation FSJZStartPageView {
    UILabel     *_label;
    UILabel     *_timeLabel;
    NSInteger   _days;
    NSString    *_tip;
}

- (void)dealloc {
    
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self startPageHandleDatas];
    }
    return self;
}

- (void)startPageHandleDatas {
    _fs_dispatch_global_main_queue_async(^{
        [self handleDatas];
    }, ^{
        BOOL play = [[FSAppConfig objectForKey:_appCfg_speak] boolValue];
        if (play) {
            FSTTS *tts = FSTTS.new;
            [tts speech:self->_tip priority:0 wait:YES];
        }
       
        [self startPageDesignViews];
    });
}

- (void)handleDatas {
    NSDate *then = nil;
    @try {
        then = [FSDate dateByString:@"2077-05-10 23:59:59" formatter:nil]; // 遇到过崩溃的情况
    } @catch (NSException *exception) {
        [FSTrack event:@"startCrash"];
    } @finally {
        if (![then isKindOfClass:NSDate.class]) {
            _tip = @"你好呐 ~";
            return;
        }
        NSDate *now = NSDate.date;
        NSTimeInterval tt = [then timeIntervalSince1970];
        NSTimeInterval tn = [now timeIntervalSince1970];
        NSTimeInterval delta = tt - tn;
        NSTimeInterval days = delta / 86400;
        _days = (NSInteger)days;
        
        NSDateComponents *time = [FSDate componentForDate:now];
        if (time.hour >= 22 && time.hour <= 24) {
            _tip = @"夜深了 ~";
        } else if (time.hour >= 0 && time.hour <= 6) {
            _tip = @"凌晨好 ~";
        } else if (time.hour > 6 && time.hour <= 10) {
            _tip = @"早上好 ~";
        } else if (time.hour > 10 && time.hour < 14) {
            _tip = @"中午好 ~";
        } else if (time.hour >= 14 && time.hour <= 18) {
            _tip = @"下午好 ~";
        } else if (time.hour > 18 && time.hour < 22) {
            _tip = @"晚上好 ~";
        } else {
            _tip = @"你好呐 ~";
        }
    }
}

- (void)startPageDesignViews {
    self.backgroundColor = UIColor.whiteColor;
    
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:self.bounds];
    imgView.image = [UIImage imageNamed:@"start_bg"];
    imgView.contentMode = UIViewContentModeScaleAspectFill;
    imgView.clipsToBounds = YES;
    [self addSubview:imgView];
    
    BOOL isSmallScreenLikePhone = (UIScreen.mainScreen.bounds.size.height < 700); // iPhone 6 的屏幕高度为667

    CGFloat headSize = 80;
    if (isSmallScreenLikePhone) {
        headSize = 70;
    }
    
    UIImageView *headImageView = [[UIImageView alloc] initWithFrame:CGRectMake(UIScreen.mainScreen.bounds.size.width / 2 - headSize / 2, _fs_statusAndNavigatorHeight(), headSize, headSize)];
    headImageView.image = [UIImage imageNamed:@"start_heart"];
    headImageView.contentMode = UIViewContentModeScaleAspectFill;
    headImageView.clipsToBounds = YES;
    [self addSubview:headImageView];
    
    CGFloat fontSize = 30;
    if (isSmallScreenLikePhone) {
        fontSize = 25;
    }
    
    _label = [[UILabel alloc] initWithFrame:CGRectMake(10, headImageView.frame.origin.y + headImageView.frame.size.height + 20 - isSmallScreenLikePhone * 10, UIScreen.mainScreen.bounds.size.width - 20, 60 - isSmallScreenLikePhone * 10)];
    _label.text = _tip;
    _label.textAlignment = NSTextAlignmentCenter;
    _label.font = [UIFont systemFontOfSize:fontSize];
    _label.alpha = 0;
    [self addSubview:_label];
    
    _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, _label.frame.origin.y + _label.frame.size.height, UIScreen.mainScreen.bounds.size.width - 20, 30)];
    _timeLabel.text = @(_days).stringValue;
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    _timeLabel.font = [UIFont boldSystemFontOfSize:18];
    _timeLabel.alpha = 0;
    [self addSubview:_timeLabel];
    
    [UIView animateWithDuration:2 animations:^{
        self-> _label.alpha = 1;
        self-> _timeLabel.alpha = 1;
    } completion:^(BOOL finished) {
        [self dismiss];
    }];
    
    UIView *bgView = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:bgView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(click)];
    [bgView addGestureRecognizer:tap];
}

- (void)click {
    [self dismiss];
}

- (void)dismiss {
    if (self.willDissmiss) {
        self.willDissmiss(self);
        self.willDissmiss = nil;
    }
    [UIView animateWithDuration:0.5 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
