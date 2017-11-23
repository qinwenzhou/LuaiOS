//
//  LuaBridge.m
//  LuaiOS
//
//  Created by qwz on 2017/11/14.
//  Copyright © 2017年 qwz. All rights reserved.
//

#import "LuaBridge.h"
#import "lua.h"
#import "lualib.h"
#import "lauxlib.h"


@implementation LuaValue

+ (instancetype)valueWithType:(LVType)type info:(id)info {
    LuaValue *value = [[self alloc] init];
    value.type = type;
    value.info = info;
    return value;
}

@end


// MARK: - LuaBridge

@interface LuaBridge()

@property(nonatomic, strong) NSMutableDictionary *methodBlocks;

@end


@implementation LuaBridge {
    lua_State *L;
}

- (id)init {
    if (self = [super init]) {
        L = luaL_newstate();
        luaL_openlibs(L);
        lua_settop(L, 0); // Clean up the stack
        
        self.methodBlocks = [NSMutableDictionary dictionary];
    }
    return self;
}


// MARK: - Public

- (void)evalScriptFromString:(NSString *)string {
    if (!string || string.length == 0) {
        NSLog(@"Lua string is empty!");
        return;
    }
    
    if (luaL_loadstring(L, string.UTF8String) != 0) {
        luaL_error(L, "compile error: %s", lua_tostring(L, -1));
        
    } else {
        if (lua_pcall(L, 0, 0, 0) != 0) {
            luaL_error(L, "run error: %s", lua_tostring(L, -1));
        }
    }

    lua_gc(L, 2, 0); // Collection the memory.
}

- (void)evalScriptFromFile:(NSString *)filePath {
    if (!filePath || filePath.length == 0) {
        NSLog(@"Lua file is empty!");
        return;
    }
    
    if (![filePath hasPrefix:@"/"]) {
        filePath = [[NSBundle mainBundle] pathForResource:filePath ofType:nil];
    }
    
    if (luaL_loadfile(L, filePath.UTF8String) != 0) {
        luaL_error(L, "compile error: %s", lua_tostring(L, -1));
        
    } else {
        if (lua_pcall(L, 0, 0, 0) != 0) {
            luaL_error(L, "run error: %s", lua_tostring(L, -1));
        }
    }

    lua_gc(L, 2, 0); // Collection the memory.
}

- (LuaValue *)callMethodWithName:(NSString *)methodName
                       arguments:(NSArray<LuaValue *> *)arguments {
    LuaValue *result = nil;
    
    lua_getglobal(L, methodName.UTF8String);
    if (lua_isfunction(L, -1)) {
        __weak LuaBridge *weakSelf = self;
        [arguments enumerateObjectsUsingBlock:^(LuaValue *value, NSUInteger idx, BOOL *stop) {
            [weakSelf pushStackWithValue:value];
        }];
        
        if (lua_pcall(L, (int)arguments.count, LUA_MULTRET, 0) == 0) { // Success
            result = [self valueForArgumentsAtIndex:-1];
            
        } else { // Failure
            LuaValue *value = [self valueForArgumentsAtIndex:-1];
            NSLog(@"Unabled call %@. %@", methodName, value.info);
        }
        
        lua_pop(L, 1); // Pop result
        
    } else {
        lua_pop(L, 1); // Remove from top stack
    }
    
    lua_gc(L, 2, 0); // Collection the memory
    
    return result;
}

- (void)registerMethodWithName:(NSString *)methodName
                         block:(CFunctionHandler)block {
    if (![self.methodBlocks objectForKey:methodName]) {
        [self.methodBlocks setObject:block forKey:methodName];
        
        const char *cfuncName = methodName.UTF8String;
        lua_pushlightuserdata(L, (__bridge void *)self);
        lua_pushstring(L, cfuncName);
        lua_pushcclosure(L, cfuncHandler, 2);
        lua_setglobal(L, cfuncName);
        
    } else {
        NSLog(@"Unabled register %@. The method of the specified name already exists!",
              methodName);
    }
}


// MARK: - Private

static int cfuncHandler(lua_State *L) {
    int count = 0;
    
    LuaBridge *bridge = (__bridge LuaBridge *)lua_topointer(L, lua_upvalueindex(1));
    const char *cfuncName = lua_tostring(L, lua_upvalueindex(2));
    NSString *methodName = [NSString stringWithUTF8String: cfuncName];
    
    // Call the block handler.
    CFunctionHandler handler = bridge.methodBlocks[methodName];
    if (handler) {
        NSArray *arguments = [bridge parseArguments];
        LuaValue *result = handler(arguments);
        if (result) {
            count = [bridge setReturnValue: result];
        }
    }
    
    return count;
}

// Get cfunc arguments

- (NSArray *)parseArguments {
    int top = lua_gettop(L);
    if (top >= 1) {
        NSMutableArray *arguments = [NSMutableArray array];
        for (int i = 1; i <= top; i++) {
            LuaValue *value = [self valueForArgumentsAtIndex:i];
            [arguments addObject:value];
        }
        return arguments;
    }
    return nil;
}

- (int)setReturnValue: (LuaValue *)value {
    int count = 0;
    
    if (value) {
        count = 1;
        [self pushStackWithValue:value];
    } else {
        lua_pushnil(L);
    }
    
    return count;
}

- (LuaValue *)valueForArgumentsAtIndex:(int)index {
    LuaValue *value = nil;
    
    index = lua_absindex(L, index);
    int type = lua_type(L, index);
    
    switch (type) {
        case LUA_TNIL: {
            value = [LuaValue valueWithType:LVTypeNil info:nil];
        } break;
            
        case LUA_TBOOLEAN: {
            value = [LuaValue valueWithType:LVTypeBoolean info: @(lua_toboolean(L, index))];
        } break;
            
        case LUA_TNUMBER: {
            value = [LuaValue valueWithType:LVTypeNumber info:@(lua_tonumber(L, index))];
        } break;
            
        case LUA_TSTRING: {
            size_t len = 0;
            const char *bytes = lua_tolstring(L, index, &len);
            NSString *str = [NSString stringWithCString:bytes encoding:NSUTF8StringEncoding];
            if (str) {
                value = [LuaValue valueWithType:LVTypeString info:str]; // NSString
            } else {
                NSData *data = [NSData dataWithBytes:bytes length:len];
                value = [LuaValue valueWithType:LVTypeData info:data]; // NSData
            }
        } break;
    }
    
    return value;
}

- (void)pushStackWithValue:(LuaValue *)value {
    switch (value.type) {
        case LVTypeInteger: {
            lua_pushinteger(L, [value.info integerValue]);
        } break;
            
        case LVTypeNumber: {
            lua_pushnumber(L, [value.info doubleValue]);
        } break;
            
        case LVTypeNil: {
            lua_pushnil(L);
        } break;
            
        case LVTypeString: {
            lua_pushstring(L, [value.info UTF8String]);
        } break;
            
        case LVTypeBoolean: {
            lua_pushboolean(L, [value.info boolValue]);
        } break;
            
        case LVTypeData: {
            NSData *data = value.info;
            lua_pushlstring(L, data.bytes, data.length);
        } break;
            
        default: {
            lua_pushnil(L);
        } break;
    }
}

@end
