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

@end


@interface Dog : NSObject<DBModelProtocol>

@property (nonatomic, copy) NSString *name;

@property (nonatomic, assign) int age;

@property (nonatomic, copy) NSArray *array;

@end


@interface Cat : NSObject

@property (nonatomic, assign) NSInteger index;

@property (nonatomic, copy) NSString *name;

@end

