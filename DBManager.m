//
//  DBManager.m
//  DBModel
//
//  Created by 谷胜亚 on 2017/11/27.
//  Copyright © 2017年 谷胜亚. All rights reserved.
//

#import "DBManager.h"

@interface DBManager()

/// 数据库队列
@property (nonatomic, strong) FMDatabaseQueue *databaseQueue;

/// 数据库文件完整路径
@property (nonatomic, copy) NSString *dbFilePath;

@end

@implementation DBManager

/// 单例初始化方法
+ (instancetype)manager
{
    static DBManager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[DBManager alloc] init];
    });
    
    return _instance;
}

/// 懒加载并初始化数据库队列
- (FMDatabaseQueue *)databaseQueue
{
    if (!_databaseQueue) {
        _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:self.dbFilePath];
    }
    
    return _databaseQueue;
}

/// 数据库文件的完整路径
- (NSString *)dbFilePath
{
    // Document目录的路径
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    // 获得文件管理者单例
    NSFileManager *filemanage = [NSFileManager defaultManager];
    // 判断是否设置数据库文件父目录
    if (self.dbFileDirectoryName == nil || self.dbFileDirectoryName.length == 0) {
        docsdir = [docsdir stringByAppendingPathComponent:@"Database"]; // 未设置使用默认的JKDB作为数据库文件父目录名称
    } else {
        docsdir = [docsdir stringByAppendingPathComponent:self.dbFileDirectoryName];
    }
    BOOL isDir;
    // isDir用来判断该路径是否是文件夹, exit用来判断指定路径文件或目录是否存在
    BOOL exit =[filemanage fileExistsAtPath:docsdir isDirectory:&isDir];
    // 如果指定路径文件或目录不存在  或者 不是目录
    if (!exit || !isDir) {
        
        // 根据指定路径创建目录
        [filemanage createDirectoryAtPath:docsdir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // 拼接数据库的文件名到该目录上形成数据库文件的完整路径
    NSString *dbpath = [docsdir stringByAppendingPathComponent:@"duia.sqlite"];
    NSLog(@"数据库文件路径:[%@]", dbpath);
    return dbpath;
}

@end
