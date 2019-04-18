local utils = require("util")
local dump = console.dump
local strip = console.strip

local tap = require("ext/tap")
local test = tap.test

test("console.logBuffer", function()
	local data = string.rep(34, 10)
	console.printBuffer(data)
end)

test("console.printr", function()
	local data = "abcd我的"
	console.printr(data)
end)

test("console.log", function()
	local data = "abcd我的"
	console.log(data, 100, 5.3, true)
end)

test("console.trace",function()
	local data = "abcd我的"
	console.trace(data)
end)

test("console.write",function()
	local data = {}
	console.write(data, "test", nil, 100, true, false, "\n")
end)

test("console.write",function()
	local index = 0
	local timerId = nil
	timerId = setInterval(100, function()
		index = index + 1
		console.write("test", index, "\r")
		if (index >= 100) then
			clearInterval(timerId)
		end
	end)
end)

tap.run()