local Target = {}

---@param key string
---@param parameters table
---@return number|string
function Target.addBoxZone(key, parameters)
    if shared.isResourceStart("ox_target") then
        parameters.name = key
        parameters.drawSprite = false
        return exports.ox_target:addBoxZone(parameters)
    elseif shared.isResourceStart("qb-target") then
        for _, option in pairs(parameters.options) do
            option.action = option.onSelect
        end
        local heading = 0.0
        if parameters.rotation then
            heading = type(parameters.rotation) == "table" and parameters.rotation.z or parameters.rotation or 0.0
        end

        exports["qb-target"]:AddBoxZone(key, parameters.coords, parameters.size.y, parameters.size.x,
            {
                name = key,
                heading = heading,
                debugPoly = parameters.debug,
                minZ = parameters.coords.z - parameters.size.z,
                maxZ = parameters.coords.z + parameters.size.z,
            }, { options = parameters.options, distance = 2.5, })
        return key
    else
        -- ? Use your target script export
        return key
    end
end

---@param id string|number
---@return boolean
function Target.removeZone(id)
    if shared.isResourceStart("ox_target") then
        exports.ox_target:removeZone(id)
    elseif shared.isResourceStart("qb-target") then
        exports["qb-target"]:RemoveZone(id)
    else
        -- ? Use your target script export
    end
    return true
end

---@param entities number|number[]
---@param options OxTargetEntity|OxTargetEntity[]
---@return boolean
function Target.addLocalEntity(entities, options)
    if shared.isResourceStart("ox_target") then
        exports.ox_target:addLocalEntity(entities, options)
    elseif shared.isResourceStart("qb-target") then
        for _, option in pairs(options) do
            option.job = option.groups
            option.action = option.onSelect
        end
        exports["qb-target"]:AddTargetEntity(entities, {
            options = options,
        })
    else
        -- ? Use your target script export
    end
    return true
end

---@param entities number|number[]
---@param optionNames? string|string[]
---@param labels? string|string[]
---@return boolean
function Target.removeLocalEntity(entities, optionNames, labels)
    if shared.isResourceStart("ox_target") then
        exports.ox_target:removeLocalEntity(entities, optionNames)
    elseif shared.isResourceStart("qb-target") then
        exports["qb-target"]:RemoveTargetEntity(entities, labels)
    else
        -- ? Use your target script export
    end
    return true
end

function Target.addGlobalVehicle(options)
    if shared.isResourceStart("ox_target") then
        exports.ox_target:addGlobalVehicle(options)
    elseif shared.isResourceStart("qb-target") then
        for _, option in pairs(options) do
            option.job = option.groups
            option.action = option.onSelect
        end
        exports["qb-target"]:AddGlobalVehicle({ options = options })
    else
        -- ? Use your target script export
    end
    return true
end

function Target.removeGlobalVehicle(name, label)
    if shared.isResourceStart("ox_target") then
        exports.ox_target:removeGlobalVehicle(name)
    elseif shared.isResourceStart("qb-target") then
        exports["qb-target"]:RemoveGlobalVehicle(label)
    else
        -- ? Use your target script export
    end
    return true
end

function Target.addModel(model, options)
    if shared.isResourceStart("ox_target") then
        exports.ox_target:addModel(model, options)
    elseif shared.isResourceStart("qb-target") then
        for key, option in pairs(options) do
            option.job = option.groups
            option.action = option.onSelect
        end
        exports["qb-target"]:AddTargetModel(model, {
            options = options,
        })
    else
        -- ? Use your target script export
    end
    return true
end

function Target.removeModel(models, optionNames, labels)
    if shared.isResourceStart("ox_target") then
        exports.ox_target:removeModel(models, optionNames)
    elseif shared.isResourceStart("qb-target") then
        exports["qb-target"]:RemoveTargetModel(models, labels)
    else
        -- ? Use your target script export
    end
    return true
end

return Target
