//
//  Person.m
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "Person.h"

@implementation Person

+ (JSONKeyMapper *)keyMapper
{
    return [[JSONKeyMapper alloc] initWithModelToJSONDictionary:@{@"age": @"myAge"}];
}

@end


@implementation Dog 





@end


@implementation Cat

@end
