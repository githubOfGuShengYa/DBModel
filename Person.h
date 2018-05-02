//
//  Person.h
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "DBModel.h"
#import <UIKit/UIKit.h>
#import <JSONModel/JSONModel.h>

#import "TempClass.h"

@interface Person : JSONModel

@property (nonatomic, copy) NSString *name;

@property (nonatomic, assign) int age;

@end

@class Cat;

/// 标记某属性中的自定义类遵守了DBModelProtocol协议
@protocol Associated_Cat
@end
@interface Dog : NSObject<DBModelProtocol>

@property (nonatomic, strong) Cat<Associated_Cat> *cat;

@property (nonatomic, strong) NSArray<Associated_Cat> *catList;

@property (nonatomic, copy) NSString *dogString;

@property (nonatomic, assign) NSInteger dogInteger;

@property (nonatomic, strong) NSNumber *dogNumber;

@property (nonatomic, assign) int dogInt;

@property (nonatomic, assign) CGFloat dogCGFloat;

@end


@interface Cat : NSObject<DBModelProtocol>

@property (nonatomic, assign) NSInteger catInteger;

@property (nonatomic, copy) NSString *catString;



@end

