local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local json  = require('json')
local wot   = require('wot')
local modbus = require('lmodbus')

local exports = {}

exports.services = {}

local context = {}

local function readFromModbus(webThing)

    local function initModbus(options)
        options = options or {}
        -- console.log('initModbus', options)
    
        if (not context.device) then
            local deviceName = options.device
            local baudrate = options.baudrate or 9600
            local dev = modbus.new(deviceName, baudrate)
            if (dev) then
                context.device = dev
    
                dev:connect()
                dev:slave(options.slave or 1)
            end
        end
    end

    local function getPropertyValue(property, buffer)
        local type = property.type or 0
        local flags = property.flags or 0
        local count = property.quantity or 1
        local value = 0

        if (type == 0) then
            local fmt = 'i2'
            if (count == 2) then -- int32
                fmt = 'i4'

            elseif (count == 4) then -- int64
                fmt = 'i8'
            end

            if (flags & 0x01) ~= 0 then
                fmt = '>' .. fmt
            else
                fmt = '<' .. fmt
            end

            value = string.unpack(fmt, buffer)

        elseif (type == 1) then
            local fmt = 'I2'
            if (count == 2) then -- uint32
                fmt = 'I4'

            elseif (count == 4) then -- uint64
                fmt = 'I8'
            end

            if (flags & 0x01) ~= 0 then
                fmt = '>' .. fmt
            else
                fmt = '<' .. fmt
            end

            value = string.unpack(fmt, buffer)

        elseif (type == 2) then
            local fmt = 'I2'
            if (count == 2) then -- float
                fmt = 'f'

            elseif (count == 4) then -- double
                fmt = 'd'
            end

            if (flags & 0x01) ~= 0 then
                fmt = '>' .. fmt
            else
                fmt = '<' .. fmt
            end

            value = string.unpack(fmt, buffer)

        elseif (type == 3) then -- string
            return buffer

        elseif (type == 4) then -- boolean
            return string.unpack('<I2', buffer)

        elseif (type == 5) then -- raw
            return buffer

        else
            return 0
        end

        if (property.scale and property.scale ~= 1) then
            value = value * property.scale
        end

        if (property.offset and property.offset ~= 0) then
            value = value + property.offset
        end

        return value
    end

    local dev = context.device
    if (not dev) then
        initModbus(webThing.modbus)

        if (not dev) then
            return
        end
    end

    local result = {}
    local count = 0

    local properties = webThing.modbus.properties;
    for name, property in pairs(properties) do
        local register = property.register
        local quantity = property.quantity

        if (register >= 0) and (quantity >= 1) then
            local data = dev:mread(register, quantity)
            console.log('data', data, type(data))
            if (data) and (type(data) == 'string') and (#data == quantity * 2) then
                -- console.log('mread', register, quantity);
                -- console.printBuffer(result)
                local value = getPropertyValue(property, data)
                if (value ~= null) then
                    property.value = value

                    -- console.log(name, 'value', value);
                    result[name] = value
                    count = count + 1
                end
            end
        end
    end

    return result, count
end

local function onDeviceRead()
    local device = {}
    device.deviceType = 'modbus'
    device.errorCode = 0
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'
    device.manufacturer = 'MODBUS'
    device.modelNumber = 'MODBUS'

    return device
end

local function onDeviceReboot()

end

local function onDeviceActions(input)
    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.reboot) then
        onDeviceReboot(input.reboot);
        return { code = 0 }

    elseif (input.reset) then
        return { code = 0 }

    elseif (input.read) then
        return onDeviceRead()

    elseif (input.write) then   
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function onConfigRead(input, webThing)
    local peripherals = exports.app.get('peripherals') or {}
    local config = peripherals[webThing.id] or {}

    return config
end

local function onConfigWrite(config)
    local config = {}

    return config
end

local function onConfigActions(input, webThing)
    if (not input) then
        return { code = 400, error = 'Unsupported methods' }

    elseif (input.read) then
        return onConfigRead(input.read, webThing)

    elseif (input.write) then
        onConfigWrite(input.write);
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function initModbusProperties(options, webThing)
    -- console.log(options.properties);
    -- console.log(options.modbus);

    local common = options.modbus or {}

    webThing.modbus = {}
    webThing.modbus.device = common.n
    webThing.modbus.slave = common.d or 2
    webThing.modbus.baudrate = common.b or 9600
    webThing.modbus.interval = common.i or 60
    webThing.modbus.properties = {}
    local properties = webThing.modbus.properties;

    for name, value in pairs(options.properties) do
        local property = {}
        properties[name] = property
        property.address = value.d or common.d or 0
        property.interval = value.i or common.i or 60
        property.timeout = value.t or common.t or 500
        property.register = value.a or 0
        property.quantity = value.quantity or 1
        property.scale = value.s or 1
        property.offset = value.o or 0
        property.code = value.c or 0x03
        property.type = value.y or 0
        property.flags = value.f or 0
        property.fixed = value.x or 0
        property.value = 0

        local property = {}
        property.value = 0
    end

    -- console.log(webThing.properties);
    local interval = webThing.modbus.interval * 1000
    setInterval(interval, function()
        local result, count = readFromModbus(webThing)
        console.log(result)

        if (result) and (count > 0) then
            local wotClient = wot.client
            wotClient:sendStream(result, webThing)
        end

    end)
end

local function processReadAction(input, webThing)
    local properties = webThing.modbus.properties;
    local result = {}

    for name, property in pairs(options.properties) do
        result[name] = property.value or 0
    end

    console.log(properties, result);

    return result
end

-- Create a Modbus thing
-- @param {object} options
-- - options.mqtt
-- - options.did
-- - options.name
-- - options.secret
local function createModbusThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'
    end

    local gateway = { 
        id = options.did, 
        url = options.mqtt,
        name = options.name or 'modbus',
        actions = {},
        properties = {},
        events = {}
    }

    local webThing = wot.produce(gateway)
    webThing.secret = options.secret

    initModbusProperties(options, webThing)

    -- device actions
    webThing:setActionHandler('device', function(input)
        return onDeviceActions(input, webThing)
    end)

    -- config actions
    webThing:setActionHandler('config', function(input)
        return onConfigActions(input, webThing)
    end)

    -- register
    webThing:expose()

    webThing:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.log('register', 'error', response.did, result)

        elseif (result.token) then
            console.log('register', response.did, result.token)
        end
    end)

    return webThing
end

exports.readProperties = function (webThing)


end

exports.createThing = createModbusThing

return exports