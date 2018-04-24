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
- (BOOL)insertWithError:(NSError *__autoreleasing*)error;

/// 改
- (BOOL)updateWithError:(NSError *__autoreleasing*)error;

/// 查
+ (NSArray *)findAllWithError:(NSError **)error;

+ (NSArray *)findByCondition:(NSString *)condition error:(NSError * __autoreleasing *)error;

/// 删
+ (BOOL)removeWithCondition:(NSString *)condition andError:(NSError *__autoreleasing*)error;
- (BOOL)removeWithError:(NSError *__autoreleasing*)error;

@end
