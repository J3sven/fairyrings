-- Small adapter for resolving generated component names to live UI proxies.
local Components = {}

-- Resolve the stable enum name to its current combined ID, then use the API's
-- combined-ID overload.
function Components.Get(componentName)
    local combinedID = id.Component[componentName]
    if combinedID == nil then
        return nil
    end
    return ui.Interfaces:GetComponent(combinedID)
end

return Components
