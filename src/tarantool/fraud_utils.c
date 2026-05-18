#include <tarantool/module.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <stdint.h>

#define BLOOM_SIZE (1024 * 1024)
static uint8_t bloom_filter[BLOOM_SIZE];

static uint32_t hash_djb2(const char *str) {
    uint32_t hash = 5381;
    int c;
    while ((c = *str++))
        hash = ((hash << 5) + hash) + c;
    return hash;
}

static uint32_t hash_sdbm(const char *str) {
    uint32_t hash = 0;
    int c;
    while ((c = *str++))
        hash = c + (hash << 6) + (hash << 16) - hash;
    return hash;
}

static uint32_t hash_fnv1a(const char *str) {
    uint32_t hash = 2166136261u;
    int c;
    while ((c = *str++)) {
        hash ^= (uint8_t)c;
        hash *= 16777619u;
    }
    return hash;
}

static int l_bloom_add(struct lua_State *L) {
    const char *key = luaL_checkstring(L, 1);
    uint32_t h1 = hash_djb2(key) % (BLOOM_SIZE * 8);
    uint32_t h2 = hash_sdbm(key) % (BLOOM_SIZE * 8);
    uint32_t h3 = hash_fnv1a(key) % (BLOOM_SIZE * 8);

    bloom_filter[h1 / 8] |= (1 << (h1 % 8));
    bloom_filter[h2 / 8] |= (1 << (h2 % 8));
    bloom_filter[h3 / 8] |= (1 << (h3 % 8));

    return 0;
}

static int l_bloom_check(struct lua_State *L) {
    const char *key = luaL_checkstring(L, 1);
    uint32_t h1 = hash_djb2(key) % (BLOOM_SIZE * 8);
    uint32_t h2 = hash_sdbm(key) % (BLOOM_SIZE * 8);
    uint32_t h3 = hash_fnv1a(key) % (BLOOM_SIZE * 8);

    int res = (bloom_filter[h1 / 8] & (1 << (h1 % 8))) &&
              (bloom_filter[h2 / 8] & (1 << (h2 % 8))) &&
              (bloom_filter[h3 / 8] & (1 << (h3 % 8)));

    lua_pushboolean(L, res);
    return 1;
}

static int l_bloom_clear(struct lua_State *L) {
    memset(bloom_filter, 0, BLOOM_SIZE);
    return 0;
}

LUA_API int luaopen_fraud_utils(struct lua_State *L) {
    static const struct luaL_Reg lib[] = {
        {"add", l_bloom_add},
        {"check", l_bloom_check},
        {"clear", l_bloom_clear},
        {NULL, NULL}
    };
    lua_newtable(L);
    luaL_register(L, NULL, lib);
    return 1;
}
