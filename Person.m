//
//  Person.m
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "Person.h"
#import <objc/runtime.h>
/// 关联主键值


@interface Person()
{
    NSInteger AssociatedKey_PrimaryKey;
}
@end
@implementation Person

- (void)setPrimaryKeyValue:(NSInteger)newValue
{
//    objc_setAssociatedObject(self.class, @selector(primaryKeyValue), @(newValue), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    AssociatedKey_PrimaryKey = newValue;
}

- (NSInteger)primaryKeyValue
{
//    return [objc_getAssociatedObject(self.class, @selector(primaryKeyValue)) integerValue];
    return AssociatedKey_PrimaryKey;
}

@end


@implementation Dog 

@synthesize pk = _pk;



@end


@implementation Cat
@synthesize pk = _pk;
@end
