//
//  ViewController.m
//  Myhome
//
//  Created by FudonFuchina on 2016/11/3.
//  Copyright © 2017年 FudonFuchina. All rights reserved.
//

#import "ViewController.h"
#import "FSNavigationController.h"
#import "FSMacro.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self createMainFramework];
}

- (void)createMainFramework{
//    NSArray *array = @[@"HAToolController",@"FSPartListController",@"FSUsageController",@"ARPersonController"];
//    NSArray *titles = @[(@"Home", nil),(@"Wap", nil),(@"Usage", nil),(@"Me", nil)];
//    NSArray *types = @[@(UITabBarSystemItemMostViewed),@(UITabBarSystemItemFavorites),@(UITabBarSystemItemBookmarks),@(UITabBarSystemItemContacts)];
//#if DEBUG
    
#if DEBUG
    NSArray *array = @[@"HAToolController",@"FSWebsiteViewController",@"ARPersonController"];
    NSArray *titles = @[@"荷华",@"发展",@"我"];
    NSArray *types = @[@(UITabBarSystemItemMostViewed),@(UITabBarSystemItemFavorites),@(UITabBarSystemItemContacts)];
    [self configInitWithClasses:array titles:titles types:types selectedColor:UIColor.blackColor];
#else
    NSArray *array = @[@"HAToolController",@"ARPersonController"];
    NSArray *titles = @[@"荷华",@"我"];
    NSArray *types = @[@(UITabBarSystemItemMostViewed),@(UITabBarSystemItemContacts)];
    [self configInitWithClasses:array titles:titles types:types selectedColor:UIColor.blackColor];
#endif
}

- (void)configInitWithClasses:(NSArray<NSString*>*)classes titles:(NSArray<NSString*>*)titles types:(NSArray<NSNumber*>*)types selectedColor:(UIColor *)selectedColor{
    NSMutableArray *vcs = [[NSMutableArray alloc] initWithCapacity:classes.count];
    for (int x = 0; x < classes.count; x ++) {
        Class Controller = NSClassFromString(classes[x]);
        UIViewController *controller = [[Controller alloc] init];
        FSNavigationController *navi = [[FSNavigationController alloc] initWithRootViewController:controller];
        UITabBarItem *tbi = [[UITabBarItem alloc] initWithTabBarSystemItem:[types[x] integerValue] tag:x];
        [tbi setValue:titles[x] forKeyPath:@"_title"];
        if ([selectedColor isKindOfClass:UIColor.class]) {
            [[UITabBar appearance] setTintColor:selectedColor];
            [[UITabBarItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:selectedColor,NSForegroundColorAttributeName,nil] forState:UIControlStateSelected];
        }
        navi.tabBarItem = tbi;
        [vcs addObject:navi];
    }
    self.viewControllers = vcs;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
