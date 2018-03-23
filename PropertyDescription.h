//
//  PropertyDescription.h
//  DBModel
//
//  Created by 谷胜亚 on 2018/3/9.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 属性类型: 1.OC对象、2.基础数据类型、3.Block、4.结构体
typedef NS_ENUM(NSUInteger, STORE_PROPERTY_TYPE) {
    /// 1.OC对象
    STORE_PROPERTY_TYPE_OBJECT,
    /// 2.基础数据类型
    STORE_PROPERTY_TYPE_BASEDATA,
    /// 3.Block
    STORE_PROPERTY_TYPE_BLOCK,
    /// 4.结构体
    STORE_PROPERTY_TYPE_STUCT,
};

@interface PropertyDescription : NSObject

/// 属性名称
@property (nonatomic, copy) NSString *name;

/// 是否只读
@property (nonatomic, assign) BOOL isReadOnly;

/// 是否可忽略该属性(该属性不保存到数据库中)
@property (nonatomic, assign) BOOL isIgnore;

/// 是否可变属性(如果可变,从数据库提取的值应该置为可变状态)
@property (nonatomic, assign) BOOL isMutable;

/// 属性类型 -- (NSObject对象类型、基础数据类型)__(有值)、(Block类型、结构体类型)__(无值)
@property (nonatomic, assign) Class type;

/** 类型字符串化 -- T@"NSDictionary"中的NSDictionary、Ti中的i、T?中的Block、T{结构体=}中的结构体名
 *
 *  1.OC对象__可具化展示、2.基础数据类型__可具化展示、3.Block类型__不可具化展示用Block代替、4.结构体__可具化展示名称
 */
@property (nonatomic, copy) NSString *typeName;

/// 属性类型分类: 1.OC对象、2.基础数据类型、3.Block、4.结构体
@property (nonatomic, assign) STORE_PROPERTY_TYPE classify;

/// 保存到SQL中的类型 -- 1.INTEGER整型  2.TEXT字符串型  3.REAL浮点型  4.BLOB二进制型  5.NULL空型
@property (nonatomic, copy) NSString *sqlTypeName;

/// 属性遵守的协议名数组
@property (nonatomic, strong) NSMutableArray *protocolNameList;

@end
