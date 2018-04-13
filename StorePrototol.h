//
//  StorePrototol.h
//  DBModel
//
//  Created by 谷胜亚 on 2018/3/9.
//  Copyright © 2018年 gushengya. All rights reserved.
//


/// 某属性是否可忽略
@protocol Ignore
@end



@protocol DBModelProtocol

@optional

@optional


/// 增
//- (void)add;
- (BOOL)insertWithError:(NSError *__strong*)error;
/// 改
//- (void)update:(void(^)(BOOL isSuccess))callback;
- (void)update;
/// 查
+ (NSArray *)findByCondition:(NSString *)condition;

/// 删
//+ (void)removeByCondition:(NSString *)condition callback:(void(^)(BOOL isSuccess))callback;

/// 保存--集合新增与修改于一体
- (void)save:(void(^)(BOOL isSuccess))callback;

/// 单个删除
//- (void)remove:(void(^)(BOOL isSuccess))callback;
- (BOOL)removeWithError:(NSError *__strong*)error;

/// 通过主键值来查询数据
+ (instancetype)findByPk:(int)pkValue;

/// 查询表中所有数据
+ (NSArray *)findAll;

/// 清空表
+ (void)clear:(void(^)(BOOL isSuccess))callback;

@end
