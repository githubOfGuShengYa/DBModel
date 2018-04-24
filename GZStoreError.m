//
//  GZStoreError.m
//  DBModel
//
//  Created by 谷胜亚 on 2018/4/18.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "GZStoreError.h"

NSString *const GZStoreInsertError = @"数据插入错误";
NSString *const GZStoreRemoveError = @"数据移除错误";
NSString *const GZStoreUpdateError = @"数据更新错误";
NSString *const GZStoreSelectError = @"数据查询错误";

@implementation GZStoreError

+ (instancetype)errorWithDomain:(NSErrorDomain)domain code:(GZStoreErrorCode)code userInfo:(NSDictionary<NSErrorUserInfoKey,id> *)dict
{
    return [GZStoreError errorWithDomain:domain code:code userInfo:dict];
}

@end
