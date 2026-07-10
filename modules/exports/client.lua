local Utils = require 'modules.utils.client'

local Exports = {}

---@param source number
---@param job Job
---Called after a job has successfully started.
---You can use this to set up job data, targets, or notify the player.
function Exports.onScenarioStarted(source, scenario)
    -- ?
end

---@param source number
---@param lastScenario Scenario
---@param completed boolean -- Whether the scenario was completed successfully.
---Called after a job has been successfully stopped.
---Use this to clean up, give rewards, or log the completion.
function Exports.onScenarioStopped(source, lastScenario, completed)
    -- ?
end

return Exports
