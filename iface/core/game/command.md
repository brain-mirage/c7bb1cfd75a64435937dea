# Experimental command availability

`--gateway 1` enables these answers for commands whose rules have moved to the gateway. Existing bindings and
`TK.Actions` still execute commands in their current input. These calls only read information.

```lua
local allowed, reason, waitMs = TK.Game.Can("open")
local stop = TK.Game.OnCan("open", function(allowed, reason, waitMs)
    -- Update this control. nil means the gateway does not know the answer yet.
end)
-- When the control is destroyed:
stop()
```

`Can(kind, slot, amount, route)` returns:

- `allowed`: true, false, or nil (unknown).
- `reason`: an empty string when allowed; otherwise the rule or the reason the answer is unknown.
- `waitMs`: remaining milliseconds for a timed wait, zero when allowed, or nil for a state-dependent/unknown wait.

`slot` defaults to 0 (none); lettered slots use the existing Lua 1-based convention. `amount` defaults to 0.
`route` is `key` by default, or `button`. The route is the input's origin, not a way to run the command.
The answer is for the split handler on that route. A self-look option is an unmoved route: use `selflook` to get
unknown, not the answer for the same option key outside that pane.

`OnCan(kind, fn, slot, amount, route)` calls `fn(allowed, reason, waitMs)` when availability or its reason changes.
It returns an unsubscribe function. Call `Can` for the initial state and for countdown updates; listeners do not
receive countdown-only changes. UI reload removes the old Lua listeners with their state.

Keys covered: `ride`, `open`, `boards`, `mail`, `helpmenu`, `helpmenu2`, `minimap`, `power`, and `option` amounts
9, 8, 2, 10, 7, 1 and 3 on the key route. Option buttons/self-look controls are not split yet.
The look window's `look:trade` and `look:group` commands are also covered on the `button` route.

Known stop reasons: `userpane-key-gate`, `open-wait`, `power-gm-flag`, `look-button-state`, `look-name-empty`.
The last one means Group has no target name: the press succeeds without a packet, as in the original.
Unknown reasons: `engine-decides`
(unmoved command/route), `input-routing` (an earlier handler may take the input), `not-in-world`, `not-connected`,
or `gateway-off`. An answer is advisory and may be a frame old. Execution asks again on the logic thread.

With the flag on, the existing `TK_ACTION_DONE(kind, result, reason)` adds the gateway's refusal reason as its third
argument (empty when the gateway did not refuse this command). With the flag off, that event keeps its two arguments.
The lower-level availability event is `TK_COMMAND_AVAILABILITY(kind, slot, amount, route, known, allowed, reason, waitMs)`;
its unknown/state-dependent wait is -1. Interfaces normally use `Can` and `OnCan` instead.
