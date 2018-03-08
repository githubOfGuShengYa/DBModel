//
//  DBModel.m
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "DBModel.h"
#import <objc/runtime.h>
#import "DBManager.h"
#import "DBDefine.h"

/// 整型
NSString *const SYPropertyType_Integer = @"NSInteger";
/// 浮点型
NSString *const SYPropertyType_CGFloat = @"CGFloat";
///// 字符型
//NSString *const SYPropertyType_NSString = @"NSString";
///// 二进制型
//NSString *const SYPropertyType_Binary = @"";
///// 空型
//NSString *const SYPropertyType_NULL = @"";


#pragma mark- <-----------  关联对象名称  ----------->
/// 继承树中所有属性与属性名组成的字典关联关键字 - 继承树上属性信息作为value,属性名作为key关联起来的该类属性信息列表Dic
static const char *AssociatedKey_PropertyDic;
/// 字段关键字关联映射表Dic
static const char *AssociatedKey_MapperDic;


@interface DBModel()

/// 主键
@property (nonatomic, assign) int pk;

@end

@implementation DBModel


#pragma mark- <-----------  override method  ----------->
+ (void)initialize
{
    NSLog(@"调用initialize方法的类名:%@", NSStringFromClass([self class]));
    if (self != [DBModel class])
    {
        NSLog(@"不是DBModel类");
        
        // 配置继承树上属性信息列表与字段映射表
        [self config];
        
        // 根据属性列表创建或更新数据库表
        [self createTable:nil updateTable:nil];
    }
    else
    {
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
//
//        // 根据属性列表创建或更新数据库表
//        [self createTable:nil updateTable:nil];
    }
    
    return self;
}

/// 创建并更新表 -- 字段只增不减
+ (void)createTable:(void(^)(BOOL isSuccess))createBlock updateTable:(void(^)(SQLTableUpdateType type))updateBlock
{
    // 获得数据库管理者对象
    DBManager *manager = [DBManager manager];
    // 根据管理者对象的数据库队列属性开启事务
    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 获取当前类的名称
        NSString *tableName = NSStringFromClass(self);
        // 创建表语句
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);", tableName, [[self class] propertyNameAndTypeString]];
        // 执行创建表语句并判断是否创建成功
        BOOL isSuccess = [db executeUpdate:sql];
        if (!isSuccess) { // 如果没有创建成功
            // 事务回滚, 并结束执行代码
            *rollback = YES;
            if (createBlock) {
                createBlock(NO);
            }
            return;
        }
        
        
        // 如果创建表成功了, 则开始判断不同版本数据迁移问题
        NSMutableArray *columnNames = [NSMutableArray array];
        // 根据数据库对象获取指定表的信息
        FMResultSet *resultSet = [db getTableSchema:tableName];
        // 遍历表信息
        while ([resultSet next]) {
            // 获取表对应列的名称
            NSString *columnName = [resultSet stringForColumn:@"name"];
            // 添加到表列名数组中
            [columnNames addObject:columnName];
        }
        
        // 获取当前版本该类的所有属性列表
        NSDictionary *dic = objc_getAssociatedObject(self, &AssociatedKey_PropertyDic);
        
        // 获取其属性名列表
        NSArray *propertyNameList = dic.allKeys;
        // 初始化一个谓词来筛选不在表中的字段
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];
        // 用当前版本类的需保存属性列表调用筛选
        NSArray *unsavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];
        
        // 遍历未添加到数据库中的字段列表
        for (NSString *columnName in unsavedProperties) {
            // 取得该列名对应的数据类型
            PropertyDescription *p = dic[columnName];
            // 采用SQL语句添加新的字段到当前数据库表中
            NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", tableName, columnName, p.sqlTypeName];
            // 执行SQL语句添加新的字段
            BOOL success = [db executeUpdate:sqlString];
            // 判断SQL语句是否执行成功
            if (success) {
                NSLog(@"表: %@插入新的字段: %@", tableName, columnName);
            }else {
                // 事务回滚, 并结束执行代码
                *rollback = YES;
                // 回调更新失败状态
                if (updateBlock) {
                    updateBlock(SQLTableUpdateType_Failed);
                }
                return;
            }
        }
        
        // 回调更新本地数据库表状态
        if (updateBlock) {
            updateBlock(unsavedProperties.count > 0 ? SQLTableUpdateType_Success : SQLTableUpdateType_NoNeed);
        }
        
        // 回调创建表状态
        if (createBlock) {
            createBlock(YES);
        }
    }];
}

/// 检查属性列表 - 收集从该类起的继承树上所有属性信息
+ (void)inspectProperties
{
    // 收集属性
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    // 类型
    Class class = self;
    // 扫描器
    NSScanner *scanner = nil;
    // 属性类型
    NSString *propertyType = nil;
    
    // 遍历子类及其父类直到父类是本类为止
    while (class != [DBModel superclass]) {
        
        // 属性列表
        unsigned int count;
        objc_property_t *propertyList = class_copyPropertyList(class, &count);
        
        // 遍历属性列表
        for (unsigned int i = 0; i < count; i++) {
            // 初始化属性描述对象
            PropertyDescription *p = [[PropertyDescription alloc] init];
            
            // 属性
            objc_property_t  property = propertyList[i];
            // 属性名
            NSString *name = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
            p.name = name;
            
            // 属性的属性
            NSString *attributes = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
            // 以,分割字符串
            NSArray *items = [attributes componentsSeparatedByString:@","];
            
            // 如果是只读属性忽略
            if ([items containsObject:@"R"]) {
                continue;
            }
            
            // 初始化扫描器
            scanner = [NSScanner scannerWithString:attributes];
            //FIXME: 基础数据类型以T+字母表示类型、类对象以T@"类型"表示类型、block以T+@?表示类型、结构体以T@{结构体名=}表示类型
            
            // 扫描从T开始
            [scanner scanUpToString:@"T" intoString:nil]; // 索引指向T的下一位
            [scanner scanString:@"T" intoString:nil]; // 只是为了让索引指向T的下一位
            
            // 判断该属性的属性字符串类型
            if ([scanner scanString:@"@\"" intoString:&propertyType]) // 类对象
            {
                // 截取类型字符串 -- 1. T@"NSString"样式  2. T@"NSString<协议名>"样式
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&propertyType];
                // 赋值属性类型 -- 如果是自定义的类型, 则此处取不到类型
                p.type = NSClassFromString(propertyType);
                
                // 属于字符串
                if ([p.type isSubclassOfClass:[NSString class]]) {
                    p.sqlTypeName = @"TEXT";
                }else {
                    p.sqlTypeName = @"BLOB";
//                    p.sqlTypeName = @"TEXT";
                }
                p.typeName = propertyType;
                // 是否可变
                p.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
                
                // 移动扫描索引点配置 1. 是否可选值  2. 是否可忽略  3. 协议名
                while ([scanner scanString:@"<" intoString:nil])
                {
                    NSString *protocolName = nil;
                    // 截取协议名 -- 协议可能不止一个
                    [scanner scanUpToString:@">" intoString:&protocolName];
                    // 判断该协议名属于什么类型 1. 可选值  2. 可忽略  3. 协议
                    if ([protocolName isEqualToString:@"Optional"]) // 可选值
                    {
                        p.isOptional = YES;
                    }
                    else if ([protocolName isEqualToString:@"Ignore"]) // 可忽略
                    {
                        continue;
                    }
                    else
                    {
                        p.protocolName = protocolName;
                    }
                    
                    // 以>字符作为协议名结束点
                    [scanner scanString:@">" intoString:nil];
                }
            }
            else if ([scanner scanString:@"@?" intoString:nil]) // Block
            {
                propertyType = @"Block";
                continue;
            }
            else if ([scanner scanString:@"{" intoString:&propertyType]) // 结构体
            {
                // 截取结构体名 -- T{MyStruct=}格式, 从{开始到=号结束, 其中=号可能是任意数字或字母(不区分大小写)
                [scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&propertyType];
                p.structName = propertyType;
                
                continue;
            }
            else // 基础数据类型(T+字母)
            {
                // 截取表示类型的字母
                [scanner scanUpToString:@"," intoString:&propertyType];
                // 根据该字母转化为正常的基础数据类型
                [self setupPropertyTypeTo:p WithType:propertyType];
            }
            
            // 是否忽略
            if ([self propertyIsIgnored:p.name]) {
                continue;
            }
            
            if ([self.class propertyIsOptional:p.name]) {
                p.isOptional = YES;
            }
            
//            // 当属性是block时, 自动忽略该属性
//            if ([propertyType isEqualToString:@"Block"]) {
//                p = nil;
//                continue;
//            }
            
            // 如果p存在且字典中未保存以p.name为key的值, 则保存该对象
            if (p && ![dic objectForKey:p.name]) {
                [dic setValue:p forKey:p.name];
            }
            
            NSLog(@"属性名: %@, 属性类型: %@-%@", p.name, p.typeName, attributes);
        }
        
        // 释放属性列表
        free(propertyList);
        // 让临时变量指向子类的父类 -- 直到最后指向本类自己
        class = [class superclass];
    }
    
    // 遍历完了继承树保存所有属性信息到静态属性中
    objc_setAssociatedObject(self.class, &AssociatedKey_PropertyDic, [dic copy], OBJC_ASSOCIATION_RETAIN); // 原子性
}


+ (void)setupPropertyTypeTo:(PropertyDescription *)p WithType:(NSString *)type
{
    // 主键
    if ([p.name isEqualToString:NSStringFromSelector(@selector(pk))]) {
        p.sqlTypeName = @"INTEGER PRIMARY KEY";
        p.typeName = SYPropertyType_Integer;
        return;
    }
    
    // 判断基础数据类型字符串
    if ([type isEqualToString:@"q"]) // int64位类型、long类型、longlong类型
    {
        p.sqlTypeName = @"INTEGER";
        p.typeName = SYPropertyType_Integer;
    }
    else if ([type isEqualToString:@"i"]) // int32位类型、int类型
    {
        p.sqlTypeName = @"INTEGER";
        p.typeName = SYPropertyType_Integer;
    }
    else if ([type isEqualToString:@"s"]) // int16位类型
    {
        p.sqlTypeName = @"INTEGER";
        p.typeName = SYPropertyType_Integer;
    }
    else if ([type isEqualToString:@"c"]) // int8位类型
    {
        p.sqlTypeName = @"INTEGER";
        p.typeName = SYPropertyType_Integer;
    }
    else if ([type isEqualToString:@"f"]) // 单精度float类型
    {
        p.sqlTypeName = @"REAL";
        p.typeName = SYPropertyType_CGFloat;
    }
    else if ([type isEqualToString:@"d"]) // 双精度double类型、双精度CGFloat
    {
        p.sqlTypeName = @"REAL";
        p.typeName = SYPropertyType_CGFloat;
    }
    else if ([type isEqualToString:@"B"]) // BOOL类型
    {
        p.sqlTypeName = @"INTEGER";
        p.typeName = SYPropertyType_Integer;
    }
    else { // 其他类型
        p.sqlTypeName = @"INTEGER";
        p.typeName = SYPropertyType_Integer;
    }
}

/// 构造函数时配置该类继承树上属性列表信息
+ (void)config
{
    // 如果静态变量中没有值, 检查属性信息进行配置
    if (!objc_getAssociatedObject(self, &AssociatedKey_PropertyDic)) {
        [self inspectProperties];
    } // 如果静态变量有值说明已经检查完类的属性可以跳过检查属性阶段
    
    // 关键字映射列表 - 如果类中的字段与存储到数据库中的字段名要求不一致,则需要进行相应的关键字映射
    id mapper = [self keyMapper];
    // 如果映射表存在并且静态变量此时未被关联, 则将该映射表与该关键字进行关联
    if (mapper && !objc_getAssociatedObject(self, &AssociatedKey_MapperDic)) {
        objc_setAssociatedObject(self, &AssociatedKey_MapperDic, mapper, OBJC_ASSOCIATION_RETAIN); // 原子性
    }
}

/// 关键字映射表
+ (NSDictionary *)keyMapper
{
    return nil;
}

/// 整体可选或指定属性名设置是否可选
+ (BOOL)propertyIsOptional:(NSString *)propertyName
{
    return NO;
}

/// 整体忽略或指定属性名设置是否忽略
+(BOOL)propertyIsIgnored:(NSString *)propertyName
{
    return NO;
}

///// 获取该类所有需保存属性的属性名与属性类型对应的字典 -- 此时只有子类中的属性
//+ (NSDictionary *)needSavePropertiesInSubClass
//{
//    // 获取忽略列表
//    NSArray *ignoreList = [[self class] ignoreColumns];
//    // 获得该类的属性列表
//    unsigned int propertyCount = 0;
//    objc_property_t *properties = class_copyPropertyList([self class], &propertyCount);
//    // 创建一个字典来保存每个属性的名称和类型
//    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
//    for (int i = 0; i < propertyCount; i++) {
//        // 获取属性对象
//        objc_property_t property = properties[i];
//        // 获得属性名
//        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
//        // 判断该字段是否不需要保存到数据库中
//        if ([ignoreList containsObject:propertyName]) {
//            continue; // 跳过下面的代码继续循环
//        }
//        // 获取该属性的类型
//        NSString *propertyType = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
//        // 根据OC中属性的类型找到对应于数据库中保存的类型
//        NSString *dbType = [[self class] dbTypeByPropertyType:propertyType];
//        NSLog(@"属性名: %@, 属性类型: %@", propertyName, propertyType);
//        // 将每个属性名与属性类型对应添加到字典中(key:属性名, value:属性类型)
//        [dic setObject:dbType forKey:propertyName];
//    }
//
//    // 结束使用后释放属性列表指针
//    free(properties);
//
//    return dic;
//}
//
///// 添加上父类中需要保存的主键属性, 构成完整的需保存属性列表
//+ (NSDictionary *)allNeedSaveProperies
//{
//    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
//    // 添加上父类中的pk属性作为表的主键
//    [dic setObject:SQL_PrimaryKey forKey:@"pk"];
//    // 加上子类中的属性列表
//    [dic addEntriesFromDictionary:[[self class] needSavePropertiesInSubClass]];
//    return dic;
//}
//
//
//
///*
// 各种符号对应类型，部分类型在新版SDK中有所变化，如long 和long long
// c char         C unsigned char
// i int          I unsigned int
// l long         L unsigned long
// s short        S unsigned short
// d double       D unsigned double
// f float        F unsigned float
// q long long    Q unsigned long long
// B BOOL
// @ 对象类型 //指针 对象类型 如NSString 是@“NSString”
//
//
// 64位下long 和long long 都是Tq
// SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
// 因为在项目中用的类型不多，故只考虑了少数类型
// */
///// 根据传入的属性类型返回对应保存在数据库中的类型
//+ (NSString *)dbTypeByPropertyType:(NSString *)type
//{
//    if ([type hasPrefix:@"Tq"]) // int64位类型、long类型、longlong类型
//    {
//        return SQL_Int64;
//    }
//    else if ([type hasPrefix:@"Ti"]) // int32位类型、int类型
//    {
//        return SQL_Int32;
//    }
//    else if ([type hasPrefix:@"Ts"]) // int16位类型
//    {
//        return SQL_Int16;
//    }
//    else if ([type hasPrefix:@"Tc"]) // int8位类型
//    {
//        return SQL_Int8;
//    }
//    else if ([type hasPrefix:@"Tf"]) // 单精度float类型
//    {
//        return SQL_Float;
//    }
//    else if ([type hasPrefix:@"Td"]) // 双精度double类型、双精度CGFloat
//    {
//        return SQL_Double;
//    }
//    else if ([type hasPrefix:@"TB"]) // BOOL类型
//    {
//        return SQL_BOOL;
//    }
//    else if ([type hasPrefix:@"T@\"NSString\""]) // NSString类型
//    {
//        return SQL_NSString;
//    }
//    else if ([type hasPrefix:@"T@\"NSNumber\""]) // NSNumber类型
//    {
//        return SQL_NSNumber;
//    }
//    else if ([type hasPrefix:@"T@\"NSData\""]) // NSData类型
//    {
//        return SQL_NSData;
//    }
//    else if ([type hasPrefix:@"T@\"NSDate\""]) // NSDate类型
//    {
//        return SQL_NSDate;
//    }
//    else { // 其他类型以二进制数据保存
//        return SQL_NSData;
//    }
//}

/// 需保存属性名与属性类型组成的SQL语句片段字符串
+ (NSString *)propertyNameAndTypeString
{
    NSMutableString *str = [NSMutableString string];
    //
    if (objc_getAssociatedObject(self, &AssociatedKey_PropertyDic)) {
        NSDictionary *dic = objc_getAssociatedObject(self, &AssociatedKey_PropertyDic);
        [dic.allValues enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            PropertyDescription *p = obj;
            // 如果该属性不被忽略则表示需要保存到SQL中
            [str appendFormat:@"%@ %@,", p.name, p.sqlTypeName];
        }];
    }
//    // 遍历需保存属性列表
//    [[[self class] allNeedSaveProperies] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
//        // 根据每一组属性名与属性类型拼接到字符串中
//        [str appendFormat:@"%@ %@,", key, obj];
//    }];
    // 删除最后一个多余的逗号
    [str deleteCharactersInRange: NSMakeRange(str.length -1, 1)];
    
    return str.copy;
}

/// 是否已存在表
+ (void)isExistTable:(void(^)(BOOL isExist))callback
{
    DBManager *manager = [DBManager manager];
    [manager.databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *tableName = NSStringFromClass([self class]);
        BOOL isExist = [db tableExists:tableName];
        if (callback) {
            callback(isExist);
        }
    }];
}

#pragma mark- <-----------  数据库操作  ----------->
/// 创建并更新表 -- 字段只增不减
//+ (void)createTable:(void(^)(BOOL isSuccess))createBlock updateTable:(void(^)(SQLTableUpdateType type))updateBlock
//{
//    // 获得数据库管理者对象
//    DBManager *manager = [DBManager manager];
//    // 根据管理者对象的数据库队列属性开启事务
//    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
//        // 获取当前类的名称
//        NSString *tableName = NSStringFromClass([self class]);
//        // 创建表语句
//        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);", tableName, [[self class] propertyNameAndTypeString]];
//        // 执行创建表语句并判断是否创建成功
//        BOOL isSuccess = [db executeUpdate:sql];
//        if (!isSuccess) { // 如果没有创建成功
//            // 事务回滚, 并结束执行代码
//            *rollback = YES;
//            if (createBlock) {
//                createBlock(NO);
//            }
//            return;
//        }
//
//
//        // 如果创建表成功了, 则开始判断不同版本数据迁移问题
//        NSMutableArray *columnNames = [NSMutableArray array];
//        // 根据数据库对象获取指定表的信息
//        FMResultSet *resultSet = [db getTableSchema:tableName];
//        // 遍历表信息
//        while ([resultSet next]) {
//            // 获取表对应列的名称
//            NSString *columnName = [resultSet stringForColumn:@"name"];
//            // 添加到表列名数组中
//            [columnNames addObject:columnName];
//        }
//
//        // 获取当前版本该类的所有需保存属性列表
//        NSDictionary *currentVersionPropertyList = [[self class] allNeedSaveProperies];
//        // 获取其属性名列表
//        NSArray *propertyNameList = currentVersionPropertyList.allKeys;
//        // 初始化一个谓词来筛选不在表中的字段
//        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];
//        // 用当前版本类的需保存属性列表调用筛选
//        NSArray *unsavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];
//
//        // 遍历未添加到数据库中的字段列表
//        for (NSString *columnName in unsavedProperties) {
//            // 取得该列名对应的数据类型
//            NSString *type = currentVersionPropertyList[columnName];
//            // 采用SQL语句添加新的字段到当前数据库表中
//            NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", tableName, columnName, type];
//            // 执行SQL语句添加新的字段
//            BOOL success = [db executeUpdate:sqlString];
//            // 判断SQL语句是否执行成功
//            if (success) {
//                NSLog(@"表: %@插入新的字段: %@", tableName, columnName);
//            }else {
//                // 事务回滚, 并结束执行代码
//                *rollback = YES;
//                // 回调更新失败状态
//                if (updateBlock) {
//                    updateBlock(SQLTableUpdateType_Failed);
//                }
//                return;
//            }
//        }
//
//        // 回调更新本地数据库表状态
//        if (updateBlock) {
//            updateBlock(unsavedProperties.count > 0 ? SQLTableUpdateType_Success : SQLTableUpdateType_NoNeed);
//        }
//
//        // 回调创建表状态
//        if (createBlock) {
//            createBlock(YES);
//        }
//    }];
//}

/// 增
- (void)add:(void(^)(BOOL isSuccess))callback
{
    NSString *tableName = NSStringFromClass([self class]);
    NSMutableString *columnNameString = [NSMutableString string];
    NSMutableString *columnValueString = [NSMutableString string];
    NSMutableArray *columnValues = [NSMutableArray array];
    // 取得属性名数组
    NSDictionary *dic = objc_getAssociatedObject([self class], &AssociatedKey_PropertyDic);
    NSArray *propertyNameList = dic.allKeys;
    // 遍历需保存到数据库的属性列表
    for (int i = 0; i < propertyNameList.count; i++) {
        // 取得对应索引的列名
        NSString *columnName = [propertyNameList objectAtIndex:i];
        
        PropertyDescription *p = dic[columnName];
        
        // 判断是否是主键, 如果是则跳出并继续循环
        if ([columnName isEqualToString:@"pk"]) {
            continue;
        }

        // 如果是基础数据类型时取出的值为NSNumber类型
        id value = [self valueForKey:columnName];// 当NSDate被assign修饰的时候会在此处crash        
        
        // 拼接到SQL语句字符串上
        [columnNameString appendFormat:@"%@,", columnName];
        
        // 如果是空值则不需要拼接到sql语句中
        if (value == nil)
        {
            [columnValueString appendString:@"null,"];
        }
        else {
            [columnValueString appendFormat:@"?,"];
            
            // 字符串
            if ([p.type isSubclassOfClass:[NSString class]])
            {
                // 把值添加的数组中
                [columnValues addObject:value];
            }
            else if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
            {
                NSError *error = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                if (!error) {
                    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [columnValues addObject:jsonStr];
                }else {
                    [columnValues addObject:value];
                }
            }
            else
            {
                // 把值添加的数组中
                [columnValues addObject:value];
            }
        }
    }

    // 清除最后一个逗号
    if (columnNameString.length > 0) {
        [columnNameString deleteCharactersInRange:NSMakeRange(columnNameString.length - 1, 1)];
        [columnValueString deleteCharactersInRange:NSMakeRange(columnValueString.length - 1, 1)];
    }
    
    // 获取管理者单例
    DBManager *manager = [DBManager manager];
    // 使用数据库队列执行保存操作
    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 拼接SQL语句
        NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, columnNameString, columnValueString];
        NSLog(@"数据库表(%@)插入SQL语句:(%@)", tableName, sqlString);//
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-W#warnings"
#warning 该方法第二个参数用于替代?所表示的值, 但是如果想让某个值为空则不能用?号替代添加到该数组中, 由于未知的原因如果向其内添加一个@"null"会导致实际存储的是@"null字符串"
#pragma clang diagnostic pop
        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:columnValues];
        if (isSuccess) {
            self.pk = [NSNumber numberWithLongLong:db.lastInsertRowId].intValue;
            NSLog(@"插入数据成功");
            if (callback) {
                callback(YES);
            }
        }else {
            // 事务回滚, 并结束执行代码
            *rollback = YES;
            NSLog(@"插入数据失败");
            if (callback) {
                callback(NO);
            }
            return;
        }
    }];
}

/// 改
- (void)update:(void(^)(BOOL isSuccess))callback
{
    // 判断是否不存在
    id pk = [self valueForKey:@"pk"];
    if (pk <= 0 || pk == nil) {
        NSLog(@"该数据未存储在数据库表中, 无法实现更新操作");
        if (callback) {
            callback(NO);
        }
        return;
    }
    
    NSString *tableName = NSStringFromClass([self class]);
    NSMutableString *columnNameString = [NSMutableString string];
    NSMutableArray *columnValues = [NSMutableArray array];
    // 取得属性名列表
    NSDictionary *dic = objc_getAssociatedObject([self class], &AssociatedKey_PropertyDic);
    NSArray *propertyNameList = dic.allKeys;
    // 遍历需保存到数据库的属性列表
    for (int i = 0; i < propertyNameList.count; i++) {
        // 取得对应索引的列名
        NSString *columnName = [propertyNameList objectAtIndex:i];
        
        PropertyDescription *p = dic[columnName];
        
        // 判断是否是主键, 如果是则跳出并继续循环
        if ([columnName isEqualToString:@"pk"]) {
            continue;
        }
        
        // 取得当前对象对应属性名的值
        id value = [self valueForKey:columnName];
        // 判断该值是否存在
        if (value == nil) {
            [columnNameString appendFormat:@"%@=null,", columnName];
        }
        else {
            [columnNameString appendFormat:@"?,"];
            
            // 字符串
            if ([p.type isSubclassOfClass:[NSString class]])
            {
                // 把值添加的数组中
                [columnValues addObject:value];
            }
            else if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
            {
                NSError *error = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                if (!error) {
                    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [columnValues addObject:jsonStr];
                }else {
                    [columnValues addObject:value];
                }
            }
            else
            {
                // 把值添加的数组中
                [columnValues addObject:value];
            }
        }
    }
    
    // 清除最后一个逗号
    if (columnNameString.length > 0) {
        [columnNameString deleteCharactersInRange:NSMakeRange(columnNameString.length - 1, 1)];
    }
    
    // SQL语句
    NSString *sqlString = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE pk = %@;", tableName, columnNameString, [self valueForKey:@"pk"]];
    NSLog(@"数据库表(%@)更新SQL语句:(%@)", tableName, sqlString);
    // 获取管理者单例
    DBManager *manager = [DBManager manager];
    // 使用数据库队列执行保存操作
    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 使用数据库事务执行SQL语句
        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:columnValues];
        if (isSuccess) {
            NSLog(@"更新数据成功");
            if (callback) {
                callback(YES);
            }
        }else {
            // 事务回滚, 并结束执行代码
            *rollback = YES;
            if (callback) {
                callback(NO);
            }
            return;
        }
    }];
}

/// 查
+ (NSArray *)findByCondition:(NSString *)condition
{
    // 取得数据管理者单例
    DBManager *manager = [DBManager manager];
    
    // 所有搜索结果数组
    __block NSMutableArray *resultArray = [NSMutableArray array];
    // 执行查询
    [manager.databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        // 获取类名
        NSString *tableName = NSStringFromClass([self class]);
        
        // SQL语句 - select * from table where column = columnName;
        NSString *sqlString = [NSString stringWithFormat:@"SELECT * FROM %@ %@%@", tableName, (condition ? condition : @""), (condition ? ([condition hasSuffix:@";"] ? @"" : @";") : @";")];
        NSLog(@"数据库表(%@)SQL查询语句(%@)", tableName, sqlString);
        // 结果集
        FMResultSet *resultSet = [db executeQuery:sqlString];
        
        // 关联属性列表
        NSDictionary *associatedDic = objc_getAssociatedObject([self class], &AssociatedKey_PropertyDic);
        
        // 当前类需保存的属性名数组
        NSArray *list = associatedDic.allKeys;
        
        // 遍历结果集
        while ([resultSet next]) {
            DBModel *model = [[[self class] alloc] init];
            // 将FMResultSet转换为NSDictionary
            NSDictionary *dic = [resultSet resultDictionary]; // 数据库中的NULL值会在FMResultSet中自动被转化为字符串@"NULL"
            NSLog(@"%@", dic);
            // 遍历属性列表
            for (int i = 0; i < list.count; i++) {
                
                // 获得属性名
                NSString *propertyName = list[i];
                
                PropertyDescription *p = associatedDic[propertyName];
                if (p == nil || [p isKindOfClass:[NSNull class]]) continue;
                
                // 获得属性类型
                NSString *propertyType = p.typeName;
                
                // 先判断该类是否实现了该属性
                if (![model respondsToSelector:NSSelectorFromString(propertyName)]) {
                    continue;
                }
                
                // 根据不同类型设置
                if ([p.name isEqualToString:NSStringFromSelector(@selector(pk))]) // 主键
                {
                    int pk = [[dic objectForKey:propertyName] intValue];
                    [model setValue:[NSNumber numberWithInt:pk] forKey:propertyName];
                }
                // int64位类型、int32位类型、int16位类型、int8位类型、int类型、long类型、longlong类型、BOOL类型
                else if ([propertyType isEqualToString:SYPropertyType_Integer])
                {
                    long long type_int64 = [resultSet longLongIntForColumn:propertyName];
                    [model setValue:[NSNumber numberWithLongLong:type_int64] forKey:propertyName];
                }
                else if ([propertyType isEqualToString:SYPropertyType_CGFloat])
                {
                    double type_double = [resultSet doubleForColumn:propertyName];
                    [model setValue:[NSNumber numberWithDouble:type_double] forKey:propertyName];
                }
                else { // 其他类型以二进制数据保存
                    Class class = NSClassFromString(propertyType);
                    if (class != nil && ![class isKindOfClass:[NSNull class]]) {
                        id value = [dic objectForKey:propertyName];
                        
                        if (![value isKindOfClass:[NSNull class]] && value != nil) {
                            
                            // 字符串
                            if ([class isSubclassOfClass:[NSString class]])
                            {
                                [model setValue:value forKey:propertyName];
                            }
                            // 数组 || 字典
                            else if ([class isSubclassOfClass:[NSArray class]] || [class isSubclassOfClass:[NSDictionary class]])
                            {
                                NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
                                NSError *error = nil;
                                id objc = [NSJSONSerialization JSONObjectWithData:valueData options:kNilOptions error:&error];
                                if (error) {
                                    NSLog(@"反序列化失败");
                                    continue;
                                }
                                [model setValue:objc forKey:propertyName];
                            }
                        }
                    }
                }
            }
            [resultArray addObject:model];
            // 释放模型
            FMDBRelease(model);
        }
    }];
    
    return resultArray.copy;
}

/// 删
+ (void)deleteByCondition:(NSString *)condition callback:(void(^)(BOOL isSuccess))callback
{
    // 取得数据库管理者
    DBManager *manager = [DBManager manager];
    
    // 获得当前类的名称
    NSString *tableName = NSStringFromClass([self class]);
    // 获取删除操作的SQL语句
    NSString *sqlString = [NSString stringWithFormat:@"DELETE FROM %@ %@%@", tableName, (condition ? condition : @""), (condition ? ([condition hasSuffix:@";"] ? @"" : @";") : @";")];
    // 删除之前先搜索是否有达到该条件的数据
    NSArray *result = [[self class] findByCondition:condition];
    if (result.count == 0) {
        if (callback) {
            NSLog(@"从数据库表(%@)中未找到符合(sql:%@)SQL语句的可删除项", NSStringFromClass([self class]), sqlString);
            callback(NO);
        }
        return;
    }
    
    // 通过数据库队列执行事务
    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 判断操作执行是否成功
        BOOL isSuccess = [db executeUpdate:sqlString];
        if (isSuccess) { // 执行删除操作成功
            if (callback) {
                NSLog(@"删除成功");
                callback(YES);
            }
            
        }else { // 执行删除操作失败
            // 事务回滚, 并结束执行代码
            *rollback = YES;
            NSLog(@"删除失败");
            if (callback) {
                callback(NO);
            }
        }
    }];
}

/// 单个删除
- (void)deleteCache:(void(^)(BOOL isSuccess))callback
{
    if (self.pk <= 0) {
        if (callback) {
            NSLog(@"该数据没有保存到数据库中");
            callback(NO); // 新增数据没有保存到数据库中
        }

        return;
    }
    
    [[self class] deleteByCondition:[NSString stringWithFormat:@"where pk = %d;", self.pk] callback:callback];
}

#pragma mark- <-----------  扩展的数据库操作  ----------->
/// 整合保存和更新到一个方法中
- (void)save:(void (^)(BOOL))callback
{
    // 取得主键的值
    id pkValue = [self valueForKey:@"pk"];
    // 如果主键的值小于等于0表示新增的一条数据还未保存到数据库因此没有赋值
    if ([pkValue intValue] <= 0) {
        [self add:callback];
    }else { // 已经有值, 表示该条数据是修改数据库的值
        [self update:callback];
    }
}

///// 保存多个模型
//+ (void)saveObjects:(NSArray<DBModel *> *)objs result:(void (^)(BOOL))callback
//{
//    DBManager *manager = [DBManager manager];
//    // 批量保存的任务需要使用事务来开启, 优点是发生了错误可以回滚
//    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
//        // 遍历传入的模型数组
//        for (DBModel *model in objs) {
//            // 获得该模型的类名
//            NSString *tableName = NSStringFromClass([model class]);
//            // 判断该模型是新建还是更新
//            BOOL isNewObj = model.pk <= 0;
//            // 遍历对应模型类的需保存方法拼接出对应的SQL语句
//            NSDictionary *propertyList = nil;
//            // 属性名组成的字符串 - 增操作
//            NSMutableString *propertyNameString_Add = [NSMutableString string];
//            // 属性值用SQL语句的?表示组成的字符串 - 增操作
//            NSMutableString *propertyValueString_Add = [NSMutableString string];
//            // 属性名组成的字符串 - 改操作
//            NSMutableString *propertyNameString_Update = [NSMutableString string];
//            // 属性值组成的数组
//            NSMutableArray *propertyValueArray = [NSMutableArray array];
//            for (int i = 0; i < propertyList.allKeys.count; i++) {
//                // 获取属性名
//                NSString *propertyName = propertyList.allKeys[i];
//                // 如果是主键就略过
//                if ([propertyName isEqualToString:@"pk"]) {
//                    continue;
//                }
//
//                // 获得对应属性的值
//                id propertyValue = [model valueForKey:propertyName];
//                if (propertyValue == nil) {
//                    propertyValue = @"";
//                }
//                [propertyValueArray addObject:propertyValue];
//
//                // 增操作中拼接列名
//                [propertyNameString_Add appendFormat:@"%@,", propertyName];
//                // 增操作中拼接列值未填写需用?表示
//                [propertyValueString_Add appendFormat:@"?,"];
//                // 改操作中拼接列名与列值?表示
//                [propertyNameString_Update appendFormat:@"%@=?,", propertyName];
//
//
//                // 清除最后一个逗号
//                if (propertyName.length > 0) {
//                    [propertyNameString_Add deleteCharactersInRange:NSMakeRange(propertyNameString_Add.length - 1, 1)];
//                    [propertyValueString_Add deleteCharactersInRange:NSMakeRange(propertyValueString_Add.length - 1, 1)];
//                    [propertyNameString_Update deleteCharactersInRange:NSMakeRange(propertyNameString_Update.length - 1, 1)];
//                }
//
//                // 判断该模型是新增还是更新
//                NSString *sqlString = nil;
//                if (isNewObj) { // 新增
//                    sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, propertyNameString_Add, propertyValueString_Add];
//                }else {
//                    sqlString = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE pk = %@;", tableName, propertyNameString_Update, [model valueForKey:@"pk"]];
//                }
//
//                // 获取管理者单例
//                DBManager *manager = [DBManager manager];
//                // 使用数据库队列执行保存操作
//                [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
//
//                    // 使用数据库事务执行SQL语句
//                    BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:propertyValueArray];
//                    if (!isSuccess) {
//                        if (isNewObj) {
//                            model.pk = [NSNumber numberWithLongLong:db.lastInsertRowId].intValue;
//                        }
//                    }else {
//                        // 事务回滚, 并结束执行代码
//                        *rollback = YES;
//                        if (callback) {
//                            callback(NO);
//                        }
//                        return;
//                    }
//                }];
//            }
//        }
//
//        if (callback) {
//            callback(YES);
//        }
//    }];
//}

/// 批量移除
+ (void)deleteObjects:(NSArray<DBModel *>*)objs successfulHandle:(void(^)(DBModel *successfulModel))successful failedHandle:(void(^)(DBModel *failedModel))failed afterAllSuccess:(void(^)(void))allSuccess
{
    DBManager *manager = [DBManager manager];
    // 初始化一个计数临时变量
    __block NSInteger tmpCount = 0;
    // 遍历传入的模型数组
    for (DBModel *model in objs) {
        // 获得该模型的类名
        NSString *tableName = NSStringFromClass([model class]);
        // 删除的任务需要使用事务来开启, 优点是发生了错误可以回滚
        [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            // 拼接SQL语句
            NSString *sqlString = [NSString stringWithFormat:@"DELETE FROM %@ WHERE pk = %@", tableName, [model valueForKey:@"pk"]];
            // 执行SQL语句
            BOOL isSuccess = [db executeUpdate:sqlString];
            if (!isSuccess) {
                *rollback = YES;
                if (failed) {
                    failed(model);
                }
            }else {
                if (successful) {
                    successful(model);
                }
                
                tmpCount++;
                if (tmpCount == objs.count && allSuccess != nil) {
                    allSuccess();
                }
            }
        }];
    }
}


/// 清空表
+ (void)clear:(void(^)(BOOL isSuccess))callback
{
    DBManager *manager = [DBManager manager];
    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 获取类名
        NSString *tableName = NSStringFromClass([self class]);
        // 拼接SQL语句
        NSString *sqlString = [NSString stringWithFormat:@"DELETE FORM %@", tableName];
        BOOL isSuccess = [db executeUpdate:sqlString];
        if (isSuccess) {
            if (callback) {
                callback(YES);
            }
            NSLog(@"清空%@表成功", tableName);
        }else {
            *rollback = YES;
            if (callback) {
                callback(NO);
            }
            NSLog(@"清空%@表失败", tableName);
            return;
        }
    }];
}

/// 查询表中所有数据
+ (NSArray *)findAll
{
    return [[self class] findByCondition:nil];
}

/// 通过主键值来查询数据
+ (instancetype)findByPk:(int)pkValue
{
    return [[self class] findByCondition:[NSString stringWithFormat:@"where pk = %d", pkValue]].firstObject;
}

#pragma mark- <-----------  不需要保存到数据库的字段  ----------->
/// 不需保存到数据库的字段数组 -- 需在子类中重写该数组, 返回不需要保存的字段的名称
+ (NSArray<NSString *> *)ignoreColumns
{
    return [NSArray array];
}

@end


#pragma mark- <-----------  属性描述类  ----------->

@implementation PropertyDescription

@end
