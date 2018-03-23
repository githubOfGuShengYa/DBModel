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
    
    Cat *cat = [Cat new];
    cat.name = @"xiaomao";
    
    Dog *dog = [[Dog alloc] init];
    dog.name = @"xiaohong";
    dog.age = 13;
    dog.array = @[cat, cat, @"333", @444];
    [dog save:^(BOOL isSuccess) {
        NSLog(@"保存成功");
    }];
    
//    NSArray *array = [Dog findAll];
//    for (int i = 0; i < array.count; i++) {
//        Dog *d = array[i];
//        d.age = 22 + i;
//        d.name = [NSString stringWithFormat:@"小狗[%d]号", i];
//        [d update:nil];
//    }

    [Dog removeByCondition:@"where pk = 1" callback:nil];
    
    NSArray *arr = [Dog findAll];
    NSLog(@"%@", arr.firstObject);
    return;
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
