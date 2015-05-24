local config = {
    ["modem"] = "top",
    ["interface"] = "right",
    ["channel"] = "teleport"
}

local adv = peripheral.wrap(config.interface)

rednet.open(config.modem)

while true do
    local id, msg = rednet.receive(config.channel)
    local err, errmsg = pcall(function()
        local obj = textutils.unserialize(msg)
        local player = adv.getPlayerByName(obj.player)
        local pos = obj.pos
        local entity = player.asEntity()
        entity.setPosition(pos.x, pos.y, pos.z)
        print(string.format("Teleporting %s to %d;%d;%d", obj.player, pos.x,
            pos.y, pos.z))
    end)
    if(not err) then
        print("Failed to handle tp packet: "..errmsg)
    end
end
