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
struct MyStruct {
    
};

typedef BOOL(^boolBlock)(NSString *key);
typedef void(^myBlock)(NSString *key);
@class Cat;

@interface Person : DBModel<Printable>

@property (nonatomic, copy) NSString *type_NSString;

@property (nonatomic, assign) CGFloat type_CGFloat;

@property (nonatomic, assign) BOOL type_BOOL;

@property (nonatomic, assign) int16_t type_int16;
@property (nonatomic, copy) NSDictionary *type_NSDictionary;
//@property (nonatomic, strong) Cat *cat;
//@property (nonatomic, copy) NSArray *type_NSArray;
//
//@property (nonatomic,strong, readonly) NSMutableArray *type_NSMutableArray;
//
//@property (nonatomic, strong) NSMutableDictionary *type_NSMutableDictionary;
//
//@property (nonatomic, assign) int64_t type_int64;
//
//@property (nonatomic, assign) int32_t type_int32;
//
//@property (nonatomic, assign) int8_t type_int8;
//
//@property (nonatomic, assign) int type_int;
//
//@property (nonatomic, assign) long type_long;
//
//@property (nonatomic, assign) long long type_longlong;
//
//@property (nonatomic, assign) float type_float;
//
//@property (nonatomic, assign) double type_double;

//@property (nonatomic, assign) NSNumber *type_NSNumber;


//@property (nonatomic, copy) NSData *type_NSData;

//@property (nonatomic, strong) NSDate *type_NSDate;
//@property (nonatomic) struct MyStruct p;
//@property (nonatomic, strong) myBlock block;
//@property (nonatomic, strong) boolBlock boolBlock;
@end


@interface Dog : NSObject

@property (nonatomic, strong) NSArray *food;

@property (nonatomic, copy) NSString *name;

@property (nonatomic, assign) int age;

@end


@interface Cat : JSONModel


@end

