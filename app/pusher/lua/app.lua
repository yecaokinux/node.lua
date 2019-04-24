local app   = require('app')
local rtmp  = require('rtmp')
local util  = require('util')
local url 	= require('url')
local fs 	= require('fs')
local path 	= require('path')
local core 	= require('core')
local rtsp  = require('rtsp')
local http  = require('http')
local json  = require('json')
local wot   = require('wot')
local request = require('http/request')
local client  = require('rtmp/client')
local Promise = require('wot/promise')

local session  = require('./session')

local exports = {}

-- ////////////////////////////////////////////////////////////////////////////
-- Notify

local cpuInfo = {}

local function getWotClient()
    return app.wotClient
end

-- Get the MAC address of localhost 
local function getMacAddress()
    local faces = os.networkInterfaces()
    if (faces == nil) then
    	return
    end

	local list = {}
    for k, v in pairs(faces) do
        if (k == 'lo') then
            goto continue
        end

        for _, item in ipairs(v) do
            if (item.family == 'inet') then
                list[#list + 1] = item
            end
        end

        ::continue::
    end

    if (#list <= 0) then
    	return
    end

    local item = list[1]
    if (not item.mac) then
    	return
    end

    return util.bin2hex(item.mac)
end

local function getCpuUsage()
    local data = fs.readFileSync('/proc/stat')
    if (not data) then
        return 0
    end

    local list = string.split(data, '\n')
    local d = string.gmatch(list[1], "%d+")

    local totalCpuTime = 0;
    local x = {}
    local i = 1
    for w in d do
        totalCpuTime = totalCpuTime + w
        x[i] = w
        i = i +1
    end

    local totalCpuUsedTime = x[1] + x[2] + x[3] + x[6] + x[7] + x[8] + x[9] + x[10]

    local cpuUsedTime = totalCpuUsedTime - cpuInfo.used_time
    local cpuTotalTime = totalCpuTime - cpuInfo.total_time

    cpuInfo.used_time = math.floor(totalCpuUsedTime) --record
    cpuInfo.total_time = math.floor(totalCpuTime) --record

    if (cpuTotalTime == 0) then
        return 0
    end

    local cpuUserPercent = math.floor(cpuUsedTime / cpuTotalTime * 100)
    return cpuUserPercent
end

local function sendGatewayEventNotify(name, data)
    local event = {}
    event[name] = data

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendEvent(event, app.gateway)
    end
end

local function sendGatewayDeviceInformation()
    local device = {}
    device.manufacturer = 'TDK'
    device.modelNumber = 'DT02'
    device.serialNumber = getMacAddress()
    device.firmwareVersion = '1.0'
    device.hardwareVersion = '1.0'

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendProperty({ device = device }, app.gateway)
    end
end

local function sendGatewayStatus()
    local result = {}
    result.memoryFree = math.floor(os.freemem() / 1024)
    result.memoryTotal = math.floor(os.totalmem() / 1024)
    result.cpuUsage = getCpuUsage()

    local wotClient = getWotClient();
    if (wotClient) then
        wotClient:sendStream(result, app.gateway)
    end
end

-- ////////////////////////////////////////////////////////////////////////////
-- Web Server

function getThingStatus()
    local wotClient = wot.client
    local things = wotClient and wotClient.things
    local list = {}
    if (things) then
        for did, thing in pairs(things) do 
            local data = {}
            data.id = thing.id
            data.name = thing.name
            data.deviceId = thing.deviceId
            list[did] = data
        end
    end

    return list
end

function createHttpServer()
    local server = http.createServer(function(req, res)
        -- console.log(req.url, req.method)

        local result = {}
        result.rtmp = getRtmpStatus()
        result.rtsp = getRtspStatus()
        result.things = getThingStatus()

        local body = json.stringify(result)
        res:setHeader("Content-Type", "application/json")
        res:setHeader("Content-Length", #body)
        res:finish(body)
    end)

    server:listen(8000, function()

    end)
end

-- ////////////////////////////////////////////////////////////////////////////
--

function exports.notify()
    cpuInfo.used_time = 0;
    cpuInfo.total_time = 0;

    setInterval(1000 * 15, function()
        sendGatewayStatus()
    end)

    setInterval(1000 * 3600, function()
        sendGatewayDeviceInformation()
    end)
end

function exports.play(rtmpUrl)
    local rtmpSession = getRtmpSession()
    rtmpSession.rtmpIsPlay = true

    local urlString = rtmpUrl or 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = createRtmpClient('test', urlString)

    rtmpClient:on('startStreaming', function()
        rtmpClient.isStartStreaming = true
        console.log('startStreaming')
    end)
end

function exports.test()
    local urlString = 'rtmp://iot.beaconice.cn:1935/live/test'
    local rtmpClient = createRtmpClient('test', urlString)
end

function exports.start()
    exports.rtmp()
    exports.rtsp()
    exports.register()
end

function exports.rtmp()
    startRtmpClient();
end

function exports.rtsp()
    local config = exports.config()
    local cameras = config.cameras or {}

    for did, camera in pairs(cameras) do
        startRtspClient(did, camera);
    end

    createHttpServer();
end

function exports.config()
    if (app.config) then
        return app.config
    end

    local filename = path.join(util.dirname(), '../config/config.json')
    local filedata = fs.readFileSync(filename)
    local config = json.parse(filedata)

    app.config = config or {}

    if (not config.did) then
        config.did = getMacAddress();
    end

    -- console.log(config)
    return app.config
end

function createCameraThing(did, options)
    local config = exports.config()

    local camera = { id = did, name = 'camera' }
    local webThing = wot.produce(camera)

    local mqttUrl = config.mqtt
    webThing.secret = options and options.secret

    -- play action
    local play = { input = { type = 'object' } }
    webThing:addAction('play', play, function(input)
        console.log('play', 'input', input)

        local url = input and input.url
        local now = process.now()
        local did = webThing.id;
        local rtmpSession = getRtmpSession(did)

        local promise = Promise.new()
        if (not url) then
            setTimeout(0, function()
                promise:resolve({ code = 400, error = "Invalid RTMP URL" })
            end)
            return promise
        end

        rtmpSession.rtmpUrl = url;
        rtmpSession.lastNotifyTime = now;

        onRtmpSessionTimer(did);

        -- promise
        
        setTimeout(0, function()
            promise:resolve({ code = 0 })
        end)

        return promise
    end)

    -- stop action
    local stop = { input = { type = 'object' } }
    webThing:addAction('stop', stop, function(input)
        console.log('stop', input);

        local did = webThing.id;
        stopRtmpClient(did, 'stoped');

        -- promise
        local promise = Promise.new()
        setTimeout(0, function()
            promise:resolve({ code = 0 })
        end)

        return promise
    end)

    -- ptz action
    local ptz = { input = { type = 'object'} }
    webThing:addAction('ptz', ptz, function(input)
        local did = webThing.id;
        console.log('ptz', did, input);

        if (input and input.start) then
            local direction = tonumber(input.start.direction)
            local speed = input.start.speed or 1

            if direction and (direction >= 0) and (direction <= 9) then
                return { code = 0 }
            else 
                return { code = 400, error = 'Invalid direction' }
            end

        elseif (input and input.stop) then
            return { code = 0 }
            
        else
            return { code = 400, error = 'Unsupported methods' }
        end

        return { code = 0 }
    end)

    -- preset action
    local preset = { input = { type = 'object'} }
    webThing:addAction('preset', preset, function(input)
        console.log('preset', input);
        local did = webThing.id;

        local getIndex = function(input, name)
            local index = math.floor(tonumber(input[name].index))
            if index and (index > 0 and index <= 128) then
                return index
            end
        end

        if (input and input.set) then
            local index = getIndex(input, 'set')
            if index then
                return { code = 0 }
            else
                return { code = 400, error = "Invalid preset index" }
            end

        elseif (input and input['goto']) then
            local index = getIndex(input, 'goto')
            if index then
                return { code = 0 }
            else
                return { code = 400, error = "Invalid preset index" }
            end

        elseif (input and input.remove) then
            local index = getIndex(input, 'remove')
            if index then
                return { code = 0 }
            else
                return { code = 400, error = "Invalid preset index" }
            end

        elseif (input and input.list) then
            return { code = 0, presets = { { index = 1 }, { index = 2 } } }

        else
            return { code = 400, error = 'Unsupported methods' }
        end

        return { code = 0 }
    end)

    -- device:reboot action
    local action = { input = { type = 'object'} }
    webThing:addAction('device', action, function(input)
        console.log('device', input);
        local did = webThing.id;

        if (input and input.reboot) then
            return { code = 0 }

        elseif (input and input.reset) then
            return { code = 0 }

        else
            return { code = 400, error = 'Unsupported methods' }
        end

        return { code = 0 }
    end)

    -- firmware:update action
    local action = { input = { type = 'object'} }
    webThing:addAction('firmware', action, function(input)
        console.log('firmware', input);
        local did = webThing.id;

        if (input and input.update) then
            return { code = 0 }
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- properties
    webThing:addProperty('device', { type = 'service' })
    webThing:addProperty('firmware', { type = 'service' })
    webThing:addProperty('location', { type = 'service' })
    webThing:addProperty('statistics', { type = 'service' })
    webThing:addProperty('connectivity', { type = 'service' })

    webThing:setPropertyReadHandler('device', function(input)
        console.log('read device', input);
        local did = webThing.id;
        return { 
            manufacturer = "TDK",
            modelNumber = "DT01",
            serialNumber = did,
            hardwareVersion = "1.0",
            memoryTotal = 1024,
            memoryFree = 1024,
            cpuUsage = 0,
            firmwareVersion = "1.0" 
        }
    end)

    webThing:setPropertyReadHandler('firmware', function(input)
        local did = webThing.id;
        local firmware = webThing.properties['firmware'];
        if (firmware and firmware.value) then
            return firmware.value
        end

        return {
            uri = "",
            state = "",
            result = 0,
            name = "",
            version = "1.0" 
        }
    end)

    webThing:setPropertyWriteHandler('firmware', function(input)
        console.log('write firmware', input);
        local did = webThing.id;
        local firmware = webThing.properties['firmware'];
        if (firmware) then
            if (not firmware.value) then
                firmware.value = {}
            end

            if (input.uri) then
                firmware.value.uri = uri
            end

            if (input.name) then
                firmware.value.name = name
            end

            if (input.version) then
                firmware.value.version = version
            end
        end

        return 0
    end)   

    webThing:setPropertyReadHandler('connectivity', function(input)
        local did = webThing.id;
        return { 
            signalStrength = -92,
            linkQuality = 2,
            ip = "192.168.0.100",
            router = "192.168.0.1",
            utilization = 0,
            apn = "internet",
        }
    end)

    webThing:setPropertyReadHandler('location', function(input)
        local did = webThing.id;
        return { 
            latitude = 0,
            longitude = 0,
            atitude = 0,
            radius = 0,
            timestamp = 0,
            speed = 0
        }
    end)

    webThing:setPropertyReadHandler('statistics', function(input)
        local did = webThing.id;
        return { 
            txPackets = 0,
            rxPackets = 0,
            txBytes = 0,
            rxBytes = 0,
            maxMessageSize = 0,
            avgMessageSize = 0,
            period = 0
        }
    end)    

    -- play event
    local event = { type = 'object' }
    webThing:addEvent('play', event)

    -- register
    -- console.log('webThing', webThing)
    wot.register(mqttUrl, webThing)

    return webThing
end

function createMediaGatewayThing()
    local config = exports.config()
    local gateway = { id = config.did, name = 'gateway' }
    -- console.log('config', config);

    local mqttUrl = config.mqtt
    local webThing = wot.produce(gateway)
    webThing.secret = config.secret

        -- device:reboot action
    local action = { input = { type = 'object'} }
    webThing:addAction('device', action, function(input)
        console.log('device', input);
        local did = webThing.id;

        if (input and input.reboot) then
            return { code = 0 }

        elseif (input and input.reset) then
            return { code = 0 }

        else
            return { code = 400, error = 'Unsupported methods' }
        end

        return { code = 0 }
    end)

    -- firmware:update action
    local action = { input = { type = 'object'} }
    webThing:addAction('firmware', action, function(input)
        console.log('firmware', input);
        local did = webThing.id;

        if (input and input.update) then
            return { code = 0 }
        else
            return { code = 400, error = 'Unsupported methods' }
        end
    end)

    -- properties
    webThing:addProperty('device', { type = 'service' })
    webThing:addProperty('firmware', { type = 'service' })
    webThing:addProperty('location', { type = 'service' })

    webThing:setPropertyReadHandler('device', function(input)
        console.log('read device', input);
        local did = webThing.id;

        return { firmwareVersion = "1.0" }
    end)

    webThing:setPropertyWriteHandler('device', function(input)
        console.log('write device', input);
        local did = webThing.id;

        return 0
    end)   

    webThing:setPropertyReadHandler('firmware', function(input)
        console.log('read device', input);
        local did = webThing.id;

        return { firmwareVersion = "1.0" }
    end)

    webThing:setPropertyReadHandler('location', function(input)
        console.log('read device', input);
        local did = webThing.id;

        return { firmwareVersion = "1.0" }
    end)

    -- register
    local wotClient = wot.register(mqttUrl, webThing)
    wotClient:on('register', function(response)
        local result = response and response.result
        if (result and result.code and result.error) then
            console.log('register', 'error', response.did, result)

        elseif (result.token) then
            console.log('register', response.did, result.token)
        end
    end)

    return webThing
end

-- 注册 WoT 客户端
function exports.register()
    local config = exports.config()
    local cameras = config.cameras or {}

    app.gateway = createMediaGatewayThing()

    local things = {}
    for did, camera in pairs(cameras) do
        local thing = createCameraThing(did, camera)
        things[did] = thing
    end
    app.cameras = things

    -- report stream
    exports.notify()
end

app(exports)
