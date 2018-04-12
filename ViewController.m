//
//  ViewController.m
//  DBModel
//
//  Created by 谷胜亚 on 2018/2/24.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "ViewController.h"
#import "Person.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    Cat *cat = [[Cat alloc] init];
    cat.catAge = 11;
    cat.catName = @"xiaomao";
    
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 7; i++) {
        Cat *cat = [[Cat alloc] init];
        cat.catAge = i + 10;
        cat.catName = [NSString stringWithFormat:@"小猫:[%02d]", i + 1];
        [array addObject:cat];
    }
    
    Dog *dog = [[Dog alloc] init];
    dog.dogAge = 21;
    dog.dogName = @"猫子";
    dog.cat = cat;
    dog.number1 = 111;
    dog.number2 = 222;

        [dog save:^(BOOL isSuccess) {
            NSLog(@"保存成功");
        }];

    
    
//    [Dog searchBySqlString:@"" result:^(NSArray *result) {
//        for (Dog *value in result)
//        {
//            value.dogName = @"我的小狗";
//            value.cat.catName = @"我的小猫";
//            [value update];
//        }
//    }];
    NSArray *arr = [Dog findByCondition:@""];
//    for (Dog *value in arr)
//    {
//        value.dogName = @"我的小狗";
//        value.cat.catName = @"我的小猫";
//        [value update];
//    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
