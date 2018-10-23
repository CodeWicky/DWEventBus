<p align="center" >
<font size="20">DWDatabase</font>
</p>

## 描述
这是一个基于FMDB的无入侵的ORM数据库方案。

借住他你可以直接使用模型操作数据库而不是去考虑sql语句该怎么写，而且你并不需要继承自特殊模型，从而可以做到代码的无入侵性。如果你遵循了协议的话那么你甚至可以指定模型落库的属性及落库后对应的字段名转换。而且所有的一切操作，都将是线程安全的。

## Description
It's an nonintrusive ORM database schema which is based on FMDB.

You can manager the database by model instead of sql via it.And you needn't inherite from specific class so that is nonintrusive.If you follow the protocol you can even manage which property to save on the field name in database of each property.And all these operation is thread-safe.

## 功能
- 根据模型创建表
- 使用模型进行数据库操作
- 自定制模型与数据库字段名映射
- 模型属性白/黑名单

## Func
- Create table with model.
- Manage database with model.
- Customsize map between model and table.
- White / Black list for property to save.

## 如何使用
首先，你应该将所需文件拖入工程中，或者你也可以用Cocoapods去集成他。

```
pod 'DWDatabase', '~> 1.0.0'
```

使用过程中，你应该保证在使用之前初始化数据库，一般我们建议你在AppDelegate中调用他。初始化数据库主要是为了读取本地已存在的数据库信息。

```
DWDatabase * db = [DWDatabase shareDB];
NSError * err;
if ([db initializeDBWithError:nil]) {
    NSLog(@"%@",db.allDBs);
} else {
    NSLog(@"%@",err);
}
```

初始化之后，你可以调用一下API去创建一个新的本地数据库。

```
BOOL success = [db configDBIfNeededWithClass:cls name:name tableName:tblName path:path error:&err];
```

本地数据库创建成功以后，你就可以开始操作数据库了，不过你要先获取操作所需的数据库句柄，所有库操作你要获取库名数据库句柄，所有表操作你要获取表名数据库句柄。

```
///库名数据库句柄
DWDatabaseConfiguration * conf = [db fetchDBConfigurationWithName:name error:&err];

///表名数据库句柄
DWDatabaseConfiguration * conf = [db fetchDBConfigurationWithName:name tableName:tblName error:&err];
```

最后，你就可以使用数据库句柄进行库操作或者表操作了。

```
///插入数据
success = [db insertTableWithModel:model keys:keys configuration:conf error:&err];
```

当然，如果你觉得这一套流程太过麻烦，我同时还提供了组合API让你可以一句调用完成数据库操作，比如：

```
BOOL success = [[DWDatabase shareDB] insertTableAutomaticallyWithModel:model name:name tableName:tblName path:path keys:keys error:&error];
```

这个API组合了所有以上的操作，可直接调用，不过作者还是建议在清楚数据库状态时尽量调用单独的API而不是组合API，这样可以避免很多判断操作。

## Usage
Firstly,drag it into your project or use cocoapods.

```
pod 'DWDatabase', '~> 1.0.0'
```

You should make sure having initialized the database before using it.You'd better do this in appDelegate.The initial operation is to load local database information.

```
DWDatabase * db = [DWDatabase shareDB];
NSError * err;
if ([db initializeDBWithError:nil]) {
    NSLog(@"%@",db.allDBs);
} else {
    NSLog(@"%@",err);
}
```

After initializing,you can create an new local database.

```
BOOL success = [db configDBIfNeededWithClass:cls name:name tableName:tblName path:path error:&err];
```

If you have successed on creating database,you can start managing the database using a configuration.You should use database-configuration for all operation on database as well as table-configuration for all operation on table.

```
///Database-configuration
DWDatabaseConfiguration * conf = [db fetchDBConfigurationWithName:name error:&err];

///Table-configuration
DWDatabaseConfiguration * conf = [db fetchDBConfigurationWithName:name tableName:tblName error:&err];
```

Finally,use the conf to manager the database.

```
///Insert model
success = [db insertTableWithModel:model keys:keys configuration:conf error:&err];
```

Of course,if you feel that is too difficult,I've all provide Combine-API to make you are able to manager database easily,such as:

```
BOOL success = [[DWDatabase shareDB] insertTableAutomaticallyWithModel:model name:name tableName:tblName path:path keys:keys error:&error];
```

This API includes all above operation,you can call it straightly.But I suggest you to call single-API as much as possible instead of combine-API.Because there is much redundant operation.

## 联系作者

你可以通过在[我的Github](https://github.com/CodeWicky/DWDatabase)上给我留言或者给我发送电子邮件 codeWicky@163.com 来给我提一些建议或者指出我的bug,我将不胜感激。

如果你喜欢这个小东西，记得给我一个star吧，么么哒~

## Contact With Me
You may issue me on [my Github](https://github.com/CodeWicky/DWDatabase) or send me a email at  codeWicky@163.com  to tell me some advices or the bug,I will be so appreciated.

If you like it please give me a star.

