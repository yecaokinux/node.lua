#include <stdio.h>
#include <string.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <modbus.h>
#include "modbus-private.h"

#include "luv.h"

#include "lthreadpool.h"

#define LUV_MODBUS "modbus"

enum
{
    TCP,
    RTU
};

typedef struct l_modbus_t
{
    modbus_t *modbus;
    modbus_mapping_t *mb_mapping;
    int use_backend;
    int fd;
    uv_mutex_t lock;
} l_modbus_t;

static void l_pushtable(lua_State *L, int key, void *value, char *vtype)
{
    lua_pushnumber(L, key);

    if (strcmp(vtype, "number") == 0)
    {
        double *buf = value;
        lua_pushnumber(L, *buf);
    }
    else if (strcmp(vtype, "integer") == 0)
    {
        long int *buf = value;
        lua_pushinteger(L, *buf);
    }
    else if (strcmp(vtype, "boolean") == 0)
    {
        int *buf = value;
        lua_pushboolean(L, *buf);
    }
    else if (strcmp(vtype, "string") == 0)
    {
        lua_pushstring(L, (char *)value);
    }
    else
    {
        printf("Get NULL value\n");
        lua_pushnil(L);
    }

    lua_settable(L, -3);
}

static int lmodbus_version(lua_State *L)
{
    lua_pushstring(L, LIBMODBUS_VERSION_STRING);
    return 1;
}

static int lmodbus_new(lua_State *L)
{
    const char *host = lua_tostring(L, 1);
    int port = (int)lua_tointeger(L, 2);
    char parity = (char)luaL_optinteger(L, 3, 'N'); // N: 78, O: 79, E: 69
    int data_bit = (int)luaL_optinteger(L, 4, 8);
    int stop_bit = (int)luaL_optinteger(L, 5, 1);

    lua_pop(L, 2);

    l_modbus_t *self;

    if (port < 9600)
    {
        self = (l_modbus_t *)lua_newuserdata(L, sizeof(l_modbus_t));

        luaL_getmetatable(L, LUV_MODBUS);
        lua_setmetatable(L, -2);

        self->modbus = modbus_new_tcp(host, port);
        self->mb_mapping = NULL;
        self->use_backend = TCP;
    }
    else
    {
        self = (l_modbus_t *)lua_newuserdata(L, sizeof(l_modbus_t));

        luaL_getmetatable(L, LUV_MODBUS);
        lua_setmetatable(L, -2);

        const char *device = host;
        int baud = port;

        self->modbus = modbus_new_rtu(device, port, parity, data_bit, stop_bit);
        self->mb_mapping = NULL;
        self->use_backend = RTU;
    }

    if (self->modbus == NULL)
    {
        fprintf(stderr, "Modbus init error: %s\n", modbus_strerror(errno));
        return -1;
    }

    uv_mutex_init(&self->lock);
    return 1;
}

static l_modbus_t *lmodbus_check(lua_State *L, int index)
{
    l_modbus_t *self = (l_modbus_t *)luaL_checkudata(L, index, LUV_MODBUS);
    luaL_argcheck(L, (self != NULL) && (self->modbus != NULL), index, "Expected l_modbus_t");
    return self;
}

static int lmodbus_error(lua_State *L, int status)
{
    lua_pushnil(L);
    lua_pushstring(L, modbus_strerror(status));
    return 2;
}

static int lmodbus_connect(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    if (modbus_connect(self->modbus) == -1)
    {
        return lmodbus_error(L, errno);
    }

    lua_pushinteger(L, 0);
    return 1;
}

static int lmodbus_listen(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    int fd = modbus_tcp_listen(self->modbus, 1);
    modbus_tcp_accept(self->modbus, &fd);

    self->fd = fd;
    lua_pushinteger(L, fd);
    return 1;
}

static int lmodbus_new_mapping(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    if (self->mb_mapping)
    {
        modbus_mapping_free(self->mb_mapping);
        self->mb_mapping = NULL;
    }

    unsigned int startAddress1 = (unsigned int)luaL_optinteger(L, 2, 0);
    unsigned int registerCount1 = (unsigned int)luaL_optinteger(L, 3, 10);

    unsigned int startAddress2 = (unsigned int)luaL_optinteger(L, 4, 0);
    unsigned int registerCount2 = (unsigned int)luaL_optinteger(L, 5, 10);

    unsigned int startAddress3 = (unsigned int)luaL_optinteger(L, 6, 0);
    unsigned int registerCount3 = (unsigned int)luaL_optinteger(L, 7, 0);

    unsigned int startAddress4 = (unsigned int)luaL_optinteger(L, 8, 0);
    unsigned int registerCount4 = (unsigned int)luaL_optinteger(L, 9, 0);

    modbus_mapping_t *mb_mapping = modbus_mapping_new_start_address(
        startAddress3, registerCount3, startAddress4, registerCount4,
        startAddress1, registerCount1, startAddress2, registerCount2);
    self->mb_mapping = mb_mapping;

    lua_pushinteger(L, 0);
    return 1;
}

static int lmodbus_set_mapping(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    unsigned int registerType = (unsigned int)luaL_optinteger(L, 2, 0);
    int registerAddress = (int)luaL_optinteger(L, 3, 0);
    uint16_t registerValue = (uint16_t)luaL_optinteger(L, 4, 0);

    modbus_mapping_t *mb_mapping = self->mb_mapping;
    if (mb_mapping)
    {
        if (registerType == 1 && mb_mapping->tab_registers)
        {
            int offset = registerAddress - mb_mapping->start_registers;
            if (offset >= 0 && offset < mb_mapping->nb_registers)
            {
                mb_mapping->tab_registers[offset] = registerValue;
                lua_pushinteger(L, 0);
                return 1;
            }
        }
        else if (registerType == 2 && mb_mapping->tab_input_registers)
        {
            int offset = registerAddress - mb_mapping->start_input_registers;
            if (offset >= 0 && offset < mb_mapping->nb_input_registers)
            {
                mb_mapping->tab_input_registers[offset] = registerValue;
                lua_pushinteger(L, 0);
                return 1;
            }
        }
        else if (registerType == 3 && mb_mapping->tab_bits)
        {
            int offset = registerAddress - mb_mapping->start_bits;
            if (offset >= 0 && offset < mb_mapping->nb_bits)
            {
                mb_mapping->tab_bits[offset] = registerValue;
                lua_pushinteger(L, 0);
                return 1;
            }
        }
        else if (registerType == 4 && mb_mapping->tab_input_bits)
        {
            int offset = registerAddress - mb_mapping->start_input_bits;
            if (offset >= 0 && offset < mb_mapping->nb_bits)
            {
                mb_mapping->tab_input_bits[offset] = registerValue;
                lua_pushinteger(L, 0);
                return 1;
            }
        }
    }

    lua_pushinteger(L, -1);
    return 1;
}

static int lmodbus_get_mapping(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    unsigned int registerType = (unsigned int)luaL_optinteger(L, 2, 0);
    int registerAddress = (int)luaL_optinteger(L, 3, 0);

    modbus_mapping_t *mb_mapping = self->mb_mapping;
    if (mb_mapping)
    {
        if (registerType == 1 && mb_mapping->tab_registers)
        {
            int offset = registerAddress - mb_mapping->start_registers;
            if (offset >= 0 && offset < mb_mapping->nb_registers)
            {
                uint16_t registerValue = mb_mapping->tab_registers[offset];
                lua_pushinteger(L, registerValue);
                return 1;
            }
        }
    }

    lua_pushnil(L);
    lua_pushinteger(L, -1);
    return 1;
}

static int lmodbus_receive(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    uint8_t query[MODBUS_TCP_MAX_ADU_LENGTH];
    memset(query, 0, sizeof(query));

    modbus_mapping_t *mb_mapping = self->mb_mapping;

    int ret = modbus_receive(self->modbus, query);
    if (ret > 0)
    {
        int reply = modbus_reply(self->modbus, query, ret, mb_mapping);

        lua_pushinteger(L, reply);
        lua_pushlstring(L, query, ret);
        return 2;
    }
    else
    {
        return lmodbus_error(L, errno);
    }
}

static int lmodbus_close(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    if (self->mb_mapping)
    {
        modbus_mapping_free(self->mb_mapping);
        self->mb_mapping = NULL;
    }

    if (self->modbus)
    {
        modbus_close(self->modbus);
        modbus_free(self->modbus);
        uv_mutex_destroy(&self->lock);
        self->modbus = NULL;
    }

    lua_pushinteger(L, 0);
    return 1;
}

static int lmodbus_set_slave(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    int slave = (int)lua_tointeger(L, 2);
    modbus_set_slave(self->modbus, slave);

    lua_pushinteger(L, 0);
    return 1;
}

static int l_read(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    int count = lua_rawlen(L, -1);
    int addresses[256];
    uint16_t buffer[MODBUS_MAX_ADU_LENGTH];

    // 历遍表格
    int i = 0;
    lua_pushnil(L);
    while (lua_next(L, -2))
    {
        lua_pushvalue(L, -2);
        addresses[i] = lua_tointeger(L, -2);
        lua_pop(L, 2);
        i++;
    }

    lua_pop(L, 1);

    lua_newtable(L);
    for (i = 0; i < count; i++)
    {
        if (modbus_read_registers(self->modbus, addresses[i], 1, buffer) == -1)
        {
            return 0;
        }

        if (buffer == NULL)
        {
            return 0;
        }

        long int res = (long int)*buffer;
        l_pushtable(L, addresses[i], &res, "integer");
    }

    return 1;
}

static int lmodbus_read_registers(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);
    int address = lua_tointeger(L, 2);
    int count = lua_tointeger(L, 3);

    if (count > MODBUS_MAX_READ_REGISTERS)
    {
        count = MODBUS_MAX_READ_REGISTERS;
    }

    uint16_t buffer[MODBUS_MAX_ADU_LENGTH];
    uv_mutex_lock(&self->lock);

    if (modbus_read_registers(self->modbus, address, count, buffer) == -1)
    {
        uv_mutex_unlock(&self->lock);
        return lmodbus_error(L, errno);
    }
    uv_mutex_unlock(&self->lock);

    if (buffer == NULL)
    {
        return lmodbus_error(L, errno);
    }

    lua_pushlstring(L, (const char *)buffer, count * 2);
    return 1;
}

static int lmodbus_write_register(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);
    int address = lua_tointeger(L, 2);
    int value = lua_tointeger(L, 3);

    if (modbus_write_register(self->modbus, address, value) == -1)
    {
        return lmodbus_error(L, errno);
    }

    lua_pushinteger(L, 0);

    return 1;
}

static int lmodbus_get_fd(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);
    modbus_t *modbus = self->modbus;
    if (modbus == NULL)
    {
        lua_pushinteger(L, -1);
        return 1;
    }
    int fd = modbus->s;
    lua_pushinteger(L, fd);
    return 1;
}

static int lmodbus_write_registers(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    lua_pushvalue(L, -1);
    int count = 0;
    lua_pushnil(L);
    while (lua_next(L, -2))
    {
        lua_pushvalue(L, -2);
        lua_pop(L, 2);
        count++;
    }

    lua_pop(L, 1);

    int address[256];
    int value[256];

    // 历遍表格
    int i = 0;
    lua_pushnil(L);
    while (lua_next(L, -2))
    {
        lua_pushvalue(L, -2);
        address[i] = lua_tointeger(L, -1);
        value[i] = lua_tointeger(L, -2);
        lua_pop(L, 2);
        i++;
    }

    lua_pop(L, 1);

    lua_newtable(L);
    int res = 0;
    for (i = 0; i < count; i++)
    {
        if (modbus_write_register(self->modbus, address[i], value[i]) == -1)
        {
            res = 0;
        }
        else
        {
            res = 1;
        }

        l_pushtable(L, address[i], &res, "boolean");
    }

    lua_pushinteger(L, 0);
    return 1;
}

static int lmodbus_read_bits(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);
    int address = lua_tointeger(L, 2);
    int count = lua_tointeger(L, 3);

    if (count > MODBUS_MAX_READ_REGISTERS)
    {
        count = MODBUS_MAX_READ_REGISTERS;
    }

    uint8_t buffer[MODBUS_MAX_ADU_LENGTH];
    uv_mutex_lock(&self->lock);
    if (modbus_read_bits(self->modbus, address, count, buffer) == -1)
    {
        uv_mutex_unlock(&self->lock);
        return lmodbus_error(L, errno);
    }
    uv_mutex_unlock(&self->lock);

    if (buffer == NULL)
    {
        return lmodbus_error(L, errno);
    }

    lua_pushlstring(L, (const char *)buffer, count);
    return 1;
}

static int lmodbus_write_bit(lua_State *L)
{
    l_modbus_t *self = lmodbus_check(L, 1);

    int address = lua_tointeger(L, 2);
    int value = lua_tointeger(L, 3);
    uv_mutex_lock(&self->lock);
    if (modbus_write_bit(self->modbus, address, value) == -1)
    {
        uv_mutex_unlock(&self->lock);
        return lmodbus_error(L, errno);
    }
    uv_mutex_unlock(&self->lock);
    lua_pushinteger(L, 0);
    return 1;
}

static const struct luaL_Reg modbus_func[] = {
    {"close", lmodbus_close},
    {"connect", lmodbus_connect},
    {"getFD", lmodbus_get_fd},
    {"getMapping", lmodbus_get_mapping},
    {"listen", lmodbus_listen},
    {"newMapping", lmodbus_new_mapping},
    {"read", l_read},
    {"readBits", lmodbus_read_bits},
    {"readRegisters", lmodbus_read_registers},
    {"receive", lmodbus_receive},
    {"setMapping", lmodbus_set_mapping},
    {"setSlave", lmodbus_set_slave},
    {"write", lmodbus_write_registers},
    {"writeBit", lmodbus_write_bit},
    {"writeRegister", lmodbus_write_register},

    {NULL, NULL},
};

static const struct luaL_Reg modbus_lib[] = {
    {"version", lmodbus_version},
    {"new", lmodbus_new},
    {NULL, NULL},
};

LUALIB_API int luaopen_lmodbus(lua_State *L)
{
    /*luaL_newmetatable(L, "modbus");
    lua_pushvalue(L,-1);
    lua_setfield(L, -2, "__index");
    luaL_register(L, NULL, modbus_func);
    luaL_register(L, "modbus", modbus_lib);*/

    luaL_newlib(L, modbus_lib);

    luaL_newmetatable(L, LUV_MODBUS);

    luaL_newlib(L, modbus_func);
    lua_setfield(L, -2, "__index");

    lua_pop(L, 1);

    return 1;
}
