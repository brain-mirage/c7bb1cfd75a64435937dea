# Experimental command metadata, availability, and named execution

`--gateway 1` enables these answers for commands whose rules have moved to the gateway. `Commands`, `Can`, and
`OnCan` only read information; existing bindings and `TK.Actions` still execute commands in their current input.
The separate experimental `TK.Game.Command` entry point can request a named command from an input owned by the UI.

`TK.Game.Commands()` returns fresh plain metadata rows for the layered session, or an empty table without one.
Each row has `kind`, `ruled`, `needsInput`, `inputExemption`, `cites` and `mode`. A base row has an empty mode;
5.33's sound-mute override has mode `5.x`, selected by the existing version policy. There are no eligibility
numbers or performing callbacks in this data. Editing a returned row changes only that Lua table.

The list includes internal binding and native continuation kinds. It describes the command surface, not which
commands are currently available or callable through a particular UI method. `needsInput` and `inputExemption`
record the plan's provenance requirements. Native and direct-input checks for named execution are complete; the
contract is below. An exemption describes a trusted engine continuation, not permission to invoke it from a timer:
a named request for a ruled command still needs genuine input. Use `Can` for the live advisory answer on the routes
that support it.

## Named execution

`TK.Game.Command(kind, slot, amount, text)` requests one command and returns nothing. `slot` defaults to 0 (none);
lettered slots use the existing Lua 1-based convention. `amount` defaults to 0 and `text` defaults to the empty
string. The request uses the existing connection action sink and engine, with actual source data only; it does not
fabricate input. Availability questions do not reserve input.

Connected requests are decided on the logic thread. Completion is reported through the existing
`TK_ACTION_DONE(kind, result, reason)` event, where `result` is the actual `ok`, `refused`, or `unavailable` result.
A ruled request outside genuine input is refused with `needs-input`; a spent input is refused with `input-spent`;
and UI capture that already owns unspent input is refused with `input-claimed`. Named key repeat and key-up phases
are refused with `input-phase`. An unknown kind is refused and logged with `unknown-command`.

Native input keeps its frozen data first, and its first-command claim stays in place; native dialog values are kept
as data. A named mouse-down and mouse-up for the same button are one named request. If there was no named
mouse-down request, the normal `OnClick` mouse-up behavior still works.

Metadata is not a performer registry or a promise that every listed kind is callable. Existing
`RuleFamily`/`SessionActions` performers are used; an unsupported existing kind remains unavailable. No menu,
audio, or lifecycle payload formats are added. The native input exemption is for engine continuation only. This
entry point is for the client's own UI: the separate plugin sandbox API does not export `Command` (boundary
question 136 is unchanged).

With no session the request completes as unavailable with `not-connected`. With a session but the gateway flag
off, the new entry point completes as unavailable with `gateway-off`. Existing bound-event behavior with the flag
off is unchanged.

For example, an own button can make a named request in its `OnClick`, without a bound action. Register the
completion listener before the click:

```lua
TK.On("TK_ACTION_DONE", function(_, kind, result, reason)
    if kind == "macro" then
        -- Handle this named request's actual result.
    end
end)

-- In the own button's OnClick script:
TK.Game.Command("macro", 0, 0, "Hello")
```

Call this from the button's genuine input callback, not a timer. The completion listener reports the result; it
does not make a timer call eligible for a ruled command.

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
