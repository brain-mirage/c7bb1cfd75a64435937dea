local C = TK.GetComponent("macros")
local H = __tk

C.defaults = { originalSetup = false }

-- s6-sandbox (round 14): why the last prefix typed was refused ("" when it was taken).
local refused = ""
local serverRefused = "" -- s6-play-modes (round 4): the same for the server command prefix

function C:SettingsNodes()
    local function p() return H:CommandPrefix() end
    local args = {
        { type = "description", name = function()
            return "Macros run this client's commands with one press, as in WoW: " .. p() .. "cast, " .. p() .. "use, "
                .. p() .. "castsequence, " .. p() .. "target, " .. p() .. "focus, " .. p() .. "startattack, " .. p()
                .. "say, " .. p() .. "yell, " .. p() .. "whisper, " .. p() .. "party, " .. p() .. "clan and the others the "
                .. "macro window lists. Make one with New (a name and an icon), then drag it from the window onto an action "
                .. "bar button or the action wheel: that button's key runs it. Each action sends exactly what its button or "
                .. "key sends. Any other line is said to the server as written, as the original client said it; a server "
                .. "command (a / line) is not sent from a macro: type it in the chat's Terminal tab."
        end },
        { type = "binding", name = "Open the Macros window", command = "TOGGLEMACROS" },
        { type = "description", name = "A macro's key is its action bar button's. Every key is in the Key Bindings list (Key Bindings, at the end of the list on the left); its Macros group has this window's key, Original Macro Setup and keys bound to macros before." },
        { type = "execute", name = "Key Bindings List: Macros", func = function() C:ShowBindingsList() end },
        -- s6-sandbox (round 14; the owner, 2026-10-03): our commands' own prefix, kept in settings.toml ([chat] command_prefix).
        { type = "header", name = "Client Commands" },
        { type = "input", name = "Client command prefix", live = true,
          get = function() return p() end,
          set = function(_, text) refused = C:SetCommandPrefix(text) end,
          default = function() return H:ClientSettingDefaultString("chat", "command_prefix") end },
        { type = "description", name = function()
            if refused ~= "" then return "Not changed: " .. refused .. ". The prefix is still " .. p() .. "." end
            return "The prefix is " .. p() .. ": " .. p() .. "cast Heal, " .. p() .. "dance, a plugin's " .. p() .. "rc."
        end },
        { type = "description", name = "This client's own commands (the macro commands, the emotes by name and plugins' commands) start with this prefix, in the chat line, in macros and from plugins alike; such a line is never sent to the server, and a name that is no command shows a short message. The prefix is up to four characters without letters, digits or spaces, not a single / and not starting with #. Changing it rewrites the command lines of your macros to the new prefix; the original's thirty text hotkeys are left as they are." },
        -- s6-play-modes (round 4; the owner, 2026-10-05): the server's command (GM) prefix, kept in settings.toml ([chat] server_command_prefix).
        { type = "header", name = "Server Commands" },
        -- round 6 (the owner's short-text rule, 2026-10-05): the explanation is the tooltip; the page says only a refusal
        { type = "input", name = "Server command prefix", live = true,
          desc = "Lines starting with it (or with /) are sent only when typed in the chat's Terminal.",
          get = function() return H:ServerCommandPrefix() end,
          set = function(_, text) serverRefused = H:SetServerCommandPrefix(text) end,
          default = function() return H:ClientSettingDefaultString("chat", "server_command_prefix") end },
        { type = "description", name = function() return serverRefused ~= "" and ("Not changed: " .. serverRefused .. ".") or "" end },
        { type = "header", name = "The Original's Hotkeys" },
        { type = "toggle", key = "originalSetup", name = "Show the original's hotkey setup (Macro Setup)" },
        { type = "description", name = "The original client's thirty text hotkeys, on keys 1 to 0, Ctrl+1 to Ctrl+0 and Alt+1 to Alt+0, and its Macro Setup dialog. On: the macro window has a Hotkeys tab to edit them, the Menu's Hotkey opens the original's dialog, and Original Macro Setup can be given a key (F11 was the original's). Off: the Menu's Hotkey and F11 open the macro window. The text hotkeys already on your bars say their lines either way; editing their text needs this on. Original Macro Setup's key is set in the Key Bindings list's Macros group (the button above)." },
    }
    return {
        { id = self.name, title = self.title, order = self.order, tabs = { { name = "Macros", args = args } },
          db = function() return self:DB() end,
          defaults = function() return self.defaults end }, -- s6-ui-settings: what the page's reset icon puts back
    }
end
