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
#import "GZStoreError.h"

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

@interface DBModel()
{
    /// 数据在表中的主键值(不能设置为静态的, 静态会导致所有取到的值都是同一个)
    NSInteger AssociatedKey_PrimaryKey;
    
    /// 与上级表关联的字段
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



/// 检查属性列表 -- 收集属性信息
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
        p.name = name;
        
        // 属性描述信息
        NSString *attributes = [NSString stringWithCString:property_getAttributes(property) encoding:NSUTF8StringEncoding];
        NSArray *items = [attributes componentsSeparatedByString:@","];
        
        // 只读
        if ([items containsObject:@"R"]) { p.isReadOnly = YES;}
        
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
            
            if ([propertyType isEqualToString:@""]) // id类型且遵守了某些协议
            {
                p.sqlTypeName = @"BLOB";
                p.notOcType = @"id";
                p.classify = STORE_PROPERTY_TYPE_ID;
            }
            else // OC类型
            {
                p.classify = STORE_PROPERTY_TYPE_OBJECT;
                // 赋值属性类型 -- 如果是自定义的类型, 则此处取不到类型
                p.ocType = NSClassFromString(propertyType);
                // 是否可变
                p.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
                
                // 属于字符串
                if ([p.ocType isSubclassOfClass:[NSString class]]) // 字符串系可直接保存为TEXT格式
                {
                    p.sqlTypeName = @"TEXT";
                }
                else if ([p.ocType isSubclassOfClass:[NSNumber class]]) // NSNumber类型可保存为浮点型
                {
                    p.sqlTypeName = @"REAL";
                }
                else // 其余ObjectC类型保存为二进制格式
                {
                    p.sqlTypeName = @"BLOB";
                }
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
        }
        else if ([scanner scanString:@"@?" intoString:nil]) // Block
        {
            p.notOcType = @"Block";
            // Block分类
            p.classify = STORE_PROPERTY_TYPE_BLOCK;
            p.isIgnore = YES; // Block自动划入忽略项
        }
        else if ([scanner scanString:@"@" intoString:nil]) // id类型(表指针) 此时属性没有遵守任何协议格式为:T@,
        {
            p.sqlTypeName = @"BLOB";
            p.notOcType = @"id";
            p.classify = STORE_PROPERTY_TYPE_ID;
        }
        else if ([scanner scanString:@"{" intoString:&propertyType]) // 结构体
        {
            // 截取结构体名 -- T{MyStruct=}格式, 从{开始到=号结束, 其中=号可能是任意数字或字母(不区分大小写)
            [scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&propertyType];
            p.notOcType = [NSString stringWithFormat:@"Struct_%@", propertyType];
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
        p.notOcType = @"int64_t";
    }
    else if ([type isEqualToString:@"i"]) // int32位类型、int类型
    {
        p.sqlTypeName = @"INTEGER";
        p.notOcType = @"int32_t";
    }
    else if ([type isEqualToString:@"s"]) // int16位类型
    {
        p.sqlTypeName = @"INTEGER";
        p.notOcType = @"int16_t";
    }
    else if ([type isEqualToString:@"c"]) // int8位类型
    {
        p.sqlTypeName = @"INTEGER";
        p.notOcType = @"int8_t";
    }
    else if ([type isEqualToString:@"f"]) // 单精度float类型
    {
        p.sqlTypeName = @"REAL";
        p.notOcType = @"float";
    }
    else if ([type isEqualToString:@"d"]) // 双精度double类型、双精度CGFloat
    {
        p.sqlTypeName = @"REAL";
        p.notOcType = @"double";
    }
    else if ([type isEqualToString:@"B"]) // BOOL类型
    {
        p.sqlTypeName = @"INTEGER";
        p.notOcType = @"BOOL";
    }
    else { // 其他类型
        p.sqlTypeName = @"INTEGER";
        p.notOcType = @"int";
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

// FIXME: 新增
/// 增
- (BOOL)insertWithError:(NSError *__autoreleasing*)error
{
    [self.class configPropertyAndTable];
    
    // 1. 判断该数据主键ID是否大于0
    if ([self primaryKeyValue] > 0) {
        *error = [NSError errorWithDomain:GZStoreInsertError code:GZStoreErrorExistInTable userInfo:@{NSLocalizedDescriptionKey: @"插入数据失败, 该条数据在表中已存在"}];
        return NO;
    }
    
    // 2. 数据库中进行操作
    __block BOOL result = YES;
    [[DBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self insertWithAssociatedFieldValue:nil database:db rollback:rollback error:error];
    }];
    
    return result;
}

- (BOOL)insertWithAssociatedFieldValue:(NSString *)fieldValue database:(FMDatabase *)db rollback:(BOOL *)rollback error:(NSError **)error
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
    if (fieldValue) // 存在与上级关联
    {
        [valueList appendFormat:@"?,"];
        [values addObject:fieldValue];
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
            if (p.ocType != nil && ![p.ocType isSubclassOfClass:[NSNull class]]) // OC对象
            {
                if ([p.ocType isSubclassOfClass:[NSArray class]] || [p.ocType isSubclassOfClass:[NSDictionary class]]) // 数组或字典
                {
                    // 1.3.1 尝试进行JSON序列化, 如果不成功则直接保存为二进制数据
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
            else if (p.notOcType != nil && ![p.notOcType isKindOfClass:[NSNull class]]) // 非OC对象
            {
                [values addObject:value];
            }
            else
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
        NSLog(@"[%@]未嵌套部分插入数据成功(%@)", NSStringFromClass([self class]), sqlString);
        
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
            if ([p.ocType isSubclassOfClass:[NSArray class]]) // 嵌套的是个数组
            {
                // 遍历数组来依次配置嵌套的对象
                for (id subValue in value) {
                    if ([subValue isKindOfClass:p.associateClass]) {
                        BOOL result = [subValue insertWithAssociatedFieldValue:associatedColumnValue database:db rollback:rollback error:error];
                        // 如果嵌套的对象插入不成功，则回滚
                        if (result == NO) {
                            *rollback = YES;
                            return NO;
                        }
                    }
                }
            }
            else if ([p.ocType isSubclassOfClass:[NSDictionary class]]) // 嵌套的是个字典
            {
                if (error) {
                    *error = [NSError errorWithDomain:GZStoreInsertError
                                                 code:GZStoreErrorNonsupportType
                                             userInfo:@{NSLocalizedDescriptionKey:@"嵌套类型为字典, 该功能暂不支持"}];
                }
                NSLog(@"[%@]插入数据失败: 属性名为:[%@]的类型暂不支持(%@)", NSStringFromClass(self.class), p.name, sqlString);
                *rollback = YES;
                return NO;
            }
            else if ([p.ocType isSubclassOfClass:p.associateClass]) // 直接嵌套
            {
                BOOL result = [value insertWithAssociatedFieldValue:associatedColumnValue database:db rollback:rollback error:error];
                if (result == NO) {
                    *rollback = YES;
                    return NO;
                }
            }
            else // 其他
            {
                if (error) {
                    *error = [NSError errorWithDomain:GZStoreInsertError
                                                 code:GZStoreErrorNonsupportType
                                             userInfo:@{NSLocalizedDescriptionKey:@"嵌套类型未知, 暂不支持该类型"}];
                }
                NSLog(@"[%@]插入数据失败: 属性名为:[%@]的类型暂不支持(%@)", NSStringFromClass(self.class), p.name, sqlString);
                *rollback = YES;
                return NO;
            }
        }
    }
    else
    {
        NSLog(@"[%@]插入数据失败:sql语句错误(%@)", NSStringFromClass([self class]), sqlString);
        if (error) {
            *error = [NSError errorWithDomain:GZStoreInsertError
                                         code:GZStoreErrorSQLString
                                     userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"[%@]插入数据失败:sql语句错误(%@)", NSStringFromClass([self class]), sqlString]}];
        }
        *rollback = YES;
        return NO;
    }
    
    return YES;
}




// FIXME: 更改
/// 改
- (BOOL)updateWithError:(NSError *__autoreleasing*)error
{
    // 1. 判断主键是否大于0[1.大于0表示该值在数据库中原本存在可以更新、2.不大于0表示该值在数据库中不存在]
    if ([self primaryKeyValue] <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:GZStoreUpdateError code:GZStoreErrorNotInTable userInfo:@{NSLocalizedDescriptionKey: @"该数据在数据表中不存在"}];
        }
        NSLog(@"[%@]该对象不在数据库中", NSStringFromClass(self.class));
        return NO;
    }
    
    // 2. 更新数据库数据
    __block BOOL result = YES;
    [[DBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self updateWithError:error database:db rollback:rollback];
    }];
    
    return result;
}


- (BOOL)updateWithError:(NSError **)error database:(FMDatabase *)db rollback:(BOOL *)rollback
{
    // 1. 非嵌套部分update
    NSDictionary *unNestPart = objc_getAssociatedObject([self class], &AssociatedKey_StorePropertyList);
    
    // 1.0 初始化拼接用源
    NSMutableArray *valueList = [NSMutableArray array];
    NSMutableString *columnString = [NSMutableString string];
    
    // 1.1 遍历非嵌套部分字段
    for (NSString *key in unNestPart.allKeys)
    {
        // 1.1.2 属性信息对象
        PropertyDescription *p = unNestPart[key];
        
        // 1.1.3 只读略过
        if (p.isReadOnly) continue;
        
        // 1.1.4 对应属性的值
        id value = [self valueForKey:p.name];
        
        // 1.1.5 空值传入null
        if (value == nil || [value isKindOfClass:[NSNull class]]) {
            [columnString appendFormat:@"%@=null,", p.name];
            continue;
        }
        
        // 1.1.6 非空值
        [columnString appendFormat:@"%@=?,", p.name];
        
        // 1.1.7 属性类型判断
        if ([p.ocType isSubclassOfClass:[NSArray class]] || [p.ocType isSubclassOfClass:[NSDictionary class]]) {
            NSError *error = nil; NSData *data = nil;
            @try {
                // OC对象JSON序列化
                data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
                if (!error) {
                    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    [valueList addObject:jsonStr];
                }else {
                    [valueList addObject:value];
                }
            }
            @catch (NSException *e) {
                [valueList addObject:value];
            }
            continue;
        }
        
        // 1.1.8 其他类型直接添加
        [valueList addObject:value];
    }
    
    // 1.2 移除最后一个逗号
    if (columnString.length > 0) {
        [columnString deleteCharactersInRange:NSMakeRange(columnString.length - 1, 1)];
    }
    
    // 1.3 整理更新的sql语句
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = %ld;", NSStringFromClass(self.class), columnString, SQL_COLUMN_NAME_PrimaryKey, [self primaryKeyValue]];
    
    // 1.4 执行sql语句
    BOOL isSuccess = [db executeUpdate:sql withArgumentsInArray:valueList];
    if (isSuccess) {
        NSLog(@"[%@]表更新成功(%@)", NSStringFromClass(self.class), sql);
    }else {
        // 事务回滚, 并结束执行代码
        NSLog(@"[%@]表更新失败(%@)", NSStringFromClass(self.class), sql);
        if (error) {
            *error = [NSError errorWithDomain:GZStoreUpdateError code:GZStoreErrorSQLString userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"[%@]表因sql语句错误更新失败(%@)", NSStringFromClass(self.class), sql]}];
        }
        *rollback = YES;
        return NO;
    }
    
    // 2. 嵌套部分进一步判断
    NSDictionary *nestPart = objc_getAssociatedObject([self class], &AssociatedKey_NestPropertyList);
    
    // 2.1 遍历嵌套部分
    for (NSString *key in nestPart.allKeys)
    {
        // 2.1.1 属性信息对象
        PropertyDescription *p = nestPart[key];
        
        // 2.1.2 是以什么类型嵌套的(直接嵌套、数组嵌套、字典嵌套)
        if ([p.associateClass isSubclassOfClass:p.ocType]) // 直接嵌套
        {
            // 2.1.2.1 取得对应属性的值
            id value = [self valueForKey:p.name];
            
            if (![value isKindOfClass:p.associateClass]) {
                // value类型与属性类型不匹配
                if (error) {
                    *error = [NSError errorWithDomain:GZStoreUpdateError code:GZStoreErrorTypeUnMatchBetweenObjAndProperty userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"[%@]错误原因:类型不匹配, [%@]属性类型是:%@, 实际上对象类型是:%@", NSStringFromClass(self.class), p.name, NSStringFromClass(p.associateClass), NSStringFromClass(value)]}];
                }
                *rollback = YES;
                return NO;
            }
            
            // 2.1.2.2 主键值与关联值
            NSInteger pk = [value primaryKeyValue];
            NSString *associatedValue_Object = [value superiorKeyValue]; // 与上级嵌套表的关联值
            NSString *associatedValue_Splice = [NSString stringWithFormat:@"%@_%@_%ld", NSStringFromClass(self.class), p.name, [self primaryKeyValue]]; // 由上级内容信息拼接到的值
            
            // 2.1.2.3 更新内容为新值(新值或数据表中别的值)
            if (pk <= 0 || ![associatedValue_Object isEqualToString:associatedValue_Splice])
            {
                // 假如原关联内容存在, 则移除
                NSString *sql = [NSString stringWithFormat:@"select * from %@ where %@ = '%@'", NSStringFromClass(p.associateClass), SQL_COLUMN_NAME_SuperiorKey, associatedValue_Splice];
                NSArray *array = [p.associateClass searchBySqlString:sql inDatabase:db error:error];
                if (array.count > 0) {
                    if (![self removeAllDataFromArray:array error:error database:db rollback:rollback]) // 如果移除未成功回滚
                    {
                        return NO;
                    }
                }
                
                // 添加新的内容到数据库中
                if (![value insertWithAssociatedFieldValue:associatedValue_Splice database:db rollback:rollback error:nil]) // 如果添加未成功回滚
                {
                    return NO;
                }
                continue;
            }
            
            // 2.1.2.5 拼接的值与关联值一致时, 表示该值是原来的值可以直接更新, 再次进入这个循环
            if (![value updateWithError:error database:db rollback:rollback]) return NO;
        }
        else if ([p.ocType isSubclassOfClass:[NSArray class]]) // 以数组形式嵌套
        {
            // 移除当前该数组属性下所有关联的数据库中内容
            id value = [self valueForKey:p.name];
            if (![value isKindOfClass:[NSArray class]]) {
                if (error) {
                    *error = [NSError errorWithDomain:GZStoreUpdateError code:GZStoreErrorTypeUnMatchBetweenObjAndProperty userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"[%@]错误原因:类型不匹配, [%@]属性类型是:%@, 实际上对象类型是:%@", NSStringFromClass(self.class), p.name, NSStringFromClass(p.associateClass), NSStringFromClass(value)]}];
                }
                *rollback = YES;
                return NO;
            }
            
            NSString *associatedValue_Splice = [NSString stringWithFormat:@"%@_%@_%ld", NSStringFromClass(self.class), p.name, [self primaryKeyValue]]; // 由上级内容信息拼接到的值
            NSString *sql = [NSString stringWithFormat:@"select * from %@ where %@ = '%@'", NSStringFromClass(p.associateClass), SQL_COLUMN_NAME_SuperiorKey, associatedValue_Splice];
            NSArray *array = [p.associateClass searchBySqlString:sql inDatabase:db error:error];
            if (array.count > 0) {
                if (![self removeAllDataFromArray:array error:error database:db rollback:rollback]) // 如果移除未成功回滚
                {
                    return NO;
                }
            }
            
            // 添加新的与该属性关联的内容到数据库中
            NSString *field = [NSString stringWithFormat:@"%@_%@_%ld", NSStringFromClass(self.class), p.name, [self primaryKeyValue]];
            for (id v in value) {
                if (![v insertWithAssociatedFieldValue:field database:db rollback:rollback error:error]) return NO;
            }
        }
        else // 其他形式暂不支持
        {
            NSLog(@"[%@]嵌套数据更新失败,原因:不支持(%@)属性类型嵌套", NSStringFromClass(self.class), p.name);
            if (error) {
                *error = [NSError errorWithDomain:GZStoreUpdateError code:GZStoreErrorNonsupportType userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"[%@]嵌套数据更新失败,原因:不支持(%@)属性类型嵌套", NSStringFromClass(self.class), p.name]}];
            }
            *rollback = YES;
            return NO;
        }
    }
}




// FIXME: 查询

/// 查询表中所有数据
+ (NSArray *)findAllWithError:(NSError **)error
{
    return [self findByCondition:nil error:error];
}

/// 查
+ (NSArray *)findByCondition:(NSString *)condition error:(NSError * __autoreleasing *)error
{
    if (condition == nil) condition = @"";
    
    // 1. 配置属性信息与数据库表
    [self configPropertyAndTable];
    
    // 2. 调起数据队列的事务方法
    __block NSArray *array = nil;
    [[DBManager manager].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *sqlString = [NSString stringWithFormat:@"SELECT * FROM %@ %@;", NSStringFromClass(self), condition];
        
        array = [self searchBySqlString:sqlString inDatabase:db error:error];
    }];
    
    return array;
}

+ (NSArray *)searchBySqlString:(NSString *)sql inDatabase:(FMDatabase *)db error:(NSError **)error
{
    // 1. 根据条件查找结果集
    FMResultSet *resultSet = [db executeQuery:sql];
    
    // 1.1 表示查询出错
    if (resultSet == nil)
    {
        if (error) {
            *error = [NSError errorWithDomain:GZStoreSelectError code:GZStoreErrorSQLString userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"[%@]查询出错, 原因: sql语句错误(%@)", NSStringFromClass(self), sql]}];
        }
        return nil;
    }
    
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
            
            // 分为[1. OC对象(字符串、数组、字典、NSNumber、Class)、2. 非OC对象(基础数据类型、Block、结构体)]
            if (p.ocType != nil && ![p.ocType isSubclassOfClass:[NSNull class]]) // OC对象
            {
                NSString *value = [dic valueForKey:p.name];
                if (value == nil || [value isKindOfClass:[NSNull class]]) continue;
                if ([p.ocType isSubclassOfClass:[NSString class]]) // 字符串类型
                {
                    [model setValue:(p.isMutable ? value.mutableCopy : value) forKey:p.name];
                }
                else if ([p.ocType isSubclassOfClass:[NSNumber class]]) // NSNumber类型
                {
                    [model setValue:value forKey:p.name];
                }
                else if ([p.ocType isSubclassOfClass:[NSArray class]] || [p.ocType isSubclassOfClass:[NSArray class]]) // 数组或字典
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
            else if (p.notOcType != nil && ![p.notOcType isKindOfClass:[NSNull class]]) // 非OC对象
            {
                if ([p.notOcType isEqualToString:@"Block"]) continue; // block类型
                if ([p.notOcType hasPrefix:@"Struct_"]) continue; // 结构体类型
                
                // 需要做兼容(当新添加一个基础数据类型到表中时, 由于前面的数据没有该字段默认为null)
                id value = [dic valueForKey:p.name];
                if (value == nil || [value isKindOfClass:[NSNull class]]) {
                    [model setValue:@0 forKey:p.name];
                }else {
                    [model setValue:[dic valueForKey:p.name] forKey:p.name];
                }
            }
            else // 其他
            {
                [model setValue:[dic valueForKey:p.name] forKey:p.name];
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
            NSArray *resultModelArray = [p.associateClass searchBySqlString:sql inDatabase:db error:error];
            
            // 3.4.5 判断嵌套属性的类型
            if ([p.ocType isSubclassOfClass:[NSArray class]]) // 数组
            {
                if (resultModelArray.count > 0) {
                    [model setValue:resultModelArray forKey:p.name];
                }
            }
            else if ([p.ocType isSubclassOfClass:[NSDictionary class]]) // 字典
            {
                
            }
            else if ([p.ocType isSubclassOfClass:p.associateClass]) // 嵌套类
            {
                // 取出数组中第一个值赋给作为嵌套类的属性
                if (resultModelArray.count > 0) {
                    [model setValue:resultModelArray.firstObject forKey:p.name];
                }
            }
            else
            {
                
            }
        }
        
        [resultModels addObject:model];
        FMDBRelease(model);
    }
    
    
    return resultModels;
}

// FIXME: 删除
+ (BOOL)removeWithCondition:(NSString *)condition andError:(NSError *__autoreleasing*)error
{
    // 1. 配置属性信息与数据库表
    [self configPropertyAndTable];
    
    // 2. 调起数据队列的事务方法
    __block BOOL result = YES;
    [[DBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        
        // 2.1 先查找对应条件数据
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ %@;", NSStringFromClass(self), condition];
        
        // 2.2 根据要求从数据库中查找对应条件数据
        NSArray *array = [self searchBySqlString:sql inDatabase:db error:error];
        
        // 2.3 遍历结果集以便依次移除数据
        for (id subValue in array) {
            if (![subValue removeNestWithError:error database:db rollback:rollback])
            {
                result = NO;
                break;
            }
        }
    }];
    
    return result;
}

- (BOOL)removeWithError:(NSError *__autoreleasing*)error
{
    // 1. 判断数据库中是否存在该条数据
    if ([self primaryKeyValue] <= 0) {
        if (error) {
            *error = [NSError errorWithDomain:GZStoreRemoveError code:GZStoreErrorNotInTable userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"[%@]删除失败,原因:表中不存在该条数据", NSStringFromClass(self.class)]}];
        }
        return NO;
    }
    
    __block BOOL result = YES;
    // 2. 数据库队列调起事务来处理删除操作
    [[DBManager manager].databaseQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        result = [self removeNestWithError:error database:db rollback:rollback];
    }];
    
    return result;
}

- (BOOL)removeNestWithError:(NSError **)error database:(FMDatabase *)db rollback:(BOOL * _Nonnull)rollback
{
    // 1. 主键是否大于0
    if ([self primaryKeyValue] <= 0) // 数据库中不存在该条数据,因此无法完成删除操作
    {
        if (error) {
            *error = [NSError errorWithDomain:GZStoreRemoveError code:GZStoreErrorNotInTable userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"[%@]嵌套数据删除失败,原因:表中不存在该条数据", NSStringFromClass(self.class)]}];
        }
        *rollback = YES;
        return NO;
    }
    
    // 2. 删除嵌套内容
    NSDictionary *nestDic = objc_getAssociatedObject([self class], &AssociatedKey_NestPropertyList);
    
    for (NSString *key in nestDic.allKeys)
    {
        // 2.1 取得属性信息对象
        PropertyDescription *p = nestDic[key];
        
        // 2.2 嵌套的值
        id value = [self valueForKey:p.name];
        
        // 此时该属性值为空, 搜索库中该数据然后移除
        if (value == nil || [value isKindOfClass:[NSNull class]])
        {
            // 2.2.1 拼接的关联值
            NSString *columnValue = [NSString stringWithFormat:@"%@_%@_%ld", NSStringFromClass(self.class), p.name, [self primaryKeyValue]];
            
            // 2.2.2 在嵌套下级表中搜索指定关联值的内容
            NSArray *array = [[value class] searchBySqlString:[NSString stringWithFormat:@"where %@ = '%@';", SQL_COLUMN_NAME_SuperiorKey, columnValue] inDatabase:db error:error];
            
            if (![self removeAllDataFromArray:array error:error database:db rollback:rollback]) return NO;
            
            continue;
        }
        
        // 2.3 判断嵌套类型
        if ([p.associateClass isSubclassOfClass:[p.ocType class]]) // 直接嵌套
        {
            if (![value removeNestWithError:error database:db rollback:rollback]) return NO;
        }
        else if ([p.ocType isSubclassOfClass:[NSArray class]]) // 以数组形式嵌套
        {
            // 遍历数组中对象按顺序移除
            if (![self removeAllDataFromArray:value error:error database:db rollback:rollback]) return NO;
        }
        else // 其他
        {
            if (error) {
                *error = [NSError errorWithDomain:GZStoreRemoveError code:GZStoreErrorNonsupportType userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"[%@]嵌套数据删除失败,原因:不支持(%@)属性类型嵌套", NSStringFromClass(self.class), p.name]}];
            }
            *rollback = YES;
            return NO;
        }
    }
    
    // 3. 移除非嵌套内容
    NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = %ld;", NSStringFromClass(self.class), SQL_COLUMN_NAME_PrimaryKey, [self primaryKeyValue]];
    BOOL isSuccess = [db executeUpdate:sql];
    if (isSuccess == NO) {
        if (error) {
            *error = [NSError errorWithDomain:GZStoreRemoveError code:GZStoreErrorSQLString userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"[%@]移除非嵌套部分失败(%@)", NSStringFromClass(self.class), sql]}];
        }
        *rollback = YES;
        return NO;
    }
    
    return YES;
}

// 移除数组中的数据
- (BOOL)removeAllDataFromArray:(NSArray *)array error:(NSError **)error database:(FMDatabase *)db rollback:(BOOL * _Nonnull)rollback
{
    // 1. 判断数组是否为空
    if (array == nil || [array isKindOfClass:[NSNull class]]) {
        if (error) {
            *error = [NSError errorWithDomain:GZStoreRemoveError code:GZStoreErrorArrayIsNil userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"待移除数组内容为nil"]}];
        }
        *rollback = YES;
        return NO;
    }
    
    if (![array isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:GZStoreRemoveError code:GZStoreErrorTypeUnMatchBetweenObjAndProperty userInfo:@{NSLocalizedDescriptionKey: @"所要移除的value类型错误不是数组类型"}];
        }
        *rollback = YES;
        return NO;
    }
    
    // 2. 移除数组中所有元素
    BOOL result = YES;
    for (id subValue in array) {
        // 移除数组数组中直接关联的可嵌套对象
        if (![subValue removeNestWithError:error database:db rollback:rollback]) return NO;
    }
    
    return result;
}


#pragma mark- <-----------  扩展的数据库操作  ----------->
/// 整合保存和更新到一个方法中
- (BOOL)save
{
    [self.class configPropertyAndTable];
    
    // 取得主键的值
    NSInteger pkValue = [self primaryKeyValue];
    NSError *error = nil;
    // 如果主键的值小于等于0表示新增的一条数据还未保存到数据库因此没有赋值
    if (pkValue <= 0) {
        return [self insertWithError:&error];
    }else { // 已经有值, 表示该条数据是修改数据库的值
//        return [self update];
    }
    
    return YES;
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



/**
 static void start(void) __attribute__ ((constructor)); // 构造函数、表示在main()函数执行之前执行
 static void stop(void) __attribute__ ((destructor)); // 析构函数、表示在mian()函数退出时执行
 */
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
