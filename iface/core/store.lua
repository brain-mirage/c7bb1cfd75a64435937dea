-- The save rules shared by the profile and the machine settings (review F10):
--
--   * changes are written half a second after the last one, so a dragged slider is one write;
--   * "dirty" is cleared only after a write succeeded;
--   * a failed write is retried with a growing delay (1, 2, 4 ... 30 s), and the first failure is shown;
--   * anything about to replace the data in memory (switching profile, reloading) calls Flush() first and stops
--     if the write fails, so unsaved changes are never thrown away silently.
--
-- s6-gateway round 39 (head note 113): a store whose write is queued on the files thread (the profile, the machine
-- settings) names its file; the write's true then means "queued", and a failure there arrives later as TK_SAVE_FAILED
-- with that name, as a failed write. A flush, and a retry after a failure, write at once (write's now), so their answer
-- is the disk's.

local Store = {}
Store.__index = Store

--- A store for one document. write(data, now) returns true on success (now: on the disk before it returns); file names
--- a queued write's file for TK_SAVE_FAILED.
function TK.NewStore(what, write, file)
    -- s6-interface-5x (round 13, step 11): an interface panel's store is flushed and dropped when it is turned off
    return TK.Mark(setmetatable({ what = what, write = write, file = file, data = nil, dirty = false, failures = 0 }, Store))
end

function Store:MarkDirty()
    self.dirty = true
    self.dirtyAt = GetTime()
end

--- Writes now (queued, for a store with a file, unless now or after a failure). Returns true if the data is safely on
--- disk, or queued.
function Store:Save(now)
    if not self.data then return true end
    local ok = self.write(self.data, now == true or self.failures > 0) == true
    if ok then
        if self.failures > 0 then TK.Notify(self.what .. " saved again.") end
        self.dirty = false
        self.failures = 0
        self.retryAt = nil
    else
        self:Failed()
    end
    return ok
end

--- A write that failed, here or on the files thread: the changes are kept and tried again; the first failure is shown.
function Store:Failed()
    self.dirty = true
    self.failures = self.failures + 1
    self.retryAt = GetTime() + math.min(30, 2 ^ (self.failures - 1))
    if self.failures == 1 then
        TK.Popup(self.what .. " could not be saved. The changes are kept and saving will be tried again; "
            .. "switching profile or reloading waits until it works.", "Settings not saved")
    end
end

--- Saves pending changes before the data is replaced, on the disk before it returns. False means: do not replace it.
function Store:Flush()
    if not self.dirty then return true end
    return self:Save(true)
end

function Store:Tick(now)
    if not self.dirty then return end
    local due = self.retryAt or ((self.dirtyAt or 0) + 0.5)
    if now >= due then self:Save() end
end

TK.Stores = {}

local saver = CreateFrame("Frame", nil, UIParent)
saver:SetScript("OnUpdate", function()
    local now
    for _, s in ipairs(TK.Stores) do
        if s.dirty then
            now = now or GetTime()
            s:Tick(now)
        end
    end
end)

--- Saves every store; false if any failed (used before a reload, and at logout).
function TK.FlushAll()
    local ok = true
    for _, s in ipairs(TK.Stores) do
        if not s:Flush() then ok = false end
    end
    return ok
end

TK.On("PLAYER_LOGOUT", TK.FlushAll)

-- s6-gateway round 39 (head note 113): a queued write the files thread could not write (LuaApi's SaveFailed).
TK.On("TK_SAVE_FAILED", function(_, file)
    for _, s in ipairs(TK.Stores) do
        if s.file == file then s:Failed() end
    end
end)

-- s6-interface-5x (round 13, the separation's step 11): a panel turned off saves what its stores hold, and they go
TK.OnWithdraw(function(name, panel)
    for _, s in ipairs(TK.Stores) do
        if TK.OwnedBy(s, name, panel) then s:Flush() end
    end
    TK.DropOwned(TK.Stores, name, panel)
end)
