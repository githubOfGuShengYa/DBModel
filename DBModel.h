//
//  DBModel.h
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//  数据库模型操作

#import <Foundation/Foundation.h>

/// 某属性是否为可选值
@protocol Optional
@end

/// 某属性是否可忽略
@protocol Ignore
@end


@protocol DBModelProtocol


@end

@interface DBModel : NSObject<DBModelProtocol>

#pragma mark- <-----------  需要保存到数据库的字段  ----------->
/// 主键
@property (nonatomic, assign, readonly) int pk;

/// 以什么为标准作为唯一关键字
@property (nonatomic, copy) NSString *keyword;

#pragma mark- <-----------  不需要保存到数据库的字段名集合  ----------->
/// 不需保存到数据库的字段数组 -- 需在子类中重写该数组, 返回不需要保存的字段的名称
+ (NSArray<NSString *> *)ignoreColumns;

//
///// 是否编辑状态
//@property (nonatomic, assign) BOOL is_editing;
//
///// 是否选中状态
//@property (nonatomic, assign) BOOL is_selected;

#pragma mark- <-----------  数据库操作  ----------->
/// 增
- (void)add:(void(^)(BOOL isSuccess))callback;
/// 改
- (void)update:(void(^)(BOOL isSuccess))callback;
/// 查
+ (NSArray *)findByCondition:(NSString *)condition;
/// 删
+ (void)deleteByCondition:(NSString *)condition callback:(void(^)(BOOL isSuccess))callback;

#pragma mark- <-----------  扩展的数据库操作  ----------->
/// 保存--集合新增与修改于一体
- (void)save:(void(^)(BOOL isSuccess))callback;

/// 批量保存
//+ (void)saveObjects:(NSArray<DBModel *>*)objs result:(void(^)(BOOL isSuccess))callback;

/// 单个删除
- (void)deleteCache:(void(^)(BOOL isSuccess))callback;

/**
 *  批量移除数据库表中的数据
 *
 *  @param objs 即将被移除的数据数组
 *  @param successful 每条被移除的数据成功移除后回调一个该条数据的模型
 *  @param failed 每条被移除的数据移除失败后回调一个该条数据的模型
 *  @param allSuccess 全部移除成功后的回调
 */
+ (void)deleteObjects:(NSArray<DBModel *>*)objs successfulHandle:(void(^)(DBModel *successfulModel))successful failedHandle:(void(^)(DBModel *failedModel))failed afterAllSuccess:(void(^)(void))allSuccess;

/// 通过主键值来查询数据
+ (instancetype)findByPk:(int)pkValue;

/// 查询表中所有数据
+ (NSArray *)findAll;

/// 清空表
+ (void)clear:(void(^)(BOOL isSuccess))callback;
@end


#pragma mark- <-----------  属性描述类  ----------->
/// 类属性描述 -- 记录属性的各种状态
@interface PropertyDescription: NSObject

/// 属性名
@property (nonatomic, copy) NSString *name;

/// 是否为可选值
@property (nonatomic, assign) BOOL isOptional;

/// 是否可忽略该属性
@property (nonatomic, assign) BOOL isIgnore;

/// 是否可变属性
@property (nonatomic, assign) BOOL isMutable;

/// 属性类型 -- NSObject对象类型、基础数据类型、Block类型、结构体类型
@property (nonatomic, assign) Class type;

/// 类型名 -- T@"NSDictionary"中的NSDictionary、Ti中的i、T?中的Block、T{结构体=}中的结构体名
@property (nonatomic, copy) NSString *typeName;

/// 保存到SQL中的类型 -- 1.INTEGER整型  2.TEXT字符串型  3.REAL浮点型  4.BLOB二进制型  5.NULL空型
@property (nonatomic, copy) NSString *sqlTypeName;

/// 属性遵守的协议名
@property (nonatomic, copy) NSString *protocolName;

/// 属性如果是结构体, 则结构体名
@property (nonatomic, copy) NSString *structName;

@end
