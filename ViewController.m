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
    
//    NSMutableArray *arr = [NSMutableArray array];
//
//    for (int i = 0; i < 9; i++) {
//        Person *p = [[Person alloc] init];
//        [p setPrimaryKeyValue:(i+1)];
//        [arr addObject:p];
//    }
//
//    for (Person *p in arr) {
//        NSLog(@"%ld", [p primaryKeyValue]);
//    }
    
    
//    Cat *cat = [[Cat alloc] init];
//    cat.catAge = 11;
//    cat.catName = @"xiaomao";
//    
//    NSMutableArray *array = [NSMutableArray array];
//    for (int i = 0; i < 7; i++) {
//        Cat *cat = [[Cat alloc] init];
//        cat.catAge = i + 10;
//        cat.catName = [NSString stringWithFormat:@"小猫:[%02d]", i + 1];
//        [array addObject:cat];
//    }
//    
//    Dog *dog = [[Dog alloc] init];
//    dog.dogAge = 21;
//    dog.dogName = @"猫子";
//    dog.cat = cat;
//    dog.catList = array;
//    [dog save:^(BOOL isSuccess) {
//        NSLog(@"保存成功");
//    }];
    
//    NSArray *array = [Dog findAll];
//    for (int i = 0; i < array.count; i++) {
//        Dog *d = array[i];
//        d.age = 22 + i;
//        d.name = [NSString stringWithFormat:@"小狗[%d]号", i];
//        [d update:nil];
//    }

//    [Dog removeByCondition:@"where pk = 1" callback:nil];
    
    [Dog searchBySqlString:@"" result:^(NSArray *result) {
        for (Dog *value in result)
        {
            
            for (id v in value.catList) {
                NSInteger p = [v primaryKeyValue];
                
                NSLog(@"[%@]主键值:--%ld", v, p);
            }
        }
    }];
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
