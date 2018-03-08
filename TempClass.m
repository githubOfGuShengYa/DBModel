//
//  TempClass.m
//  DBModel
//
//  Created by 谷胜亚 on 2018/3/8.
//  Copyright © 2018年 gushengya. All rights reserved.
//

#import "TempClass.h"
#import <objc/runtime.h>

@implementation TempClass

- (NSString *)desc
{
    return [NSString stringWithFormat:@"%@+%@", self, [self addOne]];
}

- (NSString *)addOne
{
    return [NSString stringWithFormat:@"谷胜亚"];
}



- (instancetype)initWithSomething
{
    self = [self init];
    if (self) {
        self.name = @"临时类中的初始化";
    }
    
    return self;
}

@synthesize name;

@end

/* GNU C的一大特色就是__attribute__机制。__attribute__可以设置函数属性、变量属性和类型属性。书写特征: __attribute__前后都有两个下划线，并且后面紧跟一对圆括弧，括弧里面对应的__attribute__参数。语法格式: __attribute__((attribute-list))
 参数: 参数constructor让系统执行main()函数之间调用被__attribute__修饰的函数，同理参数destructor让系统在main()函数退出或调用了exit()之后调用被修饰的函数。
 优先级: 参数constructor(100)比constructor(101)优先级要高，因此调用时先调用constructor(100)修饰的函数，系统保留了1-100范围的优先级因此最好从100+开始使用。
 修饰格式: 官方文档中说，__attribute__((attribute-list))应该放到函数声明之后分号(;)之间使用，但放到前面使用也没出问题。
 最后: 不用放到main()函数文件中使用，在任何文件中都可以正常使用
 */
__attribute__((constructor)) static void _append_default_implement_method_to_class() {
    unsigned classCount;
    Class *classes = objc_copyClassList(&classCount);
    //第一层遍历所有的类
    for (int i = 0; i < classCount; i ++) {
        Class class = classes[i];
        Class metaClass = object_getClass(class);
        
        unsigned protocolCount;
        Protocol * __unsafe_unretained *protocols = class_copyProtocolList(class, &protocolCount);
        //第二层遍历类中所有的协议
        for (int j = 0; j < protocolCount; j ++) {
            Protocol *protocol = protocols[j];
            NSString *protocolName = [NSString stringWithFormat:@"%s", protocol_getName(protocol)];
            // 协议名不正确或者类名是临时类则跳过
            if (![protocolName isEqualToString:@"Printable"] || [NSStringFromClass(class) isEqualToString:@"TempClass"]) continue;
            
            
            // 类的实例方法转移
            unsigned methodCount;
            Class tempClass = objc_getClass(NSStringFromClass(class).UTF8String);
            Method *methods = class_copyMethodList(tempClass, &methodCount);
            for (int k = 0; k < methodCount; k ++) {
                Method method = methods[k];
                class_addMethod(class, method_getName(method), method_getImplementation(method), method_getTypeEncoding(method));
            }
            free(methods);
            
            
            // 类的类方法转移
            unsigned metaMethodCount;
            Class metaTempClass = object_getClass(tempClass);
            Method *metaMethods = class_copyMethodList(metaTempClass, &metaMethodCount);
            for (int k = 0; k < metaMethodCount; k ++) {
                Method method = metaMethods[k];
                class_addMethod(metaClass, method_getName(method), method_getImplementation(method), method_getTypeEncoding(method));
            }
            free(metaMethods);
            
//            // 类的实例属性转移
//            unsigned propertyCount;
//            objc_property_t *propertyList = class_copyPropertyList(tempClass, &propertyCount);
//            // 遍历临时类的所有属性并添加
//            for (int k = 0; k < propertyCount; k++) {
//                objc_property_t  property = propertyList[i];
//                class_addProperty(tempClass, property_getName(property), property_getAttributes(property), )
//            }
        }
        free(protocols);
    }
    free(classes);
}

