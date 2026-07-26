-- Plugin lifecycle coordinator. It detects the native Fairy Ring interface,
-- attaches the layout/search/filter helpers as one unit, and restores the
-- native interface when it closes or the plugin shuts down.
local Constants = require("src/constants")
local Components = require("src/components")
local DestinationFilter = require("src/destination_filter")
local NativeLayout = require("src/native_layout")
local SearchUI = require("src/search_ui")

local state = {
    interface = nil,
    filter = nil,
    layout = nil,
    searchUI = nil,
}

local function detach(restore)
    -- Once the native interface is unloaded its component proxies are invalid.
    -- Restore only when the interface still exists.
    if restore then
        if state.filter ~= nil then
            state.filter:Restore()
        end
        if state.layout ~= nil then
            state.layout:Restore()
        end
    end
    if state.searchUI ~= nil then
        state.searchUI:Destroy()
    end

    state.interface = nil
    state.filter = nil
    state.layout = nil
    state.searchUI = nil
end

local function attach(interface, holder)
    local layout = NativeLayout.new()
    if layout == nil or not layout:Apply() then
        return false
    end

    local filter = DestinationFilter.new()
    local searchUI, searchError =
        SearchUI.new(holder, layout, filter)
    if searchUI == nil then
        layout:Restore()
        log("fairyrings: " .. tostring(searchError))
        return false
    end

    state.interface = interface
    state.filter = filter
    state.layout = layout
    state.searchUI = searchUI
    return true
end

local function currentOpenInterface()
    local interfaceID = id.Interface["FAIRYRINGS"]
    if interfaceID == nil then
        return nil, nil, nil
    end
    local interface = ui.Interfaces:GetInterface(interfaceID)
    if interface == nil then
        return nil, nil, nil
    end

    local holder = Components.Get("FAIRYRINGS__LOG_CONTENT_HOLDER")
    if holder == nil then
        return interface, nil, nil
    end

    local ok, visible = pcall(function()
        return holder.visible
    end)
    if not ok or not visible then
        return interface, nil, nil
    end
    return interface, interface, holder
end

local function onLogic(event)
    -- The API has no interface-open event. Poll once per second while dormant,
    -- then update more often while attached so native layout rebuilds and the
    -- custom caret are corrected promptly.
    local updateInterval = state.interface == nil
        and Constants.CLOSED_POLL_INTERVAL
        or Constants.ACTIVE_UPDATE_INTERVAL
    local immediateFilterUpdate = state.filter ~= nil
        and state.filter:NeedsImmediateUpdate()
    if not immediateFilterUpdate
        and event.logicTick % updateInterval ~= 0
    then
        return
    end

    local loadedInterface, openInterface, holder =
        currentOpenInterface()
    if openInterface ~= state.interface then
        if state.interface ~= nil then
            detach(loadedInterface ~= nil)
        end
        if openInterface ~= nil then
            attach(openInterface, holder)
        end
        return
    end

    if openInterface ~= nil then
        state.layout:Apply()
        state.searchUI:Update(holder, event.logicTick)
        if immediateFilterUpdate
            or (
                state.filter:NeedsUpdate()
                and event.logicTick % Constants.FILTER_INTERVAL == 0
            )
        then
            state.filter:Apply()
        end
    end
end

Event.Logic.Subscribe(Constants.EVENT_ID, onLogic)

function PluginShutdown()
    Event.Logic.Unsubscribe(Constants.EVENT_ID)
    detach(true)
end
