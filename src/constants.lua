-- Shared timing and geometry values. Logic intervals are expressed in client
-- logic ticks; the client runs at 50 ticks per second.
local Constants = {
    EVENT_ID = "fairyring_search",
    CLOSED_POLL_INTERVAL = 50,
    ACTIVE_UPDATE_INTERVAL = 5,
    -- Text changes filter immediately. This slower refresh only repairs rows
    -- rebuilt by native sorting or favourite scripts.
    FILTER_INTERVAL = 25,
    -- Ring dial animations can rewrite the list for several frames. Enforce an
    -- active query every logic tick for one second after either click target.
    CLICK_REAPPLY_TICKS = 50,
    SEARCH_HEIGHT = 28,
    SEARCH_GAP = 34,
    SEARCH_Y_OFFSET = -9,
    SEARCH_PADDING = 8,
    CARET_HEIGHT = 18,
    CARET_BLINK_TICKS = 15,
}

return Constants
