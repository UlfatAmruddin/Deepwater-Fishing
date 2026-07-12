--!strict
-- Minimal cleanup helper ("trove"/"maid").
--
-- Tracks connections, instances, and teardown callbacks so per-player or
-- per-run state can be released in a single call. This backs the engineering
-- rule that every connection is disconnected and per-player state is cleaned
-- when a player leaves.

type Task = RBXScriptConnection | Instance | () -> ()

local Cleanup = {}
Cleanup.__index = Cleanup

export type Cleanup = typeof(setmetatable({} :: { _tasks: { Task } }, Cleanup))

function Cleanup.new(): Cleanup
	return setmetatable({ _tasks = {} }, Cleanup)
end

-- Track a task and return it, e.g. `local conn = trove:add(sig:Connect(fn))`.
function Cleanup.add(self: Cleanup, item: Task): Task
	table.insert(self._tasks, item)
	return item
end

local function cleanupOne(item: Task)
	if typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif type(item) == "function" then
		item()
	end
end

-- Run and clear every tracked task in reverse (LIFO) order.
function Cleanup.destroy(self: Cleanup)
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		cleanupOne(tasks[i])
	end
end

return Cleanup
