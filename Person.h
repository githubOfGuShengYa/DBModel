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

@interface Person : DBModel

- (void)setPrimaryKeyValue:(NSInteger)newValue;

- (NSInteger)primaryKeyValue;

@end

@class Cat;

/// 标记某属性中的自定义类遵守了DBModelProtocol协议
@protocol Associated_Cat
@end
@interface Dog : NSObject<DBModelProtocol>

@property (nonatomic, strong) Cat<Associated_Cat> *cat;

@property (nonatomic, copy) NSString *dogName;

@property (nonatomic, assign) NSInteger dogAge;

@property (nonatomic, copy) NSArray<Associated_Cat> *catList;

@end


@interface Cat : NSObject<DBModelProtocol>

@property (nonatomic, assign) NSInteger catAge;

@property (nonatomic, copy) NSString *catName;

@end

