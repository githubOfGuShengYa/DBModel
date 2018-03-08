//
//  DBDefine.m
//  DBModel
//
//  Created by 谷胜亚 on 2017/12/20.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "DBDefine.h"

@implementation DBDefine

@end


#pragma mark- <-----------  主键  ----------->
/// 主键
NSString *const SQL_PrimaryKey  = @"INTEGER PRIMARY KEY";
//#define SQL_PKey @"INTEGER PRIMARY KEY" // 主键

#pragma mark- <-----------  基础数据类型  ----------->
/// NSString
NSString *const SQL_NSString = @"TEXT";
/// NSNumber
NSString *const SQL_NSNumber = @"TEXT";
/// BOOL
NSString *const SQL_BOOL = @"INTEGER";
/// CGFloat
NSString *const SQL_CGFloat = @"REAL";
/// NSInteger
NSString *const SQL_NSInteger = @"INTEGER";
/// 64位int
NSString *const SQL_Int64 = @"INTEGER";
/// 32位int
NSString *const SQL_Int32 = @"INTEGER";
/// 16位int
NSString *const SQL_Int16 = @"INTEGER";
/// 8位int
NSString *const SQL_Int8 = @"INTEGER";
/// int
NSString *const SQL_Int = @"INTEGER";
/// longlong
NSString *const SQL_LongLong = @"INTEGER";
/// long
NSString *const SQL_Long = @"INTEGER";
/// 单精度浮点型
NSString *const SQL_Float = @"REAL";
/// 双精度浮点型
NSString *const SQL_Double = @"REAL";

#pragma mark- <-----------  非基本数据类型  ----------->
/// 二进制数据
NSString *const SQL_NSData = @"BLOB";
/// 日期
NSString *const SQL_NSDate = @"TIMESTAMP";
/// 空
NSString *const SQL_Nil = @"NULL";
