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
    
//    Person *p = [[Person alloc] initWithDictionary:@{@"name":@"gu", @"myAge": @34} error:nil];
    
    
    
    Cat *cat = [[Cat alloc] init];
    cat.catAge = 11;
    cat.catName = @"直接嵌套的猫";
    
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 7; i++) {
        Cat *cat = [[Cat alloc] init];
        cat.catAge = i + 10;
        NSDate *date = [NSDate date];
        cat.catName = @"嵌套数组的猫";
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
    
    
//    [Dog removeWithCondition:@"" andError:&error];
    NSArray *array1 = [Dog findByCondition:nil error:&error];
    
    for (Dog *d in array1) {

        d.dogAge = 001;
        d.dogName = @"疯猫";
        d.cat = cat;
        d.catList = array.copy;
        d.number1 = 1;
        d.number2 = 2;
        [d updateWithError:&error];
    }
    
    array1 = [Dog findByCondition:nil error:&error];
//    result = [array1.firstObject removeWithError:&error];
//    if (result) {
//
//    }
}



@end
