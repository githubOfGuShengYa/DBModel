//
//  GZStoreError.h
//  DBModel
//
//  Created by 谷胜亚 on 2018/4/18.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 作用域名称
extern NSString *const GZStoreInsertError;
extern NSString *const GZStoreRemoveError;
extern NSString *const GZStoreUpdateError;
extern NSString *const GZStoreSelectError;

typedef NS_ENUM(NSUInteger, GZStoreErrorCode) {
    /**
     整体上
     */
    /// 不支持的类型
    GZStoreErrorNonsupportType,
    /// sql语句错误
    GZStoreErrorSQLString,
    /// 对象实际类型与所属属性类型不匹配
    GZStoreErrorTypeUnMatchBetweenObjAndProperty,
    
    /**
     插入数据
     */
    /// 数据在表中已存在
    GZStoreErrorExistInTable,
    /**
     删除数据
     */
    /// 待移除的数组型对象为空
    GZStoreErrorArrayIsNil,
    /**
     更新数据
     */
    GZStoreErrorNotInTable,
    
    /**
     查找数据
     */
    /// 数据库表中不存在该条数据
    GZStoreErrorAbsenceInTable,
    /// 传入类型错误
    /// 数据删除失败
    /// 暂未支持的数据类型
    /// 数据库中已存在该条数据
    /// 暂未支持的数据类型插入失败
    /// 数据插入失败
    /// 数据更新失败
};

@interface GZStoreError : NSError

+ (instancetype)errorWithDomain:(NSErrorDomain)domain code:(GZStoreErrorCode)code userInfo:(NSDictionary<NSErrorUserInfoKey,id> *)dict;

@end
