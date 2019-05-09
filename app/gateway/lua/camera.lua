local app   = require('app')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')
local Promise = require('wot/promise')

local exports = {}

exports.services = {}

local function getWotClient()
    return wot.client
end

local function getDeviceInformation()
    local device = {}
    device.cpuUsage = getCpuUsage()
    device.currentTime = os.time()
    device.deviceType = 'gateway'
    device.errorCode = 0
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'
    device.manufacturer = 'TDK'
    device.memoryFree = math.floor(os.freemem() / 1024)
    device.memoryTotal = math.floor(os.totalmem() / 1024)
    device.modelNumber = 'DT02'
    device.powerSources = 0
    device.powerVoltage = 12000
    device.serialNumber = getMacAddress()

    return device
end

local function onRebootDevice()

end

local function getConfigInformation()
    local config = {}

    return config
end

local function setConfigInformation(config)
    local config = {}

    return config
end

local function processDeviceActions(input)
    if (input.reboot) then
        onRebootDevice(input.reboot);
        return { code = 0 }

    elseif (input.reset) then
        return { code = 0 }

    elseif (input.read) then
        return getDeviceInformation()

    elseif (input.write) then   
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function processConfigActions(input, webThing)
    if (input.read) then
        return getConfigInformation()

    elseif (input.write) then
        setConfigInformation(input.write);
        return { code = 0 }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function processPtzActions(input, webThing)
    if (input.start) then
        local direction = tonumber(input.start.direction)
        local speed = input.start.speed or 1

        if direction and (direction >= 0) and (direction <= 9) then
            return { code = 0 }
        else 
            return { code = 400, error = 'Invalid direction' }
        end

    elseif (input.stop) then
        return { code = 0 }
        
    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function processPresetActions(input, webThing)
    local did = webThing.id;

    local getIndex = function(input, name)
        local index = math.floor(tonumber(input[name].index))
        if index and (index > 0 and index <= 128) then
            return index
        end
    end

    if (input.set) then
        local index = getIndex(input, 'set')
        if index then
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input['goto']) then
        local index = getIndex(input, 'goto')
        if index then
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input.remove) then
        local index = getIndex(input, 'remove')
        if index then
            return { code = 0 }
        else
            return { code = 400, error = "Invalid preset index" }
        end

    elseif (input.list) then
        return { code = 0, presets = { { index = 1 }, { index = 2 } } }

    else
        return { code = 400, error = 'Unsupported methods' }
    end
end

local function processPlayActions(input, webThing)
    local url = input and input.url
    local did = webThing.id;

    local promise = Promise.new()
    if (not url) then
        setTimeout(0, function()
            promise:resolve({ code = 400, error = "Invalid RTMP URL" })
        end)
        return promise
    end

    if (rtmp) then
        rtmp.publishRtmpUrl(did, url);
    end

    -- promise
    
    setTimeout(0, function()
        promise:resolve({ code = 0 })
    end)

    return promise
end

local function processStopActions(input, webThing)
    console.log('stop', input);

    local did = webThing.id;
    if (rtmp) then
        rtmp.stopRtmpClient(did, 'stoped');
    end

    -- promise
    local promise = Promise.new()
    setTimeout(0, function()
        promise:resolve({ code = 0 })
    end)

    return promise
end

local function createCameraThing(options)
    if (not options) then
        return nil, 'need options'

    elseif (not options.mqtt) then
        return nil, 'need MQTT url option'

    elseif (not options.did) then
        return nil, 'need did option'

    elseif (not options.rtmp) then
        console.log('need rtmp option')
    end

    local mqttUrl = options.mqtt
    local did = options.did
    local rtmp = options.rtmp

    local camera = { id = did, name = 'camera' }
    local webThing = wot.produce(camera)

    webThing.secret = options and options.secret

    -- play action
    local play = { input = { type = 'object' } }
    webThing:addAction('play', play, function(input)
        return processPlayActions(input, webThing)
    end)

    -- stop action
    local stop = { input = { type = 'object' } }
    webThing:addAction('stop', stop, function(input)
        return processStopActions(input, webThing)
    end)

    -- ptz action
    local ptz = { input = { type = 'object'} }
    webThing:addAction('ptz', ptz, function(input)
        if (input) then
            return processPtzActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- preset action
    local preset = { input = { type = 'object'} }
    webThing:addAction('preset', preset, function(input)
        if (input) then
            return processPresetActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
  
    end)

    -- device actions
    local action = { input = { type = 'object'} }
    webThing:addAction('device', action, function(input)
        if (input) then
            return processDeviceActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- config actions
    local action = { input = { type = 'object'} }
    webThing:addAction('config', action, function(input)
        if (input) then
            return processConfigActions(input, webThing)
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- play event
    local event = { type = 'object' }
    webThing:addEvent('play', event)

    -- register
    -- console.log('webThing', webThing)
    local client, err = wot.register(mqttUrl, webThing)
    if (err) then
        console.log(err)
    end

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

exports.createThing = createCameraThing

return exports