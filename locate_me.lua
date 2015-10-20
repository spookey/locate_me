#!/usr/bin/env lua

local device = "/dev/ttyACM0"
local verbose = false
local use_alt = false
local print_only = false

local util = require("luci.util")
local uci = require("luci.model.uci").cursor()


local function msg(txt, nor)
    local pfunc = nor and io.stdout or io.stderr
    pfunc:write(txt .. "\n")
end


local function parse_args()
    local function usage()
        msg("\nusage: " .. arg[0] .. " [-avh] [device]", true)
        msg("-a\tset altitude, too", true)
        msg("-v\tuse verbose output", true)
        msg("-p\tonly print the location, skip save")
        msg("-h\tprint this help", true)
        msg("\ndevice is: " .. device .. "\n", true)
    end

    for _, a in ipairs(arg) do
        if a == "-v" or a == "--verbose" then
            verbose = true
        elseif a == "-a" or a == "--altitude" then
            use_alt = true
        elseif a == "-p" or a == "--print" then
            print_only = true
        elseif a == "-h"  or a == "--help" then
            usage()
            os.exit(0)
        elseif string.sub(a, 1, 1) == '/' then -- string.startswith()
            device = a
        else
            msg("could not parse args")
            usage()
            os.exit(1)
        end
    end
end


local function get_location(device_path)
    local function conv(raw, bias, ltd)
        -- converting NMEA latitude & longitude to decimal
        local sp = ltd and 2 or 3
        -- is this a latitude or longitude value here?
        -- so chomp of the first two or three digits for the degrees
        local bs = (bias ~= "N" or bias ~= "E") and 1 or -1
        -- prefix location with a minus if location is in the south or west

        local deg = tonumber(string.sub(raw, 1, sp))
        local min = tonumber(string.sub(raw, sp+1, -1))

        return bs * (deg + min/60)
    end

    local location = {}
    local handle = io.open(device_path, "r")

    repeat
        local line = handle:read("*line")
        local data = util.split(line, ",")

        if data[1] == "$GPGGA" then

            if data[7] ~= "0" then -- no error in gps data
                location.latitude = conv(data[3], data[4], true)
                location.longitude = conv(data[5], data[6], false)
                location.altitude = tonumber(data[10])
            else
                if verbose then io.stdout:write(":") end
            end

        elseif data[1] == "$GPRMC" then

            if data[3] == "A" then -- real gps fix
                location.latitude = conv(data[4], data[5], true)
                location.longitude = conv(data[6], data[7], false)
           else
               if verbose then io.stdout:write(":") end
           end

        else
            if verbose then io.stdout:write(".") end
        end

    until (
        (location.latitude ~= nil) and (location.longitude ~= nil) and
        (use_alt and (location.altitude ~= nil) or true)
    )

    if verbose then msg("\\o/", true) end

    return location
end


local function save_location(location)
    local config = "gluon-node-info"
    local section = uci:get_first(config, "location")

    local share_location = uci:get_bool(config, section, "share_location")


    if location.latitude and not uci:set(config, section, "latitude", location.latitude) then
        return msg("could not set latitude " .. location.latitude)
    end
    if location.longitude and not uci:set(config, section, "longitude", location.longitude) then
        return msg("could not set longitude " .. location.longitude)
    end
    if location.altitude and not uci:set(config, section, "altitude", location.altitude) then
        return msg("could not set altitude " .. location.altitude)
    end

    if not uci:save(config) then
        return msg("could not save " .. config)
    end
    if not uci:commit(config) then
        return msg("could not commit " .. config)
    end

    if verbose and not share_location then
        msg("[warn] option 'share_location' is disabled", true)
    end

    return true
end


parse_args()

local location = get_location(device)

if print_only then
    msg(location, true)
else
    if not save_location(location) then
        if verbose then msg("sorry, something failed") end
        os.exit(1)
    end

    if verbose then msg("all went well", true) end
    os.exit(0)
end
