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

export type Cleanup = typeof(setmetatable({} :: { _tasks: { Task }, _destroyed: boolean }, Cleanup))

local function cleanupOne(item: Task)
	if typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif type(item) == "function" then
		item()
	end
end

function Cleanup.new(): Cleanup
	return setmetatable({ _tasks = {}, _destroyed = false }, Cleanup)
end

-- Track a task and return it, e.g. `local conn = trove:add(sig:Connect(fn))`.
-- If the trove has already been destroyed, the task is cleaned up immediately
-- rather than retained — this guards the "leave during an async yield, then a
-- late task:add lands after teardown" race so nothing is silently leaked.
function Cleanup.add(self: Cleanup, item: Task): Task
	if self._destroyed then
		cleanupOne(item)
		return item
	end
	table.insert(self._tasks, item)
	return item
end

-- Run and clear every tracked task in reverse (LIFO) order. Idempotent: a second
-- call is a no-op, and any task added afterwards is cleaned immediately.
function Cleanup.destroy(self: Cleanup)
	self._destroyed = true
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		cleanupOne(tasks[i])
	end
end

return Cleanup
