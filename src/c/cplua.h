/*
*/
#ifdef _WIN32
#define chdir(p) (_chdir(p))
#define getcwd(d, s) (_getcwd(d, s))
#define rmdir(p) (_rmdir(p))
#define CPLUA_EXPORT __declspec (dllexport)
#ifndef fileno
#define fileno(f) (_fileno(f))
#endif
#else
#define CPLUA_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

CPLUA_EXPORT int luaopen_cplua(lua_State* L);
CPLUA_EXPORT int luaopen_lite_xl_cplua(lua_State* L, void* XL);


#ifdef __cplusplus
}
#endif