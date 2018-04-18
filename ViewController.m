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
    
    Person *p = [[Person alloc] initWithDictionary:@{@"name":@"gu", @"myAge": @34} error:nil];
    
    
    
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
    dog.catList = array.copy;
    dog.number1 = 111;
    dog.number2 = 222;

    NSError *error = nil;
//    BOOL result = [dog insertWithError:&error];
    
    
    
    NSArray *array1 = [Dog findByCondition:@""];
    BOOL result = [array1.firstObject removeWithError:&error];
    if (result) {
        
    }
}

- (void)error:(NSError *)error
{
    error = [NSError errorWithDomain:@"ddjjjdjj" code:1 userInfo:nil];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
