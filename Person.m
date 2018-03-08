//
//  Person.m
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "Person.h"

@implementation Person

- (instancetype)init
{
    self = [super init];
    
    
    if (self) {
        self.name = @"Person类中的重写初始化";
    }
    
    return self;
}


@end


@implementation Dog 

- (void)setStringWithJSONObject:(NSString *)string
{
    
}

+ (JSONKeyMapper *)keyMapper
{
    return [[JSONKeyMapper alloc] initWithModelToJSONDictionary:@{}];
}
@end
