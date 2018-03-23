//
//  TempClass.h
//  DBModel
//
//  Created by 谷胜亚 on 2018/3/8.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol Printable

@optional
- (void)lll;

@end

@interface TempClass : NSObject<Printable>

//@property (nonatomic, assign) NSInteger age;
@property (nonatomic, copy) NSString *keyword;

- (void)function1;
+ (void)function2;

@end
