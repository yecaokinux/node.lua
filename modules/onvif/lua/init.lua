local request = require('http/request')
local xml = require("onvif/xml")
local util = require("util")

local exports = {}

function exports.xml2table(element)
    if (not element) then
        return
    end

    local name = element:name()
    local properties = element:properties();
    local children = element:children();

    local pos = string.find(name, ':')
    if (pos and pos > 0) then
        name = string.sub(name, pos + 1)
    end

    if (children and #children > 0) then
        -- children
        local item = {}

        if (#children >= 2) and (children[1]:name() == children[2]:name()) then
            for index, value in ipairs(children) do
                local key, ret = exports.xml2table(value)
                item[key .. '.' .. index] = ret
            end

        else
            for _, value in ipairs(children) do
                local key, ret = exports.xml2table(value)
                item[key] = ret
            end
        end

        return name, item

    else
        -- properties
        if (properties and #properties > 0) then
            -- console.log(name, properties)
            local item = {}
            for _, property in ipairs(properties) do
                local value = element['@' .. property.name]
                -- console.log(name, property, value)

                item['@' .. property.name] = value
            end

            item.value = element:value()

            -- console.log(name, item)
            return name, item

        else
            return name, element:value()
        end
    end
end

function exports.post(options, callback)
    local url = 'http://' .. options.host
    if (options.port) then
        url = url .. ':' .. options.port
    end

    url = url .. (options.path or '/')

    request.post(url, options, function(err, response, body)
        -- console.log(err, response.statusCode, body)
        if (err or not body) then
            callback(err or 'error')
            return
        end

        local parser = xml.newParser()
        local data = parser:ParseXmlText(body)
        local root = data and data['env:Envelope']
        -- console.log(root:name())

        local xmlBody = root and root['env:Body']
        -- console.log(xmlBody:name())

        local _, result = exports.xml2table(xmlBody)
        callback(nil, result)
    end)
end

function exports.getUsernameToken(options)
    local timestamp = '2019-08-03T03:21:33.001Z'
    local nonce = util.base64Decode('SNMfYjdAJzZzDk0SY8Xdhw==')
    local data = nonce .. timestamp .. options.password
    local digest = util.sha1(data)
    digest = util.base64Encode(digest);

    return {
        timestamp = timestamp,
        nonce = util.base64Encode(nonce),
        digest = digest
    }
end

function exports.getHeader(options)
    if (not options.username) or (not options.password) then
        return ''
    end

    local result = exports.getUsernameToken(options)

    local header = [[    
    <s:Header>
        <Security s:mustUnderstand="1" xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
            <UsernameToken>
                <Username>]] .. options.username .. [[</Username>
                <Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">]] .. result.digest .. [[</Password>
                <Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">]] .. result.nonce .. [[</Nonce>
                <Created xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">]] .. result.timestamp .. [[</Created>
            </UsernameToken>
        </Security>
    </s:Header>
    ]]

    return header;
end

function exports.getMessage(options, body)
    local message = '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing">' ..
    exports.getHeader(options) .. [[
    <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">]] ..
    body .. '</s:Body></s:Envelope>'
    return message
end

function exports.getSystemDateAndTime(options, callback)
    local message = [[
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
    <s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>
    </s:Body>
</s:Envelope>
]]
    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

function exports.getCapabilities(options, callback)
    local message = exports.getMessage(options, [[
        <GetCapabilities xmlns="http://www.onvif.org/ver10/device/wsdl">
            <Category>All</Category>
        </GetCapabilities>]])
    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

function exports.getDeviceInformation(options, callback)
    local message = exports.getMessage(options, [[
        <GetDeviceInformation xmlns="http://www.onvif.org/ver10/device/wsdl">
        </GetDeviceInformation>]])
    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

function exports.getServices(options, callback)
    local message = exports.getMessage(options, [[
        <GetServices xmlns="http://www.onvif.org/ver10/device/wsdl">
            <IncludeCapability>true</IncludeCapability>
        </GetServices>]])

    options.path = '/onvif/device_service'
    options.data = message
    exports.post(options, callback)
end

local media = {}

function media.getProfiles(options, callback)
    local message = exports.getMessage(options, [[<GetProfiles xmlns="http://www.onvif.org/ver10/media/wsdl"/>]])
    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getVideoSources(options, callback)
    local message = exports.getMessage(options, [[<GetVideoSources xmlns="http://www.onvif.org/ver10/media/wsdl"/>]])
    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getStreamUri(options, callback)
    local message = exports.getMessage(options, [[
        <GetStreamUri xmlns="http://www.onvif.org/ver10/media/wsdl">
            <StreamSetup>
                <Stream xmlns="http://www.onvif.org/ver10/schema">RTP-Unicast</Stream>
                <Transport xmlns="http://www.onvif.org/ver10/schema">
                    <Protocol>RTSP</Protocol>
                </Transport>
            </StreamSetup>
            <ProfileToken>]] .. options.profile .. [[</ProfileToken>
        </GetStreamUri>]])

    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getStreamUri(options, callback)
    local message = exports.getMessage(options, [[
        <GetSnapshotUri xmlns="http://www.onvif.org/ver10/media/wsdl">
            <ProfileToken>]] .. options.profile .. [[</ProfileToken>
        </GetSnapshotUri>]])

    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

function media.getOSDs(options, callback)
    local message = exports.getMessage(options, [[
        <GetOSDs xmlns="http://www.onvif.org/ver10/media/wsdl">
        </GetOSDs>]])
    options.path = '/onvif/Media'
    options.data = message
    exports.post(options, callback)
end

exports.media = media

local ptz = {}

function ptz.GetPresets(options, callback)
    local message = exports.getMessage(options, [[
        <GetPresets xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. options.profile .. [[</ProfileToken>
        </GetPresets>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

function ptz.GetPresets(options, callback)
    local message = exports.getMessage(options, [[
        <ContinuousMove xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>]] .. options.profile .. [[</ProfileToken>
            <Velocity>
                <PanTilt x="0" y="1" xmlns="http://www.onvif.org/ver10/schema"/>
                <Zoom x="0" xmlns="http://www.onvif.org/ver10/schema"/>
            </Velocity>
        </ContinuousMove>]])
    options.path = '/onvif/ptz'
    options.data = message
    exports.post(options, callback)
end

exports.ptz = ptz

return exports
