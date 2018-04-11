//
//  DBModel.h
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//  数据库模型操作

#import <Foundation/Foundation.h>
#import "StorePrototol.h"


@interface DBModel : NSObject<DBModelProtocol>

/// 主键值
- (NSInteger)primaryKeyValue;

@end

