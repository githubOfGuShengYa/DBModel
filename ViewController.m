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
//    NSMutableArray *array = [NSMutableArray array];
//    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
//    for (int i = 0; i < 4; i++) {
//        Dog *d = [[Dog alloc] init];
//        d.name = [NSString stringWithFormat:@"狗子%02d", i + 1];
//        d.food = @[@"1", @"2", @"3"];
//        d.age = 5 + i;
//        [array addObject:d];
//        [dic setValue:d forKey:d.name];
//    }
    
    
//    Person *person = [[Person alloc] init];
//        person.type_NSString = @"gushengya";
//        person.type_BOOL = YES;
//        person.type_int16 = 12345;
//        person.type_CGFloat = 99.99;
////    person.type_NSDictionary = @{@"name": @"gushengya", @"sex": array, @"age": dic};
//    [person add:^(BOOL isSuccess) {
//
//    }];
    
    Person *p = [[Person alloc] init];
    
    NSLog(@"%@", p.name);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
