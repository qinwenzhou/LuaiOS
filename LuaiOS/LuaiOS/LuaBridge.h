//
//  LuaBridge.h
//  LuaiOS
//
//  Created by qwz on 2017/11/14.
//  Copyright © 2017年 qwz. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, LVType) {
    LVTypeNil,
    LVTypeNumber,
    LVTypeBoolean,
    LVTypeString,
    LVTypeArray,
    LVTypeMap,
    LVTypePtr,
    LVTypeObject,
    LVTypeInteger,
    LVTypeData,
    LVTypeFunction,
    LVTypeTuple
};

@interface LuaValue: NSObject

@property (nonatomic) LVType type;
@property (nonatomic, strong) id info;

+ (instancetype)valueWithType:(LVType)type info:(id)info;

@end


////////
typedef LuaValue* (^CFunctionHandler) (NSArray<LuaValue *> *arguments);

@interface LuaBridge: NSObject

- (void)evalScriptFromString:(NSString *)string;

- (void)evalScriptFromFile:(NSString *)filePath;


- (void)registerMethodWithName:(NSString *)methodName
                         block:(CFunctionHandler)block;

- (LuaValue *)callMethodWithName:(NSString *)methodName
                       arguments:(NSArray<LuaValue *> *)arguments;
@end
