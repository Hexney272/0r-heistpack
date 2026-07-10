local Utils = require 'modules.utils.server'

local Exports = {}

---@param lobby Lobby
---@param job Job
---Called after a job has successfully started in the given lobby.
---Use this to initialize job-related server-side logic.
function Exports.onScenarioStarted(lobby, scenario)
    -- ?
end

---@param lobby Lobby
---@param lastScenario Scenario
---@param completed boolean -- Whether the scenario was completed successfully
---Called after a job has successfully stopped in the given lobby.
---Use this to finalize job data, give rewards, or clean up.
function Exports.onScenarioStopped(lobby, lastScenario, completed)
    -- ?
end

return Exports