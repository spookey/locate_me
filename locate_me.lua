#!/usr/bin/env lua

local device = "/dev/ttyACM0"
local verbose = false
local use_alt = false

local util = require('luci.util')
local uci = require('luci.model.uci').cursor()


function parse_args()
    function usage()
        print("\nusage: " .. arg[0] .. " [-ahv] [device]")
        print("-a", "use altitude")
        print("-v", "verbose output")
        print("-h", "print help")
        print("device is: '" .. device .. "'")
    end

    local i = 1
    while arg[i] do
        if arg[i] == '-v' then
            verbose = true
        elseif arg[i] == '-a' then
            use_alt = true
        elseif arg[i] == '-h' then
            usage()
            os.exit(0)
        elseif string.sub(arg[i], 0, 1) == '/' then
            device = arg[i]
        else
            io.stderr:write("error parsing command line")
            usage()
            os.exit(1)
        end
        i = i + 1
    end
end


function get_location(device)

    function conv(raw, bias, ltd)
        -- converting NMEA latitude & longitude to decimal
        local sp = ltd and 2 or 3
        -- are we converting a latitude or longitude here?
        -- so chomp of the first two or three digits for the degrees
        local bs = (bias ~= "N" or bias ~= "E") and 1 or -1
        -- prefix location with a minus if location is in the south or west

        local deg = tonumber(string.sub(raw, 1, sp))
        local min = tonumber(string.sub(raw, sp+1, -1))

        return bs * (deg + min/60)
    end

    local location = {}
    local collecting = true

    local handle = io.open(device, "r")

    while collecting do
        local line = handle:read("*line")
        local data = util.split(line, ",")

        if data[1] == "$GPGGA" then
            if data[7] ~= "0" then
                location.latitude = conv(data[3], data[4], true)
                location.longitude = conv(data[5], data[6], false)
                location.altitude = tonumber(data[10])
            else
                io.stdout:write(":")
            end
        elseif data[1] == "$GPRMC" then
            if data[3] == "A" then
                location.latitude = conv(data[4], data[5], true)
                location.longitude = conv(data[6], data[7], false)
            else
                io.stdout:write(":")
            end

        else
            io.stdout:write(".")
        end

        if (location.latitude ~= nil) and (location.longitude ~= nil) and (use_alt and (location.altitude ~= nil)) then
            collecting = false
        end

    end

    handle:close()

    return location
end


function save_location(location)
    local config = "gluon-node-info"
    local section = uci:get_first(config, "location")

    local share_location = uci:get_bool(config, section, "share_location")

    if location.latitude and not uci:set(config, section, "latitude", location.latitude) then
        io.stderr:write("could not set latitude " .. location.latitude .. "\n")
        return false
    end
    if location.longitude and not uci:set(config, section, "longitude", location.longitude) then
        io.stderr:write("could not set longitude " .. location.longitude .. "\n")
        return false
    end

    if location.altitude and not uci:set(config, section, "altitude", location.altitude) then
        io.stderr:write("could not set altitude " .. location.altitude .. "\n")
        return false
    end


    if not uci:save(config) then
        io.stderr:write("could not save " .. config .. "\n")
        return false
    end
    if not uci:commit(config) then
        io.stderr:write("could not commit " .. config .. "\n")
        return false
    end

    if verbose and not share_location then
        io.stdout:write("[warn] option 'share_location' is disabled\n")
    end

    return true
end


-- do stuff here
parse_args()

if not save_location(get_location(device)) then
    if verbose then io.stdout:write("[failed]\n") end
    os.exit(1)
else
    if verbose then io.stdout:write("[success]\n") end
    os.exit(0)
end
