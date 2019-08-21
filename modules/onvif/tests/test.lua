local onvif = require('onvif')
local xml = require("onvif/xml")
local json = require('json')

local options = {
    host = '192.168.1.64',
    username = 'admin', 
    password = 'admin123456'
}

options = {
    host = '192.168.1.104',
    username = 'admin',
    password = 'abcdefg123456'
}

options = {
    host = '192.168.1.10',
    username = 'admin',
    password = '123456'
}

local function testGetSystemDateAndTime()
    onvif.getSystemDateAndTime(options, function(err, body) 
        console.log(err, body)
    end)
end

local function testGetCapabilities()
    onvif.getCapabilities(options, function(err, body) 
        console.log(err, body)
    end)
end

local function testGetDeviceInformation()
    onvif.getDeviceInformation(options, function(err, body) 
        console.log(err, body)
    end)
end

local function testGetUsernameToken()
    local data = onvif.getUsernameToken(options)
    console.log(data)
end

local function testGetProfiles(callback)
    onvif.media.getProfiles(options, function(err, body)
        local response = body and body.GetProfilesResponse
        local profile1 = response and response['Profiles.1']
        local profile2 = response and response['Profiles.2']
        local name1 = profile1 and profile1.Name
        local name2 = profile1 and profile2.Name
        console.log(err, name1, name2)

        callback(name1, name2);
    end)
end

local function testGetVideoSourcess()
    onvif.media.getVideoSources(options, function(err, body)
        console.log(err, json.stringify(body))
    end)
end

local function testGetStreamUri(name)
    options.profile = name
    onvif.media.getStreamUri(options, function(err, body)
        console.log(err, body)
    end)
end

local function testGetSnapshotUri()
    onvif.media.getSnapshotUri(options, function(err, body)
        console.log(err, body)
    end)
end

local function testContinuousMove()
    options.profile = 'Profile_1'
    options.x = 1;
    -- options.y = -1;
    options.z = 0;
    onvif.ptz.continuousMove(options, function(err, body)
        console.log(err, json.stringify(body))
    end)
end

local function testXml()
    local message = [[
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
    <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>
    </s:Body>
</s:Envelope>
]]
    local parser = xml.newParser()
    local data = parser:ParseXmlText(message)
    local root = data['s:Envelope']
    console.log(root:name())

    local body = root['s:Body']
    console.log(body:name())

    local element = body.GetSystemDateAndTime
    console.log(element:name())
    console.log(element:properties())
    console.log(element['@xmlns'])

end

local function testCamera()
    local camera = onvif.camera(options)

    camera:getDeviceInformation(function(result)
        console.log(result)
    end)

    console.log(camera:getVideoUri())
    console.log(camera:getImageUri())
end


-- testCamera()
testGetSystemDateAndTime()
testGetDeviceInformation()
testGetProfiles(function(name1, name2)
    testGetStreamUri(name1)
    testGetSnapshotUri(name2)
end)

