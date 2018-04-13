//
//  GZStoreErrorDefine.h
//  DBModel
//
//  Created by 谷胜亚 on 2018/4/13.
//  Copyright © 2018年 gushengya. All rights reserved.
//


#pragma mark- <-----------  错误的域名(大方向的描述)  ----------->
/// 类格式错误
extern NSString *const GZStoreErrorDomainFormat = @"GZStoreErrorDomainFormat";
/// 数据操作错误
extern NSString *const GZStoreErrorDomainHandle = @"GZStoreErrorDomainHandle";
/// 数据库错误
extern NSString *const GZStoreErrorDomainSQLite = @"GZStoreErrorDomainSQLite";

/// 错误的具体原因状态码枚举
typedef NS_ENUM(NSUInteger, GZStoreErrorType) {
    /// 数据库中已存在
    GZStoreErrorExistAlready = 1,
};

/// 错误的原因描述信息
