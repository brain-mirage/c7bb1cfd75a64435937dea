-- Local Server is its own Servers section, for Local and Dedicated mode. It configures the packaged server folder,
-- ports and game settings for its next start. Allow Remote Users is off by default while playing locally; Dedicated
-- allows remote connections. The existing controller writes map.conf and char.conf. Login screen only.

local H = __tk
local SECTION = "local_server"
local MAX_PORT = 65529 -- the first port: the server takes it and the six after it

local function int(key) return H:ClientSettingInt(SECTION, key) end

local function setInt(key, value)
    H:ClientSettingSetInt(SECTION, key, math.floor(value))
    H:ClientSettingsSave()
end

--- A whole number from a field's text within min..max, or nil (a field's text is kept as typed; only a number is saved).
local function number(text, min, max)
    local n = tonumber(text)
    if not n or n ~= math.floor(n) or n < min or n > max then return nil end
    return n
end

--- "" (the LAN address, found by the server) or an IPv4 address, else nil.
local function address(text)
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return "" end
    local a, b, c, d = text:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end -- not four numbers (the captures are all nil then, and a loop over them sees none)
    for _, part in ipairs({ a, b, c, d }) do
        if tonumber(part) > 255 then return nil end
    end
    return text
end

local function rate(key, name)
    return { type = "range", name = name, min = 1, max = 20, step = 1,
             get = function() return math.max(1, int(key)) end, set = function(_, v) setInt(key, v) end,
             default = function() return H:ClientSettingDefaultInt(SECTION, key) end }
end

TK.LocalServerNode = { id = "localserver", title = "Local Server", order = 891, category = "general", parent = "servers", loginOnly = true,
    machine = true,
    db = function() return {} end,
    tabs = { { name = "Local Server", args = {
        { type = "input", name = "Server Folder", live = true,
          desc = "Empty uses the shipped dedicated-server folder. Choose another packaged server folder on this PC if needed.",
          get = function() return H:ClientSettingString(SECTION, "path") end,
          set = function(_, text)
              H:SetLocalServerPath((text:gsub("^%s+", ""):gsub("%s+$", "")))
              H:ClientSettingsSave()
              TK.Login:UpdateButtons()
          end,
          default = function() return "" end },
        { type = "description", name = function() return H:ClientSettingString(SECTION, "path") == "" and "Folder: bundled server" or "Folder: custom" end },
        { type = "header", name = "Connections" },
        { type = "input", name = "First Port", live = true,
          desc = "The server takes the first port and the six after it.",
          get = function() return tostring(int("port")) end,
          set = function(_, text)
              local n = number(text, 1, MAX_PORT)
              if n then setInt("port", n) end
          end,
          default = function() return tostring(H:ClientSettingDefaultInt(SECTION, "port")) end },
        -- s6-optimize (round 34): the parent has its own row, with the address below it.
        { type = "toggle", name = "Allow Remote Users", width = "full",
          desc = "Allows other players to connect while you play locally. Off, the server listens only on this PC. Dedicated always allows remote users.",
          get = function() return H:ClientSettingBool(SECTION, "internet") end,
          set = function(_, v)
              H:ClientSettingSetBool(SECTION, "internet", v and true or false)
              H:ClientSettingsSave()
          end,
          default = function() return H:ClientSettingDefaultBool(SECTION, "internet") end },
        -- The advertised address is used only for remote users (ServerHost.Arguments).
        -- Dedicated always allows remote users, regardless of the Local switch.
        { type = "group", requires = { TK.Needs("Allow Remote Users or Dedicated", function()
            return H:ClientSettingBool(SECTION, "internet") or TK.Login.mode == "server"
        end) }, args = {
            { type = "input", name = "Address for Players", live = true,
              get = function() return H:ClientSettingString(SECTION, "address") end,
              set = function(_, text)
                  local a = address(text)
                  if a then
                      H:ClientSettingSetString(SECTION, "address", a)
                      H:ClientSettingsSave()
                  end
              end,
              default = function() return H:ClientSettingDefaultString(SECTION, "address") end },
        } },
        { type = "description", name = "The address is the one it "
            .. "gives the players; empty, it is this computer's LAN address. Players outside this network need the router "
            .. "to forward the seven ports to this computer, and the address here to be the network's public one." },
        { type = "header", name = "The Server's Settings" },
        rate("xp_rate", "Experience Rate"),
        rate("drop_rate", "Drop Rate"),
        { type = "range", name = "Save Every (seconds)", min = 10, max = 600, step = 10,
          get = function() return math.max(10, int("save_seconds")) end, set = function(_, v) setInt("save_seconds", v) end,
          default = function() return H:ClientSettingDefaultInt(SECTION, "save_seconds") end },
        { type = "input", name = "Starting Gold", live = true,
          get = function() return tostring(int("start_money")) end,
          set = function(_, text)
              local n = number(text, 0, 2147483647)
              if n then setInt("start_money", n) end
          end,
          default = function() return tostring(H:ClientSettingDefaultInt(SECTION, "start_money")) end },
    } } } }
