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
    cat.catInteger = 11;
    cat.catString = @"直接嵌套";
    
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < 7; i++) {
        Cat *cat = [[Cat alloc] init];
        cat.catInteger = i + 10;
        cat.catString = [NSString stringWithFormat:@"数组嵌套[%d]", i];
        [array addObject:cat];
    }
    
    Dog *dog = [[Dog alloc] init];
    dog.dogInt = 22;
    dog.dogInteger = 11;
    dog.cat = cat;
    dog.catList = array.copy;
    dog.dogNumber = @33;
    dog.dogString = @"嵌套父类";
    dog.dogCGFloat = 1.23;

    NSError *error = nil;
    BOOL result = YES;
    
    // 增
//    result = [dog insertWithError:&error];
    
    // 查
    NSArray *list = [Dog findAllWithError:&error];
    for (Dog *d in list) {
        // 改
//        result = [d updateWithError:&error];

        // 删
        result = [d removeWithError:&error];
    }
//
//    // 改
//    result = [dog updateWithError:&error];
//
//    // 删
//    result = [dog removeWithError:&error];
    
    if (result) {
        
    }
}



@end
