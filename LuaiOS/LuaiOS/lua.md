#  Lua

1、
为了兼容iOS11，修改了loslib.c文件中第141行的static int os_execute (lua_State *L)函数；
修改方法可以参考以下网站：
（1）http://blog.csdn.net/holdsky/article/details/78109886
（2）https://github.com/alibaba/LuaViewSDK/issues/84
本工程采用的是（1）和（2）结合的办法。


