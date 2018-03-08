//
//  DBDefine.h
//  DBModel
//
//  Created by 谷胜亚 on 2017/12/20.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DBDefine : NSObject

@end



/// 更新本地保存的数据库表
typedef NS_ENUM(NSUInteger, SQLTableUpdateType) {
    /// 不需要更新
    SQLTableUpdateType_NoNeed,
    /// 更新成功
    SQLTableUpdateType_Success,
    /// 更新失败
    SQLTableUpdateType_Failed,
};




#pragma mark- <-----------  主键  ----------->
/// 主键 INTEGER PRIMARY KEY
extern NSString *const SQL_PrimaryKey;

#pragma mark- <-----------  基础数据类型  ----------->
/// NSString
extern NSString *const SQL_NSString;
/// NSNumber
extern NSString *const SQL_NSNumber;
/// BOOL
extern NSString *const SQL_BOOL;
/// CGFloat
extern NSString *const SQL_CGFloat;
/// NSInteger
extern NSString *const SQL_NSInteger;
/// 64位int
extern NSString *const SQL_Int64;
/// 32位int
extern NSString *const SQL_Int32;
/// 16位int
extern NSString *const SQL_Int16;
/// 8位int
extern NSString *const SQL_Int8;
/// int
extern NSString *const SQL_Int;
/// longlong
extern NSString *const SQL_LongLong;
/// long
extern NSString *const SQL_Long;
/// 单精度浮点型
extern NSString *const SQL_Float;
/// 双精度浮点型
extern NSString *const SQL_Double;

#pragma mark- <-----------  非基本数据类型  ----------->
/// 二进制数据
extern NSString *const SQL_NSData;
/// 日期
extern NSString *const SQL_NSDate;
/// 空
extern NSString *const SQL_Nil;
