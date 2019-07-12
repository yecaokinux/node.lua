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

#define LUV_MODBUS "modbus"

enum {
    TCP,
    RTU
};

typedef struct l_modbus_t
{
    modbus_t *modbus;
    modbus_mapping_t *mb_mapping;
    int use_backend;
    int fd;
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

static int l_version(lua_State *L)
{
    lua_pushstring(L, LIBMODBUS_VERSION_STRING);
    return 1;
}

static int l_init(lua_State *L)
{
    const char *host = lua_tostring(L, 1);
    int port = (int)lua_tointeger(L, 2);
    char parity = (char)luaL_optinteger(L, 3, 'N'); // N: 78, O: 79, E: 69
    int data_bit = (int)luaL_optinteger(L, 4, 8);
    int stop_bit = (int)luaL_optinteger(L, 5, 1);

    printf("init: %s, %d, %d, %d, %d", host, port, parity, data_bit, stop_bit);
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

        const char* device = host;
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
    
    return 1;
}

static l_modbus_t* l_check_modbus(lua_State* L, int index) {
  l_modbus_t* self = (l_modbus_t*) luaL_checkudata(L, index, LUV_MODBUS);
  luaL_argcheck(L, (self != NULL) && (self->modbus != NULL), index, "Expected l_modbus_t");
  return self;
}

static int l_modbus_error(lua_State* L, int status) {
  lua_pushnil(L);
  lua_pushstring(L, modbus_strerror(status));
  return 2;
}

static int l_connect(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    if (modbus_connect(self->modbus) == -1)
    {
        return l_modbus_error(L, errno);
    }

    lua_pushinteger(L, 0);
    return 1;
}

static int l_listen(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    int fd = modbus_tcp_listen(self->modbus, 1);
    modbus_tcp_accept(self->modbus, &fd);

    self->fd = fd;
    lua_pushinteger(L, fd);
    return 1;
}

static int l_new_mapping(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    if (self->mb_mapping) {
        modbus_mapping_free(self->mb_mapping);
        self->mb_mapping = NULL;
    }

    unsigned int startAddress = (unsigned int)luaL_optinteger(L, 2, 0);
    unsigned int registerCount = (unsigned int)luaL_optinteger(L, 3, 100);

    modbus_mapping_t *mb_mapping = modbus_mapping_new_start_address(
        0, 0,
        0, 0,
        startAddress, registerCount,
        0, 0);
    self->mb_mapping = mb_mapping;

    lua_pushinteger(L, 0);
    return 1;
}

static int l_set_mapping(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    unsigned int registerType = (unsigned int)luaL_optinteger(L, 2, 0);
    int registerAddress = (int)luaL_optinteger(L, 3, 0);
    uint16_t registerValue = (uint16_t)luaL_optinteger(L, 4, 0);

    modbus_mapping_t *mb_mapping = self->mb_mapping;
    if (mb_mapping) {
        if (registerType == 2 && mb_mapping->tab_registers) {
            int offset = registerAddress - mb_mapping->start_registers;
            if (offset >= 0 && offset < mb_mapping->nb_registers) {
                mb_mapping->tab_registers[offset] = registerValue;
                lua_pushinteger(L, 0);
                return 1;
            }
        }
    }

    lua_pushinteger(L, -1);
    return 1;
}

static int l_receive(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    uint8_t query[MODBUS_TCP_MAX_ADU_LENGTH];
    modbus_mapping_t *mb_mapping = self->mb_mapping;
  
    int ret = modbus_receive(self->modbus, query);
    if (ret > 0) {
        ret = modbus_reply(self->modbus, query, ret, mb_mapping);
    }
    
    lua_pushinteger(L, ret);
    lua_pushlstring(L, query, MODBUS_TCP_MAX_ADU_LENGTH);
    return 1;
}

static int l_close(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    if (self->mb_mapping) {
        modbus_mapping_free(self->mb_mapping);
        self->mb_mapping = NULL;
    }

    if (self->modbus) {
        modbus_close(self->modbus);
        modbus_free(self->modbus);

        self->modbus = NULL;
    }

    lua_pushinteger(L, 0);
    return 1;
}

static int l_set_slave(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    int slave = (int)lua_tointeger(L, 2);
    modbus_set_slave(self->modbus, slave);

    lua_pushinteger(L, 0);
    return 1;
}

static int l_read(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

    int count = lua_rawlen(L, -1);
    int addresses[256];
    uint16_t buffer[MODBUS_MAX_ADU_LENGTH];

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

static int l_read_registers(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);
    int address = lua_tointeger(L, 2);
    int count = lua_tointeger(L, 3);

    if (count > MODBUS_MAX_READ_REGISTERS) 
    {
        count = MODBUS_MAX_READ_REGISTERS;
    }

    uint16_t buffer[MODBUS_MAX_ADU_LENGTH];
    if (modbus_read_registers(self->modbus, address, count, buffer) == -1)
    {
        return l_modbus_error(L, errno);
    }

    if (buffer == NULL)
    {
        return l_modbus_error(L, errno);
    }
    
    lua_pushlstring(L, (const char *)buffer, count * 2);
    return 1;
}

static int l_write_register(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);
    int address = lua_tointeger(L, 2);
    int value = lua_tointeger(L, 3);

    if (modbus_write_register(self->modbus, address, value) == -1)
    {
        return l_modbus_error(L, errno);
    }

    lua_pushinteger(L, 0);
 
    return 1;
}


static int l_uart_write(lua_State *L)
{
    size_t len;
    
    l_modbus_t *self = l_check_modbus(L, 1);
    const char *reg = lua_tolstring(L, 2, &len);
    modbus_t *modbus = self->modbus;
    if(modbus == NULL)
    {
        lua_pushinteger(L, -1);
        return 1;
    }

    const modbus_backend_t * backend = modbus->backend;
    size_t ret = backend->send(modbus, ( const uint8_t *)reg, len);
    

    lua_pushinteger(L, ret);
    return 1;

}


static int l_get_fd(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);
    modbus_t *modbus = self->modbus;
    if(modbus == NULL)
    {
        lua_pushinteger(L, -1);
        return 1;
    }
    int fd = modbus->s;
    lua_pushinteger(L, fd);
    return 1;
}


static int l_uart_read(lua_State *L)
{
    uint8_t query[MODBUS_TCP_MAX_ADU_LENGTH];
    size_t len = lua_tointeger(L, 2);;
    if(len > MODBUS_TCP_MAX_ADU_LENGTH)
        len = MODBUS_TCP_MAX_ADU_LENGTH;
    
    l_modbus_t *self = l_check_modbus(L, 1);
    modbus_t *modbus = self->modbus;
    if(modbus == NULL)
    {
        lua_pushinteger(L, -1);
        return 1;
    }
    
    const modbus_backend_t * backend = modbus->backend;
    size_t ret = backend->recv(modbus, query,len);

    lua_pushinteger(L, ret);
    if(ret > 0)
    {
        lua_pushlstring(L, query, ret);
        return 2;
    }  
    return 1;

}






static int l_write(lua_State *L)
{
    l_modbus_t *self = l_check_modbus(L, 1);

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

    int addr[256];
    int value[256];

    int i = 0;
    lua_pushnil(L);
    while (lua_next(L, -2))
    {
        lua_pushvalue(L, -2);
        addr[i] = lua_tointeger(L, -1);
        value[i] = lua_tointeger(L, -2);
        lua_pop(L, 2);
        i++;
    }

    lua_pop(L, 1);

    lua_newtable(L);
    int res = 0;
    for (i = 0; i < count; i++)
    {
        if (modbus_write_register(self->modbus, addr[i], value[i]) == -1)
        {
            res = 0;
        }
        else
        {
            res = 1;
        }

        l_pushtable(L, addr[i], &res, "boolean");
    }

    lua_pushinteger(L, 0);
    return 1;
}



static const struct luaL_Reg modbus_func[] = {
    {"close", l_close},
    {"connect", l_connect},
    {"listen", l_listen},
    {"mapping", l_new_mapping},
    {"mread", l_read_registers},
    {"mwrite", l_write_register},
    {"read", l_read},
    {"receive", l_receive},
    {"set_value", l_set_mapping},
    {"slave", l_set_slave},
    {"write", l_write},
    {"uart_write", l_uart_write},
    {"uart_read", l_uart_read},
    {"uart_fd",l_get_fd},

    
    {NULL, NULL},
};

static const struct luaL_Reg modbus_lib[] = {
    {"version", l_version},
    {"new", l_init},
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



