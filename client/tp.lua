local config = {
    ["player"] = "Toble_Miner",
    ["server"] = 248,
    ["modem"] = "back",
    ["channel"] = "teleport",
    ["wpfile"] = "waypoints"
}

local history = { "" }
local buffer = ""
local posX = 1
local posY = 1
local width, height = term.getSize()
local prefix = ">_ "
local historyPos = 0

function print(str)
    local lines = { }
    local pos = 1
    repeat
        local sub = str:sub(pos, pos + width - 1)
        posY = posY + 1
        if(posY == height) then
            term.scroll(1)
            posY = posY - 1
        end
        term.setCursorPos(1, posY)
        term.write(sub)
        pos = pos + width
    until #sub < width
    term.setCursorPos(posX + #prefix, posY)
end


Location = { }
Location.__index = Location

function Location.new(x, y, z)
    local loc = { }
    loc.x = x
    loc.y = y
    loc.z = z
    return loc
end

Waypoint = { }
Waypoint.__index = Waypoint

function Waypoint.new(name, x, y, z)
    local wayp = { }
    wayp.name = name
    wayp.x = x
    wayp.y = y
    wayp.z = z
    return wayp
end

local waypoints = { }

function tp(player, pos)
    local obj = {
        ["player"] = player,
        ["pos"] = pos
    }
    rednet.send(config.server, textutils.serialize(obj), config.channel)
end

function cmdTp(args)
    if(#args == 1) then --Waypoint
        local wayp = waypoints[args[1]:lower()]
        if(wayp == nil) then
            print(string.format("There is no waypoint called '%s'", args[1]))
            return true
        end
        tp(config.player, wayp)
    elseif(#args == 3) then --Coordinates
        local x = tonumber(args[1])
        local y = tonumber(args[2])
        local z = tonumber(args[3])
        if(not (x and y and z)) then
            print("Please specify three valid coordinates")
            return false
        end
        tp(config.player, Location.new(x, y, z))
    else
        return false
    end
    return true
end

function cmdAddWaypoint(args)
    if(#args == 1) then
        local wayp = Waypoint.new(args[1], gps.locate(3))
        if(not (wayp.x and wayp.y and wayp.z)) then
            print("Unable to use GPS location")
            return true
        end
        waypoints[args[1]:lower()] = wayp
    elseif(#args == 4) then
        local name = args[1]
        local x = tonumber(args[2])
        local y = tonumber(args[3])
        local z = tonumber(args[4])
        if(not (x and y and z)) then
            print("Please specify three valid coordinates")
            return false
        end
        waypoints[name:lower()] = Waypoint.new(name, gps.locate(3))
    else
        return false
    end
    store(config.wpfile)
    return true
end

function cmdRmWaypoint(args)
    local name = args[1]:lower()
    if(not waypoints[name]) then
        print(string.format("Waypoint '%s' doesn't exist", args[1]))
        return true
    end
    waypoints[name] = nil
    store(config.wpfile)
    return true
end

function cmdLsWaypoint(args)
    i = 0
    for _, wayp in pairs(waypoints) do
        i = i + 1
    end
    print(string.format("You have %d %s", i, i == 1 and "waypoint" or "waypoints"))
    for _, wayp in pairs(waypoints) do
        print(wayp.name)
    end
    return true
end

local cmds = {
    ["tp"] = {
        ["aliases"] = {
            "teleport"
        },
        ["minArgs"] = 1,
        ["maxArgs"] = 3,
        ["errMsg"] = "Usage: %s [<waypoint> x y z]",
        ["handler"] = cmdTp
    },
    ["add"] = {
        ["minArgs"] = 1,
        ["maxArgs"] = 4,
        ["errMsg"] = "Usage: %s <name> [x y z]",
        ["handler"] = cmdAddWaypoint
    },
    ["rm"] = {
        ["aliases"] = {
            "remove",
            "delete"
        },
        ["minArgs"] = 1,
        ["maxArgs"] = 1,
        ["errMsg"] = "Usage: %s <name>",
        ["handler"] = cmdRmWaypoint
    },
    ["ls"] = {
        ["aliases"] = {
            "list"
        },
        ["minArgs"] = 0,
        ["maxArgs"] = 0,
        ["errMsg"] = "Usage: %s",
        ["handler"] = cmdLsWaypoint
    },
    ["help"] = {
        ["minArgs"] = 0,
        ["maxArgs"] = 1,
        ["errMsg"] = "Usage: %s [command]",
        ["handler"] = cmdHelp
    }
}

function cmdHelp(args)
    if(#args == 0) then
        print("Commands:")
        table.foreach(cmds, function(cmd)
            print(cmd)
        end)
    else
        local cmd = cmds[args[1]:lower()]
        if(cmd == nil) then
            print(string.format("Unknown command '%s'", args[1]))
            return true
        end
        print(string.format("%s:", args[1]))
        print(string.format(cmd.errMsg, args[1]))
    end
    return true
end

function split(str, sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        str:gsub(pattern, function(c)
                fields[#fields + 1] = c
            end)
        return fields
end

function parseArgs(str)
    return split(str, " ")
end

function computeAliases()
    local aliases = { }
    for _, cmd in pairs(cmds) do
        if(cmd.aliases) then
            for _, alias in pairs(cmd.aliases) do
                aliases[alias] = cmd
            end
        end
    end
    for k, v in pairs(aliases) do
        cmds[k] = v
    end
end

function load(file)
    if(fs.exists(file)) then
        local flhndl = fs.open(file, "r")
        waypoints = textutils.unserialize(flhndl.readAll())
        flhndl.close()
    end
end

function store(file)
    local flhndl = fs.open(file, "w")
    flhndl.write(textutils.serialize(waypoints))
    flhndl.close()
end

function expandLine(str)
    if(#str < width) then
        for i = 1, width - #str do
            str = str .. " "
        end
    end
    return str
end

function render()
    term.setCursorPos(1, posY)
    term.write(expandLine(prefix..buffer))
    term.setCursorPos(posX + #prefix, posY)
end

rednet.open(config.modem)
load(config.wpfile)
computeAliases()

term.clear()
term.setCursorBlink(true)
render()
while true do
    local event, key = os.pullEvent()
    if(event == "char") then
        local part1 = buffer:sub(1, posX - 1)
        local part2 = buffer:sub(posX, #buffer)
        buffer = part1 .. key .. part2
        history[#history] = buffer
        posX = posX + 1
        render()
    elseif(event == "key") then
        if(key == keys.enter or key == keys.numPadEnter) then
            local args = parseArgs(buffer)
            if(#args > 0) then
                local cmdStr = args[1]
                local cmd = cmds[cmdStr:lower()]
                if(cmd ~= nil) then
                    if(history[#history - 1] ~= buffer) then
                        history[#history] = buffer
                    end
                    table.remove(args, 1)
                    if(#args >= cmd.minArgs and #args <= cmd.maxArgs) then
                        err, errmsg = pcall(cmd.handler, args)
                        if(not err) then
                            print(string.format("Error in %s: %s",
                                tostring(cmd.handler), errmsg))
                        elseif(not errmsg) then
                            print(string.format(cmd.errMsg, cmdStr))
                        end
                    else
                        print(string.format(cmd.errMsg, cmdStr))
                    end
                else
                    print(string.format("Unknown command '%s'", args[1]))
                    table.remove(history)
                end
            end
            posY = posY + 1
            if(posY == height) then
                term.scroll(1)
                posY = posY - 1
            end
            posX = 1
            buffer = ""
            table.insert(history, "")
        elseif(key == keys.left) then
            if(posX > 1) then
                posX = posX - 1
            end
        elseif(key == keys.right) then
            if(posX <= #buffer) then
                posX = posX + 1
            end
        elseif(key == keys.backspace) then
            if(posX > 1) then
                local part1 = buffer:sub(1, posX - 2)
                local part2 = buffer:sub(posX, #buffer)
                buffer = part1 .. part2
                posX = posX - 1
            end
        elseif(key == keys.up) then
            if(historyPos < #history - 1) then
                historyPos = historyPos + 1
                buffer = history[#history - historyPos]
                posX = #buffer + 1
            end
        elseif(key == keys.down) then
            if(historyPos > 0) then
                historyPos = historyPos - 1
                buffer = history[#history - historyPos]
                posX = #buffer + 1
            end
        elseif(key == keys.tab) then
            local args = parseArgs(buffer)
            if(#args == 1) then
                local match = {}
                local matchstr = ""
                for cmd in pairs(cmds) do
                    if(cmd:match(string.format("^%s", args[1]:lower()))) then
                        table.insert(match, cmd)
                        matchstr = string.format("%s%s ", matchstr, cmd)
                    end
                end
                if(#match == 1) then
                    buffer = match[1]
                    posX = #buffer + 1
                else
                    print(matchstr)
                    posY = posY + 1
                    if(posY == height) then
                        term.scroll(1)
                        posY = posY - 1
                    end
                end
            end
        end
        render()
    end
end
