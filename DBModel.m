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
#import "PropertyDescription.h"

/// 整型
NSString *const SYPropertyType_Integer = @"NSInteger";
/// 浮点型
NSString *const SYPropertyType_CGFloat = @"CGFloat";

#pragma mark- <-----------  默认实现的字段  ----------->
/// 关联上级类的格式字段
NSString *const SQL_COLUMN_NAME_SuperiorKey = @"GZ_SuperiorKey_Name"; // 父类标记格式[所属类类名_所属类属性名_关联对象主键ID], 字段是TEXT类型(动态的因此不置为属性)
/// 主键在数据表中的字段名
NSString *const SQL_COLUMN_NAME_PrimaryKey = @"GZ_PrimaryKey_Name";

#pragma mark- <-----------  关联对象名称  ----------->
/// 所有属性与属性名组成的字典关联关键字 - 属性信息作为value,属性名作为key关联起来的该类属性信息列表Dic
static const char *AssociatedKey_AllPropertyList; // 收集所有属性
/// 需保存入数据库的字段
static const char *AssociatedKey_StorePropertyList; // 收集除了只读和忽略的属性
/// 需保存入数据库的字段
static const char *AssociatedKey_NestPropertyList; // 收集嵌套的属性
/// 字段关键字关联映射表Dic
static const char *AssociatedKey_MapperDic;
///// 关联主键值
//static const char *AssociatedKey_PrimaryKey;
///// 上级关联值
//static const char *AssociatedKey_SuperiorKey;

@interface DBModel()
{
    NSInteger AssociatedKey_PrimaryKey;
    NSString *AssociatedKey_SuperiorKey;
}
@end

@implementation DBModel

- (void)setPrimaryKeyValue:(NSInteger)newValue
{
    objc_setAssociatedObject(self.class, &AssociatedKey_PrimaryKey, @(newValue), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)primaryKeyValue
{
    return [objc_getAssociatedObject(self.class, &AssociatedKey_PrimaryKey) integerValue];
}

- (void)setSuperiorKeyValue:(NSString *)newValue
{
    objc_setAssociatedObject(self.class, &AssociatedKey_SuperiorKey, newValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)superiorKeyValue
{
    return objc_getAssociatedObject(self.class, &AssociatedKey_SuperiorKey);
}


#pragma mark- <-----------  override method  ----------->

/// 配置属性信息列表;配置数据库表
+ (void)configPropertyAndTable
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self configTable];
    });
}



// 循环配置遵守DBModelProtocol协议的类及其内关联属性类的所有需存储属性为数据库字段
//+ (void)configTableWithClass:(Class)class superClass:(Class)superClass database:(FMDatabase * _Nonnull)db
//{
//    NSString *tableName = NSStringFromClass(class);
//
//    BOOL isExist = [db tableExists:tableName];
//    if (!isExist)
//    {
//        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);", tableName, [class configSQLStringWithSuperClass:superClass]];
//        BOOL isSuccess = [db executeUpdate:sql];
//        if (!isSuccess) { // 如果没有创建成功
//            // 事务回滚, 并结束执行代码
//            return;
//        }
//        NSLog(@"创建数据库表(%@)成功", sql);
//    }
//    else
//    {
//        NSLog(@"数据库表(%@)已存在", tableName);
//    }
//
//    // 检查是否有嵌套属性
//    NSDictionary *storeDic = objc_getAssociatedObject(class, &AssociatedKey_StorePropertyList);
//    if (storeDic == nil)
//    {
//        [class config];
//        storeDic = objc_getAssociatedObject(class, &AssociatedKey_StorePropertyList);
//    }
//    for (PropertyDescription *p in storeDic.allValues)
//    {
//        if (p.isIgnore == NO && p.associateClass != nil)
//        {
//            [class configTableWithClass:p.associateClass superClass:class database:db];
//        }
//    }
//
//    // 如果表存在了, 则开始判断不同版本数据迁移问题
//    NSMutableArray *columnNames = [NSMutableArray array];
//    // 根据数据库对象获取指定表的信息
//    FMResultSet *resultSet = [db getTableSchema:tableName];
//    // 遍历表信息
//    while ([resultSet next]) {
//        // 获取表对应列的名称
//        NSString *columnName = [resultSet stringForColumn:@"name"];
//        [columnNames addObject:columnName];
//    }
//
//    // 获取需保存的属性名列表
//    NSArray *propertyNameList = storeDic.allKeys;
//    // 初始化一个谓词来筛选不在表中的字段
//    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];
//    // 用当前版本类的需保存属性列表调用筛选
//    NSArray *unsavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];
//
//    // 遍历未添加到数据库中的字段列表
//    for (NSString *columnName in unsavedProperties)
//    {
//        // 取得该列名对应的数据类型
//        PropertyDescription *p = storeDic[columnName];
//
//        if ([p.name isEqualToString:@"pk"]) continue;
//
//        if (p.isIgnore == NO && p.associateClass != nil) {
//            continue;
//        }
//
//        // 采用SQL语句添加新的字段到当前数据库表中
//        NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", tableName, columnName, p.sqlTypeName];
//        // 执行SQL语句添加新的字段
//        BOOL success = [db executeUpdate:sqlString];
//        // 判断SQL语句是否执行成功
//        if (success) {
//            NSLog(@"表: %@插入新的字段: %@", tableName, columnName);
//        }else {
//            // 事务回滚, 并结束执行代码
//            return;
//        }
//    }
//}



/// 拼接属性组成的创建表sql部分语句
+ (NSString *)splicingSqlString
{
    NSMutableString *str = [NSMutableString string];
    NSDictionary *dic = objc_getAssociatedObject(self, &AssociatedKey_StorePropertyList);
    if (dic == nil) {
        [self config];
        dic = objc_getAssociatedObject(self, &AssociatedKey_StorePropertyList);
    }
    for (PropertyDescription *p in dic.allValues) {

        [str appendFormat:@"%@ %@,", p.name, p.sqlTypeName];
    }
    
    // 删除最后一个多余的逗号
    [str deleteCharactersInRange: NSMakeRange(str.length -1, 1)];
    
    return str.copy;
}

/// 根据传入的类配置对应表
+ (void)configTable
{
    // 0. 配置属性信息
    [self config];
    
    [[DBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        // 1. 判断数据库表是否已创建
        BOOL isExist = [db tableExists:NSStringFromClass(self)];
        if (isExist) // 已创建
        {
            NSLog(@"[%@]表已创建", NSStringFromClass(self));
        }
        else // 未创建
        {
            // 1.1 按sql语句要求拼接需保存字段
            NSString *propertySQLString = [self splicingSqlString];
            
            // 1.2 嵌套类型添加的字段, 格式为[本类所属类类名_在所属类中属性名_在所属类中数据的主键值], 字段名订为
            NSString *associatedColumn = [NSString stringWithFormat:@"%@ %@", SQL_COLUMN_NAME_SuperiorKey, @"TEXT"];
            
            // 1.2.1 主键的添加
            NSString *primaryKey = [NSString stringWithFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT", SQL_COLUMN_NAME_PrimaryKey];
            
            // 1.3 完整sql创建表语句
            NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@,%@,%@);", NSStringFromClass(self), primaryKey,  associatedColumn, propertySQLString];
            
            // 1.4 判断sql语句执行是否成功
            BOOL isSuccess = [db executeUpdate:sql];
            
            // 1.5 如果成功继续, 不成功回滚
            if (isSuccess == NO) {
                *rollback = YES;
                NSLog(@"[%@]表创建语句失败:(%@)", NSStringFromClass(self), sql);
                return ;
            }
            
            NSLog(@"[%@]表创建语句成功:(%@)", NSStringFromClass(self), sql);
        }
        
        // 2. 判断是否有新属性需要增加到表中
        NSMutableArray *columnNames = [NSMutableArray array];
        
        // 根据数据库对象获取指定表的信息
        FMResultSet *resultSet = [db getTableSchema:NSStringFromClass(self)];
        while ([resultSet next]) {
            NSString *columnName = [resultSet stringForColumn:@"name"];
            [columnNames addObject:columnName];
        }
        
        NSDictionary *storeDic = objc_getAssociatedObject(self, &AssociatedKey_StorePropertyList);
        NSArray *propertyNameList = storeDic.allKeys; // 得到的不包括SQL_COLUMN_NAME_AssociatedClass_Format
        // 初始化一个谓词来筛选不在表中的字段
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];
        // 用当前版本类的需保存属性列表调用筛选
        NSArray *needSavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];
        
        if (needSavedProperties.count > 0) // 有
        {
            // 2.1 遍历数组来增加新的字段
            for (NSString *columnName in needSavedProperties)
            {
                PropertyDescription *p = storeDic[columnName];
                
                // 采用SQL语句添加新的字段到当前数据库表中
                NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", NSStringFromClass(self), columnName, p.sqlTypeName];
                BOOL success = [db executeUpdate:sqlString];
                if (success)
                {
                    NSLog(@"[%@表增加字段成功]:(%@)", NSStringFromClass(self), sqlString);
                }
                else
                {
                    // 事务回滚, 并结束执行代码
                    *rollback = YES;
                    NSLog(@"[%@表增加字段失败]:(%@)", NSStringFromClass(self), sqlString);
                    return;
                }
            }
        }
        else // 没有
        {
            
        }
    }];
    
    // 0.1 获取需保存属性信息
    NSDictionary *nestDic = objc_getAssociatedObject(self, &AssociatedKey_NestPropertyList);
    
    for (PropertyDescription *p in nestDic.allValues) {
        [p.associateClass configTable];
    }
}



/// 检查属性列表
+ (void)inspectProperties
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary]; // 收集所有属性
    NSMutableDictionary *storeDic = [NSMutableDictionary dictionary]; // 收集可保存到数据库中的属性
    NSMutableDictionary *nestDic = [NSMutableDictionary dictionary]; // 嵌套属性
    
    // 扫描器
    NSScanner *scanner = nil;
    // 属性类型
    NSString *propertyType = nil;
    
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList(self, &count);

    for (unsigned int i = 0; i < count; i++) {
        
        PropertyDescription *p = [[PropertyDescription alloc] init];
        objc_property_t  property = propertyList[i];
        NSString *name = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        // 属性名称
        p.name = name;
        
        NSString *attributes = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        NSArray *items = [attributes componentsSeparatedByString:@","];
        
        // 只读
        if ([items containsObject:@"R"]) {
            p.isReadOnly = YES;
        }
        
        // 初始化扫描器
        scanner = [NSScanner scannerWithString:attributes];
        //FIXME: 基础数据类型以T+字母表示类型、类对象以T@"类型"表示类型、block以T+@?表示类型、结构体以T@{结构体名=}表示类型
        
        // 扫描从T开始
        [scanner scanUpToString:@"T" intoString:nil]; // 索引指向T的下一位
        [scanner scanString:@"T" intoString:nil]; // 只是为了让索引指向T的下一位
        
        // 判断该属性的属性字符串类型
        if ([scanner scanString:@"@\"" intoString:&propertyType]) // OC对象
        {
            // 截取类型字符串 -- 1. T@"NSString"样式  2. T@"NSString<协议名>"样式
            [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&propertyType];
            // 赋值属性类型 -- 如果是自定义的类型, 则此处取不到类型
            p.type = NSClassFromString(propertyType);
            p.typeName = propertyType;
            // 是否可变
            p.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
            
            // 属于字符串
            if ([p.type isSubclassOfClass:[NSString class]]) // 字符串系可直接保存为TEXT格式
            {
                p.sqlTypeName = @"TEXT";
            }
            else // 非字符串系保存为二进制格式
            {
                p.sqlTypeName = @"BLOB";
            }
            
            // 遵循的协议
            NSString *protocolName = nil;
            while ([scanner scanString:@"<" intoString:nil])
            {
                // 截取协议名 -- 协议可能不止一个
                [scanner scanUpToString:@">" intoString:&protocolName];
                // 判断该协议名属于什么类型 1. 可选值  2. 可忽略  3. 协议
                if ([protocolName isEqualToString:@"Ignore"]) // 不用保存到数据库
                {
                    p.isIgnore = YES;
                }
                else if ([protocolName hasPrefix:@"Associated_"]) // 属性包含的类实现了DBModelProtocol协议
                {
                    NSRange range = [protocolName rangeOfString:@"Associated_"];
                    NSString *associatedClassName = [protocolName substringFromIndex:range.length];
                    p.associateClass = NSClassFromString(associatedClassName);
                }
                else // 普通实现了某些协议
                {
                    if (p.protocolNameList != nil) {
                        [p.protocolNameList addObject:protocolName];
                    }else {
                        p.protocolNameList = [NSMutableArray arrayWithObject:protocolName];
                    }
                }
                
                // 以>字符作为协议名结束点, 使用scanString让扫描索引移动到>位置
                [scanner scanString:@">" intoString:nil];
            }
            
            // OC对象分类
            p.classify = STORE_PROPERTY_TYPE_OBJECT;
        }
        else if ([scanner scanString:@"@?" intoString:nil]) // Block
        {
            propertyType = @"Block";
            p.typeName = propertyType;
            // Block分类
            p.classify = STORE_PROPERTY_TYPE_BLOCK;
            p.isIgnore = YES; // Block自动划入忽略项
        }
        else if ([scanner scanString:@"{" intoString:&propertyType]) // 结构体
        {
            // 截取结构体名 -- T{MyStruct=}格式, 从{开始到=号结束, 其中=号可能是任意数字或字母(不区分大小写)
            [scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&propertyType];
            p.typeName = propertyType;
            
            // 结构体分类
            p.classify = STORE_PROPERTY_TYPE_STUCT;
            p.isIgnore = YES; // 结构体自动划入忽略项
        }
        else // 基础数据类型(T+字母)
        {
            // 截取表示类型的字母
            [scanner scanUpToString:@"," intoString:&propertyType];
            // 根据该字母转化为正常的基础数据类型
            [self setupPropertyTypeTo:p WithType:propertyType];
            
            // 基础数据分类
            p.classify = STORE_PROPERTY_TYPE_BASEDATA;
        }
        
        // 是否忽略
        if ([self propertyIsIgnored:p.name]) {
            p.isIgnore = YES;
        }
        
        // 如果p存在且字典中未保存以p.name为key的值, 则保存该对象
        if (p && ![dic objectForKey:p.name]) {
            [dic setValue:p forKey:p.name];
            if (!(p.isIgnore) && ![storeDic objectForKey:p.name]) { // 未被忽略且字典中没有该key
                if (p.associateClass != nil && ![nestDic objectForKey:p.name]) { // 嵌套属性且需要保存
                    [nestDic setValue:p forKey:p.name];
                }else { // 未嵌套属性且需要保存
                    [storeDic setValue:p forKey:p.name];
                }
            }
        }
        
        NSLog(@"属性名: %@, 属性类型: %@-%@", p.name, p.typeName, attributes);
    }
    
    // 释放属性列表
    free(propertyList);
    
    // 遍历完了继承树保存所有属性信息到静态属性中
    objc_setAssociatedObject(self.class, &AssociatedKey_AllPropertyList, [dic copy], OBJC_ASSOCIATION_RETAIN); // 原子性
    objc_setAssociatedObject(self.class, &AssociatedKey_StorePropertyList, [storeDic copy], OBJC_ASSOCIATION_RETAIN); // 原子性
    objc_setAssociatedObject(self.class, &AssociatedKey_NestPropertyList, [nestDic copy], OBJC_ASSOCIATION_RETAIN); // 原子性
}


+ (void)setupPropertyTypeTo:(PropertyDescription *)p WithType:(NSString *)type
{
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
    if (!objc_getAssociatedObject(self, &AssociatedKey_AllPropertyList)) {
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

/// 整体忽略或指定属性名设置是否忽略
+(BOOL)propertyIsIgnored:(NSString *)propertyName
{
    return NO;
}



///// 需保存属性名与属性类型组成的SQL语句片段字符串
//+ (NSString *)configSQLStringWithSuperClass:(Class)superClass
//{
//    NSMutableString *str = [NSMutableString string];
//    NSDictionary *dic = objc_getAssociatedObject(self, &AssociatedKey_StorePropertyList);
//    if (dic == nil) {
//        [self config];
//        dic = objc_getAssociatedObject(self, &AssociatedKey_StorePropertyList);
//    }
//    for (PropertyDescription *obj in dic.allValues) {
//        if ([obj.name isEqualToString:@"pk"]) { // 自增主键
//            [str appendFormat:@"pk INTEGER PRIMARY KEY AUTOINCREMENT,"];
//        }else if (obj.associateClass != nil && obj.isIgnore == NO && superClass != nil) { // 属性为嵌套且未被忽略
//            [str appendFormat:@"%@_pk %@,", NSStringFromClass(superClass), @"INTEGER"];
//        }else {
//            // 如果该属性不被忽略则表示需要保存到SQL中
//            [str appendFormat:@"%@ %@,", obj.name, obj.sqlTypeName];
//        }
//    }
//
//    // 删除最后一个多余的逗号
//    [str deleteCharactersInRange: NSMakeRange(str.length -1, 1)];
//
//    return str.copy;
//}

/// 是否已存在表
+ (void)isExistTable:(void(^)(BOOL isExist))callback
{
    DBManager *manager = [DBManager manager];
    [manager.databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *tableName = NSStringFromClass(self);
        BOOL isExist = [db tableExists:tableName];
        if (callback) {
            callback(isExist);
        }
    }];
}

#pragma mark- <-----------  数据库操作  ----------->


//- (void)addWithSuperClass:(Class)superClass
//{
//    [self.class configPropertyAndTable];
//
//    NSString *tableName = NSStringFromClass([self class]);
//    NSMutableString *columnNameString = [NSMutableString string];
//    NSMutableString *columnValueString = [NSMutableString string];
//    NSMutableArray *columnValues = [NSMutableArray array];
//
//    // 嵌套时的key与value
//    NSMutableString *nestColumnName = [NSMutableString string];
//    NSMutableArray *nestColumnValue = [NSMutableArray array];
//
//    // 取得属性名数组
//    NSDictionary *dic = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
//    NSArray *propertyNameList = dic.allKeys;
//    // 遍历需保存到数据库的属性列表
//    for (int i = 0; i < propertyNameList.count; i++) {
//        // 取得对应索引的列名
//        NSString *columnName = [propertyNameList objectAtIndex:i];
//
//        PropertyDescription *p = dic[columnName];
//
//        // 判断是否是主键, 如果是则跳出并继续循环
//        if ([columnName isEqualToString:@"pk"]) {
//            continue;
//        }
//
//        // 是否嵌套
//        if (p.associateClass && p.isIgnore == NO) // 嵌套的话如果是集合只能是ObjectC类型所以必定实现了isSubclassOfClass:方法
//        {
//            if ([p.type isEqual:p.associateClass]) // 属性即对象
//            {
//                id obj = [self valueForKey:columnName];
//                [obj addWithSuperClass:self.class];
//
//            }
//            else if ([p.type isSubclassOfClass:[NSArray class]]) // 隶属于数组
//            {
//                NSArray *array = [self valueForKey:columnName];
//                [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                    [obj addWithSuperClass:self.class];
//                }];
//            }
//            else if ([p.type isSubclassOfClass:[NSDictionary class]]) // 隶属于字典
//            {
//
//            }
//            continue;
//        }
//
//        // 如果是基础数据类型时取出的值为NSNumber类型
//        id value = [self valueForKey:columnName];// 当NSDate被assign修饰的时候会在此处crash
//
//        // 拼接到SQL语句字符串上
//        [columnNameString appendFormat:@"%@,", columnName];
//
//        // 如果是空值则不需要拼接到sql语句中
//        if (value == nil)
//        {
//            [columnValueString appendString:@"null,"];
//        }
//        else {
//            [columnValueString appendFormat:@"?,"];
//
//            // 字符串
//            if ([p.type isSubclassOfClass:[NSString class]])
//            {
//                // 把值添加的数组中
//                [columnValues addObject:value];
//            }
//            else if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
//            {
//                NSError *error = nil; NSData *data = nil;
//                @try {
//                    data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
//                    if (!error) {
//                        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//                        [columnValues addObject:jsonStr];
//                    }else {
//                        [columnValues addObject:value];
//                    }
//                }
//                @catch (NSException *e) {
//                    [columnValues addObject:value];
//                }
//
//            }
//            else
//            {
//                // 把值添加的数组中
//                [columnValues addObject:value];
//            }
//        }
//    }
//
//    // 清除最后一个逗号
//    if (columnNameString.length > 0) {
//        [columnNameString deleteCharactersInRange:NSMakeRange(columnNameString.length - 1, 1)];
//        [columnValueString deleteCharactersInRange:NSMakeRange(columnValueString.length - 1, 1)];
//    }
//
//
//
//    // 获取管理者单例
//    DBManager *manager = [DBManager manager];
//    // 使用数据库队列执行保存操作
//    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
//        // 拼接SQL语句
//        NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, columnNameString, columnValueString];
//        NSLog(@"数据库表(%@)插入SQL语句:(%@)", tableName, sqlString);//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-W#warnings"
//#warning 该方法第二个参数用于替代?所表示的值, 但是如果想让某个值为空则不能用?号替代添加到该数组中, 由于未知的原因如果向其内添加一个@"null"会导致实际存储的是@"null字符串"
//#pragma clang diagnostic pop
//        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:columnValues];
//        if (isSuccess) {
//            //            self.pk = [NSNumber numberWithLongLong:db.lastInsertRowId].intValue;
//            NSLog(@"插入数据成功");
////            if (callback) {
////                callback(YES);
////            }
//        }else {
//            // 事务回滚, 并结束执行代码
//            *rollback = YES;
//            NSLog(@"插入数据失败");
////            if (callback) {
////                callback(NO);
////            }
//            return;
//        }
//    }];
//}

- (void)insertWithDatabase:(FMDatabase *)db rollback:(BOOL *)rollback associatedColumnName:(NSString *)columnName
{
    // 1. 遍历当前对象所在类的存储属性列表
    NSDictionary *dic = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
    NSDictionary *nestdic = objc_getAssociatedObject([self class], &AssociatedKey_NestPropertyList);
    
    // 1.2 可直接存储的属性
    NSMutableString *columnList = [NSMutableString string];
    NSMutableString *valueList = [NSMutableString string];
    NSMutableArray *values = [NSMutableArray array];
    
    // 1.3 上级关联字段配置
    [columnList appendFormat:@"%@,", SQL_COLUMN_NAME_SuperiorKey];
    if (columnName) // 存在与上级关联
    {
        [valueList appendFormat:@"?,"];
        [values addObject:columnName];
    }
    else
    {
        [valueList appendFormat:@"null,"];
    }
    
    // 1.4 非嵌套属性字段配置
    for (NSString *key in dic.allKeys) {
        PropertyDescription *p = dic[key];
        
        id value = [self valueForKey:p.name];
        [columnList appendFormat:@"%@,", p.name];
        if (value == nil || [value isEqual:[NSNull null]]) // 空值
        {
            [valueList appendFormat:@"null,"];
        }
        else
        {
            [valueList appendFormat:@"?,"];
            
            // 1.3 分类型
            if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
            {
                NSError *error = nil; NSData *data = nil;
                @try {
                    data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                    if (!error) {
                        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        [values addObject:jsonStr];
                    }else {
                        [values addObject:value];
                    }
                }
                @catch (NSException *e) {
                    [values addObject:value];
                }
                
            }
            else // 非集合类型
            {
                [values addObject:value];
            }
        }
    }
    
    // 清除最后一个逗号
    if (columnList.length > 0) {
        [columnList deleteCharactersInRange:NSMakeRange(columnList.length - 1, 1)];
    }
    if (valueList.length > 0) {
        [valueList deleteCharactersInRange:NSMakeRange(valueList.length - 1, 1)];
    }
    
    // 1.5 拼接当前添加类的插入sql语句
    NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", NSStringFromClass([self class]), columnList, valueList];
    
    // 1.6 执行插入语句
    BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:values];
    if (isSuccess)
    {
        NSLog(@"[%@]插入数据成功(%@)", NSStringFromClass([self class]), sqlString);
        
        // 1.6.1 主键id
        NSInteger pkID = db.lastInsertRowId;
        
        // 1.6.2 嵌套属性处理
        for (NSString *key in nestdic.allKeys)
        {
            // 1.6.2.1 属性信息对象
            PropertyDescription *p = nestdic[key];
            
            // 拼接关联字段的值
            NSString *associatedColumnValue = [NSString stringWithFormat:@"%@_%@_%ld", NSStringFromClass(self.class), p.name, pkID];
            
            // 1.6.2.2 属性值
            id value = [self valueForKey:p.name];
            
            // 1.6.2.3 判断嵌套属性集合类型
            if ([p.type isSubclassOfClass:[NSArray class]]) // 嵌套的是个数组
            {
                for (id subValue in value) {
                    if ([subValue isKindOfClass:p.associateClass]) {
                        [subValue insertWithDatabase:db rollback:rollback associatedColumnName:associatedColumnValue];
                    }
                }
            }
            else if ([p.type isSubclassOfClass:[NSDictionary class]]) // 嵌套的是个字典
            {
                
            }
            else if ([p.type isSubclassOfClass:p.associateClass]) // 嵌套的是类
            {
                [value insertWithDatabase:db rollback:rollback associatedColumnName:associatedColumnValue];
            }
            else // 其他
            {
                
            }
        }
    }
    else
    {
        NSLog(@"[%@]插入数据失败(%@)", NSStringFromClass([self class]), sqlString);
        *rollback = YES;
    }
}
- (void)addWithSuperiorID:(NSInteger)superiorID superiorClass:(Class)superiorClass superiorProperty:(NSString *)superiorProperty db:(FMDatabase *)db
{
    // 1. 遍历当前对象所在类的存储属性列表
    NSDictionary *dic = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
    NSDictionary *nestdic = objc_getAssociatedObject([self class], &AssociatedKey_NestPropertyList);
    
    // 1.2 可直接存储的属性
    NSMutableString *columnList = [NSMutableString string];
    NSMutableString *valueList = [NSMutableString string];
    NSMutableArray *values = [NSMutableArray array];
    
    // 1.3 上级关联字段配置
    [columnList appendFormat:@"%@,", SQL_COLUMN_NAME_SuperiorKey];
    if (superiorID > 0) // 存在与上级关联
    {
        [valueList appendFormat:@"?,"];
        [values addObject:[NSString stringWithFormat:@"%@_%@_%ld", NSStringFromClass(superiorClass), superiorProperty, superiorID]];
    }
    else
    {
        [valueList appendFormat:@"null,"];
    }
    
    // 1.4 非嵌套属性字段配置
    for (NSString *key in dic.allKeys) {
        PropertyDescription *p = dic[key];
        
        id value = [self valueForKey:p.name];
        [columnList appendFormat:@"%@,", p.name];
        if (value == nil || [value isEqual:[NSNull null]]) // 空值
        {
            [valueList appendFormat:@"null,"];
        }
        else
        {
            [valueList appendFormat:@"?,"];
            
            // 1.3 分类型
            if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
            {
                NSError *error = nil; NSData *data = nil;
                @try {
                    data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                    if (!error) {
                        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        [values addObject:jsonStr];
                    }else {
                        [values addObject:value];
                    }
                }
                @catch (NSException *e) {
                    [values addObject:value];
                }
                
            }
            else // 非集合类型
            {
                [values addObject:value];
            }
        }
    }
    
    // 清除最后一个逗号
    if (columnList.length > 0) {
        [columnList deleteCharactersInRange:NSMakeRange(columnList.length - 1, 1)];
    }
    if (valueList.length > 0) {
        [valueList deleteCharactersInRange:NSMakeRange(valueList.length - 1, 1)];
    }
    
    // 1.5 拼接当前添加类的插入sql语句
    NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", NSStringFromClass([self class]), columnList, valueList];
    
    // 1.6 执行插入语句
    BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:values];
    if (isSuccess)
    {
        NSLog(@"[%@]插入数据成功(%@)", NSStringFromClass([self class]), sqlString);
        
        // 1.6.1 主键id
        NSInteger pkID = db.lastInsertRowId;
        
        // 1.6.2 嵌套属性处理
        for (NSString *key in nestdic.allKeys)
        {
            // 1.6.2.1 属性信息对象
            PropertyDescription *p = nestdic[key];
            
            // 1.6.2.2 属性值
            id value = [self valueForKey:p.name];
            
            // 1.6.2.3 判断嵌套属性集合类型
            if ([p.type isKindOfClass:[NSArray class]]) // 嵌套的是个数组
            {
                for (id subValue in value) {
                    if ([subValue isKindOfClass:p.associateClass]) {
                        [value addWithSuperiorID:pkID superiorClass:self.class superiorProperty:p.name db:db];
                    }
                }
            }
            else if ([p.type isKindOfClass:[NSDictionary class]]) // 嵌套的是个字典
            {
                
            }
            else if ([p.type isKindOfClass:p.associateClass]) // 嵌套的是类
            {
                [value addWithSuperiorID:pkID superiorClass:self.class superiorProperty:p.name db:db];
            }
            else // 其他
            {
                
            }
        }
    }
    else
    {
        NSLog(@"[%@]插入数据成功(%@)", NSStringFromClass([self class]), sqlString);
    }
}

// FIXME: 新增
/// 增
- (void)add:(void(^)(BOOL isSuccess))callback
{
    [self.class configPropertyAndTable];
    
    [[DBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        [self insertWithDatabase:db rollback:rollback associatedColumnName:nil];
    }];
    
    
    
//    NSString *tableName = NSStringFromClass([self class]);
//    NSMutableString *columnNameString = [NSMutableString string];
//    NSMutableString *columnValueString = [NSMutableString string];
//    NSMutableArray *columnValues = [NSMutableArray array];
//
//    // 嵌套时的key与value
//    NSMutableString *nestColumnName = [NSMutableString string];
//    NSMutableArray *nestColumnValue = [NSMutableArray array];
//
//    // 取得属性名数组
//    NSDictionary *dic = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
//    NSArray *propertyNameList = dic.allKeys;
//    // 遍历需保存到数据库的属性列表
//    for (int i = 0; i < propertyNameList.count; i++) {
//        // 取得对应索引的列名
//        NSString *columnName = [propertyNameList objectAtIndex:i];
//
//        PropertyDescription *p = dic[columnName];
//
//        // 判断是否是主键, 如果是则跳出并继续循环
//        if ([columnName isEqualToString:@"pk"]) {
//            continue;
//        }
//
//        // 是否嵌套
//        if (p.associateClass) // 嵌套的话如果是集合只能是ObjectC类型所以必定实现了isSubclassOfClass:方法
//        {
//            if ([p.type isEqual:p.associateClass]) // 属性即对象
//            {
//                id obj = [self valueForKey:columnName];
//                [obj add:nil];
//
//            }
//            else if ([p.type isSubclassOfClass:[NSArray class]]) // 隶属于数组
//            {
//                NSArray *array = [self valueForKey:columnName];
//                [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                    [obj add:nil];
//                }];
//            }
//            else if ([p.type isSubclassOfClass:[NSDictionary class]]) // 隶属于字典
//            {
//
//            }
//            continue;
//        }
//
//        // 如果是基础数据类型时取出的值为NSNumber类型
//        id value = [self valueForKey:columnName];// 当NSDate被assign修饰的时候会在此处crash
//
//        // 拼接到SQL语句字符串上
//        [columnNameString appendFormat:@"%@,", columnName];
//
//        // 如果是空值则不需要拼接到sql语句中
//        if (value == nil)
//        {
//            [columnValueString appendString:@"null,"];
//        }
//        else {
//            [columnValueString appendFormat:@"?,"];
//
//            // 字符串
//            if ([p.type isSubclassOfClass:[NSString class]])
//            {
//                // 把值添加的数组中
//                [columnValues addObject:value];
//            }
//            else if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
//            {
//                NSError *error = nil; NSData *data = nil;
//                @try {
//                    data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
//                    if (!error) {
//                        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//                        [columnValues addObject:jsonStr];
//                    }else {
//                        [columnValues addObject:value];
//                    }
//                }
//                @catch (NSException *e) {
//                    [columnValues addObject:value];
//                }
//
//            }
//            else
//            {
//                // 把值添加的数组中
//                [columnValues addObject:value];
//            }
//        }
//    }
//
//    // 清除最后一个逗号
//    if (columnNameString.length > 0) {
//        [columnNameString deleteCharactersInRange:NSMakeRange(columnNameString.length - 1, 1)];
//        [columnValueString deleteCharactersInRange:NSMakeRange(columnValueString.length - 1, 1)];
//    }
//
//
//
//    // 获取管理者单例
//    DBManager *manager = [DBManager manager];
//    // 使用数据库队列执行保存操作
//    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
//        // 拼接SQL语句
//        NSString *sqlString = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, columnNameString, columnValueString];
//        NSLog(@"数据库表(%@)插入SQL语句:(%@)", tableName, sqlString);//
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-W#warnings"
//#warning 该方法第二个参数用于替代?所表示的值, 但是如果想让某个值为空则不能用?号替代添加到该数组中, 由于未知的原因如果向其内添加一个@"null"会导致实际存储的是@"null字符串"
//#pragma clang diagnostic pop
//        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:columnValues];
//        if (isSuccess) {
////            self.pk = [NSNumber numberWithLongLong:db.lastInsertRowId].intValue;
//            NSLog(@"插入数据成功");
////            if (callback) {
////                callback(YES);
////            }
//        }else {
//            // 事务回滚, 并结束执行代码
//            *rollback = YES;
//            NSLog(@"插入数据失败");
////            if (callback) {
////                callback(NO);
////            }
//            return;
//        }
//    }];
}

// FIXME: 更改
/// 改
- (void)update:(void(^)(BOOL isSuccess))callback
{
    [self.class configPropertyAndTable];
    
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
    NSMutableString *sql_ColumnName = [NSMutableString string]; // 字段名
    NSMutableArray *columnValueList = [NSMutableArray array];
    // 取得属性名列表
    NSDictionary *dic = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
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
            [sql_ColumnName appendFormat:@"%@=null,", p.name];
        }
        else {
            [sql_ColumnName appendFormat:@"%@=?,", p.name];
            
            // 字符串
            if ([p.type isSubclassOfClass:[NSString class]])
            {
                // 把值添加的数组中
                [columnValueList addObject:value];
            }
            else if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
            {
                NSError *error = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                if (!error) {
                    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [columnValueList addObject:jsonStr];
                }else {
                    [columnValueList addObject:value];
                }
            }
            else
            {
                // 把值添加的数组中
                [columnValueList addObject:value];
            }
        }
    }
    
    // 清除最后一个逗号
    if (sql_ColumnName.length > 0) {
        [sql_ColumnName deleteCharactersInRange:NSMakeRange(sql_ColumnName.length - 1, 1)];
    }
    
    // SQL语句
    NSString *sqlString = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE pk = %@;", tableName, sql_ColumnName, [self valueForKey:@"pk"]];
    NSLog(@"数据库表(%@)更新SQL语句:(%@)", tableName, sqlString);
    // 获取管理者单例
    DBManager *manager = [DBManager manager];
    // 使用数据库队列执行保存操作
    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 使用数据库事务执行SQL语句
        BOOL isSuccess = [db executeUpdate:sqlString withArgumentsInArray:columnValueList];

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

+ (NSArray *)searchBySqlString:(NSString *)sql inDatabase:(FMDatabase *)db
{
    // 1. 根据条件查找结果集
    FMResultSet *resultSet = [db executeQuery:sql];
    
    
    // 2. 被保存属性列表与嵌套属性列表
    NSDictionary *storeDic = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
    NSDictionary *nestDic = objc_getAssociatedObject([self class], &AssociatedKey_NestPropertyList);
    
    // 2.1 初始化一个可变数组保存转变完的模型
    NSMutableArray *resultModels = [NSMutableArray array];
    
    // 3. 遍历结果集(结果集中是一条条数据[数据中不包含嵌套的属性])
    while ([resultSet next]) // 当结果集中仍然有下一条数据时进入循环
    {
        // 3.1 一条数据转为字典[key为字段名, value是字段值]
        NSDictionary *dic = [resultSet resultDictionary];
        
        // 3.2 初始化一个当前类的对象
        id model = [[self alloc] init];
        
        // 3.2.1 主键和上级关联值 直接赋值
        NSInteger pk = [[dic valueForKey:SQL_COLUMN_NAME_PrimaryKey] integerValue];
        [model setPrimaryKeyValue:pk];
        NSString *superiorKey = [dic valueForKey:SQL_COLUMN_NAME_SuperiorKey];
        [model setSuperiorKeyValue:superiorKey];
        
        // 3.3 遍历被保存属性列表(数据库表中字段可能多于当前类的属性值)
        for (NSString *key in storeDic.allKeys)
        {
            // 3.3.1 取得对应value值
            PropertyDescription *p = storeDic[key];
            
            // 3.3.2 分类判断
            if ([p.typeName isEqualToString:SYPropertyType_Integer]) // 整型
            {
                long long value = [[dic valueForKey:p.name] longLongValue];
                [model setValue:[NSNumber numberWithLongLong:value] forKey:p.name];
            }
            else if ([p.typeName isEqualToString:SYPropertyType_CGFloat]) // 浮点型
            {
                double value = [[dic valueForKey:p.name] doubleValue];
                [model setValue:[NSNumber numberWithDouble:value] forKey:p.name];
            }
            else if ([p.type isSubclassOfClass:[NSString class]]) // 字符串类型
            {
                NSString *value = [dic valueForKey:p.name];
                [model setValue:(p.isMutable ? value.mutableCopy : value) forKey:p.name];
            }
            else // 正常OC类型, 保存为二进制数据
            {
                if (p.type != nil && ![p.type isKindOfClass:[NSNull class]]) {
                    id value = [dic objectForKey:p.typeName];
                    
                    if (![value isKindOfClass:[NSNull class]] && value != nil) {
                        
                        // 字符串
                        if ([p.type isSubclassOfClass:[NSString class]])
                        {
                            [model setValue:value forKey:p.typeName];
                        }
                        // 数组 || 字典
                        else if ([p.type isSubclassOfClass:[NSArray class]] || [p.type isSubclassOfClass:[NSDictionary class]])
                        {
                            NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
                            NSError *error = nil;
                            id objc = [NSJSONSerialization JSONObjectWithData:valueData options:kNilOptions error:&error];
                            if (error) {
                                NSLog(@"反序列化失败");
                                continue;
                            }
                            [model setValue:objc forKey:p.name];
                        }
                    }
                }
            }
        }
        
        // 3.4 遍历嵌套的属性集合
        for (NSString *key in nestDic.allKeys)
        {
            // 3.4.1 获取属性信息对象
            PropertyDescription *p = nestDic[key];
            
            // 3.4.2 对嵌套数据进行解析
            NSString *tableName = NSStringFromClass(self);
            NSString *propertyName = p.name;
            NSInteger dataID = [model primaryKeyValue];
            NSString *subTableName = NSStringFromClass(p.associateClass);
            
            // 3.4.3 拼接sql语句
            NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ where %@ = '%@';", subTableName, SQL_COLUMN_NAME_SuperiorKey, [NSString stringWithFormat:@"%@_%@_%ld", tableName, propertyName, dataID]];
            
            // 3.4.4 执行嵌套逻辑
            NSArray *resultModelArray = [p.associateClass searchBySqlString:sql inDatabase:db];
            
            // 3.4.5 判断嵌套属性的类型
            if ([p.type isSubclassOfClass:[NSArray class]]) // 数组
            {
                if (resultModelArray.count > 0) {
                    [model setValue:resultModelArray forKey:p.name];
                }
            }
            else if ([p.type isSubclassOfClass:[NSDictionary class]]) // 字典
            {
                
            }
            else if ([p.type isSubclassOfClass:p.associateClass]) // 嵌套类
            {
                // 取出数组中第一个值赋给作为嵌套类的属性
                if (resultModelArray.count > 0) {
                    [model setValue:resultModelArray.firstObject forKey:p.name];
                }
            }
        }
        
        [resultModels addObject:model];
        FMDBRelease(model);
    }
    
    
    return resultModels;
}

/// 查询--仅限嵌套的属性与数组
+ (void)searchBySqlString:(NSString *)sql result:(void(^)(NSArray *result))result
{
    // 1. 配置属性信息与数据库表
    [self configPropertyAndTable];
    
    // 2. 调起数据队列的事务方法
    [[DBManager manager].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *sqlString = [NSString stringWithFormat:@"SELECT * FROM %@ %@;", NSStringFromClass(self), sql];
        
        NSArray *array = [self searchBySqlString:sqlString inDatabase:db];
        if (result) {
            result(array);
        }
    }];
}

// FIXME: 查询
/// 查
+ (NSArray *)findByCondition:(NSString *)condition
{
    [self.class configPropertyAndTable];
    
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
        
        // 需保存的属性
        NSDictionary *associatedDic = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
        
        // 当前类需保存的属性名数组
        NSArray *list = associatedDic.allKeys;
        
        // 遍历结果集
        while ([resultSet next]) {
            id model = [[[self class] alloc] init];
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
                    int pk = [[dic valueForKey:@"pk"] respondsToSelector:@selector(intValue)] ? [[dic valueForKey:@"pk"] intValue] : 0;
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

// FIXME: 删除
/// 删
+ (void)removeByCondition:(NSString *)condition callback:(void(^)(BOOL isSuccess))callback
{
    [self.class configPropertyAndTable];
    
    // 取得数据库管理者
    DBManager *manager = [DBManager manager];
    
    // 获得当前类的名称
    NSString *tableName = NSStringFromClass([self class]);
    // 获取删除操作的SQL语句
    NSString *sqlString = [NSString stringWithFormat:@"DELETE FROM %@ %@%@", tableName, (condition ? condition : @""), (condition ? ([condition hasSuffix:@";"] ? @"" : @";") : @";")];
    // 删除之前先搜索是否有达到该条件的数据
    NSArray *result = [[self class] findByCondition:condition];
    if (result.count == 0) {
        NSLog(@"从数据库表(%@)中未找到符合(sql:%@)SQL语句的可删除项", NSStringFromClass([self class]), sqlString);
        if (callback) {
            callback(NO);
        }
        return;
    }
    
    // 通过数据库队列执行事务
    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        // 判断操作执行是否成功
        BOOL isSuccess = [db executeUpdate:sqlString];
        if (isSuccess) { // 执行删除操作成功
            NSLog(@"删除成功");
            if (callback) {
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

// FIXME: 删除
/// 删除
- (void)remove:(void(^)(BOOL isSuccess))callback
{
    [self.class configPropertyAndTable];
    
//    if (self.pk <= 0) {
//        if (callback) {
//            NSLog(@"该数据没有保存到数据库中");
//            callback(NO); // 新增数据没有保存到数据库中
//        }
//        
//        return;
//    }
//    
//    [[self class] removeByCondition:[NSString stringWithFormat:@"where pk = %d;", self.pk] callback:callback];
}

#pragma mark- <-----------  扩展的数据库操作  ----------->
/// 整合保存和更新到一个方法中
- (void)save:(void (^)(BOOL))callback
{
    [self.class configPropertyAndTable];
    
    // 取得主键的值
    NSInteger pkValue = [self primaryKeyValue];
    // 如果主键的值小于等于0表示新增的一条数据还未保存到数据库因此没有赋值
    if (pkValue <= 0) {
        [self add:callback];
    }else { // 已经有值, 表示该条数据是修改数据库的值
        [self update:callback];
    }
}




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

//
//
//static objc_property_attribute_t getAttribute(NSString *str) {
//
//    NSScanner *scanner = [NSScanner scannerWithString:str];
//    NSString *name = nil;
//    NSString *value = nil;
//
//
//    // 扫描从T开始
//    [scanner scanUpToString:@"T" intoString:nil]; // 索引指向T的下一位
//    [scanner scanString:@"T" intoString:nil]; // 只是为了让索引指向T的下一位
//
//    // 判断该属性的属性字符串类型
//    if ([scanner scanString:@"T" intoString:&name]) {
//        if ([scanner scanString:@"@\"" intoString:&value]) { // Object类型
//            [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&value];
//        }else { // 基础数据类型、Block、结构体
//            value = [str substringFromIndex:1];
//        }
//        const char *charValue = [value UTF8String];
//        objc_property_attribute_t attribute = {"T",charValue};
//        return attribute;
//    }
//    else if ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"C&W"] intoString:&name]) // 编码类型
//    {
//        const char *charName = [name UTF8String];
//        objc_property_attribute_t attribute = {charName,""};
//        return attribute;
//    }
//    else if ([scanner scanString:@"N" intoString:&name]) // 非/原子性
//    {
//        const char *charName = [name UTF8String];
//        objc_property_attribute_t attribute = {charName,""};
//        return attribute;
//    }
//    else if ([scanner scanString:@"V" intoString:&name]) // 变量名称
//    {
//        value = [str substringFromIndex:1];
//        const char *charValue = [value UTF8String];
//        objc_property_attribute_t attribute = {"V",charValue};
//        return attribute;
//    }
//
//    objc_property_attribute_t attribute = {"",""};
//    return attribute;
//}


__attribute__((constructor)) static void _append_default_implement_method_to_class1() {
    unsigned classCount;
    
    Class *classes = objc_copyClassList(&classCount);
    //第一层遍历所有的类
    for (int i = 0; i < classCount; i ++) {
        // 被添加类
        Class class = classes[i];
        Class metaClass = object_getClass(class);
        
        unsigned protocolCount;
        Protocol * __unsafe_unretained *protocols = class_copyProtocolList(class, &protocolCount);
        //第二层遍历类中所有的协议
        for (int j = 0; j < protocolCount; j ++) {
            Protocol *protocol = protocols[j];
            NSString *protocolName = [NSString stringWithFormat:@"%s", protocol_getName(protocol)];
            // 协议名不正确或者类名是临时类则跳过
            if (![protocolName isEqualToString:@"DBModelProtocol"] || [NSStringFromClass(class) isEqualToString:@"DBModel"]) continue;
            
            
            // 类的实例方法转移
            unsigned methodCount;
            // 待转移方法的类
            Class tempClass = objc_getClass(NSStringFromClass([DBModel class]).UTF8String);
            Method *methods = class_copyMethodList(tempClass, &methodCount);
            for (int k = 0; k < methodCount; k ++) {
                Method method = methods[k];
                class_addMethod(class, method_getName(method), method_getImplementation(method), method_getTypeEncoding(method));
//                NSLog(@"实例方法名:%@", [NSString stringWithCString:sel_getName(method_getName(method)) encoding:NSUTF8StringEncoding]);
            }
            free(methods);
            
            
            // 类的类方法转移
            unsigned metaMethodCount;
            Class metaTempClass = object_getClass(tempClass);
            Method *metaMethods = class_copyMethodList(metaTempClass, &metaMethodCount);
            for (int k = 0; k < metaMethodCount; k ++) {
                Method method = metaMethods[k];
                class_addMethod(metaClass, method_getName(method), method_getImplementation(method), method_getTypeEncoding(method));
//                NSLog(@"类方法名:%@", [NSString stringWithCString:sel_getName(method_getName(method)) encoding:NSUTF8StringEncoding]);
            }
            free(metaMethods);
            
            // 类的实例属性转移
            unsigned propertyCount;
            objc_property_t *propertyList = class_copyPropertyList(tempClass, &propertyCount);
            // 遍历临时类的所有属性并添加
            for (int k = 0; k < propertyCount; k++) {
                objc_property_t  property = propertyList[k];
                unsigned int attributeCount = 0;
                objc_property_attribute_t *attributeList = property_copyAttributeList(property, &attributeCount);
                const char *name = property_getName(property);
                class_addProperty(class, name, attributeList, attributeCount);
                
                
//                NSString *attributes = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
//                // 拆分为一个数组
//                NSArray *arr = [attributes componentsSeparatedByString:@","];
//                int index = 0;
//                for (id ob in arr) {
//                    index++;
//                }
//                objc_property_attribute_t *attrs = (objc_property_attribute_t *)malloc(sizeof(objc_property_attribute_t) *index);
//                for (int j = 0; j < index; j++) {
//                    objc_property_attribute_t attribute = attributeList[j];
//                    if (strcmp(attribute.name, "G") == 0) {
//                        NSString *selectorName = [NSString stringWithUTF8String:attribute.value];
//                        SEL selector = NSSelectorFromString(selectorName);
//
//                    }
//                    else if (strcmp(attribute.name, "S") == 0) {
//                        NSString *selectorName = [NSString stringWithUTF8String:attribute.value];
//                        SEL selector = NSSelectorFromString(selectorName);
//                        const char *value = [selectorName UTF8String];
//                        objc_property_attribute_t setter = {"S",value};
//                    }
//                    // 字符串取出
//                    NSString *string = arr[j];
//
//                    objc_property_attribute_t att = getAttribute(string);
//                    attrs[j] = att;
//                }
//
//                // 添加属性到
//                class_addProperty(class, property_getName(property), attrs, index);
            }
        }
        free(protocols);
    }
    free(classes);
    
    
    // 配置一遍属性信息列表以及数据库
    
}


///// 创建并更新表 -- 字段只增不减
//+ (void)createTable:(void(^)(BOOL isSuccess))createBlock updateTable:(void(^)(SQLTableUpdateType type))updateBlock
//{
//    // 获得数据库管理者对象
//    DBManager *manager = [DBManager manager];
//    // 根据管理者对象的数据库队列属性开启事务
//    [manager.databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
//        // 获取当前类的名称
//        NSString *tableName = NSStringFromClass(self);
//
//        BOOL isExist = [db tableExists:tableName];
//        if (!isExist) {
//            // 创建表语句
//            NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);", tableName, [[self class] propertyNameAndTypeString]];
//            // 执行创建表语句并判断是否创建成功
//            BOOL isSuccess = [db executeUpdate:sql];
//            if (!isSuccess) { // 如果没有创建成功
//                // 事务回滚, 并结束执行代码
//                *rollback = YES;
//                if (createBlock) {
//                    createBlock(NO);
//                }
//                return;
//            }
//            NSLog(@"创建数据库表(%@)成功", sql);
//        }else {
//            NSLog(@"数据库表(%@)已存在", tableName);
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
//        // 获取当前版本该类的所有属性列表
//        NSDictionary *dic = objc_getAssociatedObject(self, &AssociatedKey_AllPropertyList);
//
//        // 获取其属性名列表
//        NSArray *propertyNameList = dic.allKeys;
//        // 初始化一个谓词来筛选不在表中的字段
//        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", columnNames];
//        // 用当前版本类的需保存属性列表调用筛选
//        NSArray *unsavedProperties = [propertyNameList filteredArrayUsingPredicate:filterPredicate];
//
//        // 遍历未添加到数据库中的字段列表
//        for (NSString *columnName in unsavedProperties) {
//            // 取得该列名对应的数据类型
//            PropertyDescription *p = dic[columnName];
//
//            if ([p.name isEqualToString:@"pk"]) continue;
//            // 采用SQL语句添加新的字段到当前数据库表中
//            NSString *sqlString = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@;", tableName, columnName, p.sqlTypeName];
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


//+ (void)initialize
//{
//    NSLog(@"调用initialize方法的类名:%@", NSStringFromClass([self class]));
//    if (self != [DBModel class])
//    {
//        NSLog(@"不是DBModel类");
//
//        // 配置继承树上属性信息列表与字段映射表
//        [self config];
//
//        // 根据属性列表创建或更新数据库表
//        [self createTable:nil updateTable:nil];
//    }
//    else
//    {
//    }
//}
//
//- (instancetype)init
//{
//    self = [super init];
//    if (self) {
////
////        // 根据属性列表创建或更新数据库表
////        [self createTable:nil updateTable:nil];
//    }
//
//    return self;
//}
