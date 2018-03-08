//
//  TempClass.h
//  DBModel
//
//  Created by 谷胜亚 on 2018/3/8.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol Printable

@optional
@property (nonatomic, copy) NSString *name;

@optional
- (NSString *)desc;

@end

@interface TempClass : NSObject<Printable>



@end
