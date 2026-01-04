--[[
    ConnectionManager.lua - Centralized Connection & Resource Management
    ====================================================================
    Provides utilities for tracking and cleaning up:
    - RBXScriptConnections (events)
    - Spawned GUI instances
    - Character-related objects (welds, body movers)
    - RunService loops
    
    Usage:
        local CM = LoadModule("Modules/ConnectionManager")
        
        -- Track a connection
        CM.Track("myFeature", connection)
        
        -- Disconnect specific feature
        CM.Cleanup("myFeature")
        
        -- Disconnect all
        CM.CleanupAll()
]]

local ConnectionManager = {}

-- Storage for tracked resources
local TrackedConnections = {} -- { [tag] = { connections... } }
local TrackedInstances = {} -- { [tag] = { instances... } }
local CleanupCallbacks = {} -- { [tag] = function }

-- ═══════════════════════════════════════════════════════════════════
-- CONNECTION TRACKING
-- ═══════════════════════════════════════════════════════════════════

--[[
    Track a connection with an optional tag for grouped cleanup
    
    @param tag: String identifier for grouping (e.g., "fly", "speed", "esp")
    @param connection: RBXScriptConnection to track
    @return connection: The same connection for chaining
]]
function ConnectionManager.Track(tag, connection)
	if not tag then
		tag = "default"
	end
	if not connection then
		return nil
	end

	if not TrackedConnections[tag] then
		TrackedConnections[tag] = {}
	end

	table.insert(TrackedConnections[tag], connection)
	return connection
end

--[[
    Track an Instance for cleanup (e.g., BodyVelocity, ScreenGui)
    
    @param tag: String identifier for grouping
    @param instance: Instance to track
    @return instance: The same instance for chaining
]]
function ConnectionManager.TrackInstance(tag, instance)
	if not tag then
		tag = "default"
	end
	if not instance then
		return nil
	end

	if not TrackedInstances[tag] then
		TrackedInstances[tag] = {}
	end

	table.insert(TrackedInstances[tag], instance)
	return instance
end

--[[
    Register a cleanup callback for a specific tag
    
    @param tag: String identifier
    @param callback: Function to call during cleanup
]]
function ConnectionManager.OnCleanup(tag, callback)
	if not tag or not callback then
		return
	end
	CleanupCallbacks[tag] = callback
end

-- ═══════════════════════════════════════════════════════════════════
-- CLEANUP FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

--[[
    Cleanup all resources for a specific tag
    
    @param tag: String identifier to cleanup
]]
function ConnectionManager.Cleanup(tag)
	if not tag then
		return
	end

	-- Disconnect connections
	if TrackedConnections[tag] then
		for _, conn in ipairs(TrackedConnections[tag]) do
			if conn and typeof(conn) == "RBXScriptConnection" then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		TrackedConnections[tag] = nil
	end

	-- Destroy instances
	if TrackedInstances[tag] then
		for _, inst in ipairs(TrackedInstances[tag]) do
			if inst and typeof(inst) == "Instance" then
				pcall(function()
					inst:Destroy()
				end)
			end
		end
		TrackedInstances[tag] = nil
	end

	-- Call cleanup callback
	if CleanupCallbacks[tag] then
		pcall(CleanupCallbacks[tag])
		CleanupCallbacks[tag] = nil
	end
end

--[[
    Cleanup ALL tracked resources
]]
function ConnectionManager.CleanupAll()
	-- Cleanup all tagged resources
	for tag in pairs(TrackedConnections) do
		ConnectionManager.Cleanup(tag)
	end

	for tag in pairs(TrackedInstances) do
		ConnectionManager.Cleanup(tag)
	end

	for tag in pairs(CleanupCallbacks) do
		pcall(CleanupCallbacks[tag])
	end

	-- Clear all tables
	TrackedConnections = {}
	TrackedInstances = {}
	CleanupCallbacks = {}
end

-- ═══════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════

--[[
    Clean character-related objects (welds, body movers, etc.)
    Useful when respawning or disabling character features
    
    @param character: Character model to clean
    @param filterName: Optional name filter for objects
]]
function ConnectionManager.CleanCharacter(character, filterName)
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	-- Clean body movers
	local bodyMovers = {
		"BodyVelocity",
		"BodyGyro",
		"BodyPosition",
		"BodyForce",
		"BodyAngularVelocity",
		"AlignPosition",
		"AlignOrientation",
		"LinearVelocity",
		"AngularVelocity",
	}

	for _, child in ipairs(rootPart:GetChildren()) do
		for _, moverType in ipairs(bodyMovers) do
			if child:IsA(moverType) then
				if not filterName or child.Name:find(filterName) then
					pcall(function()
						child:Destroy()
					end)
				end
			end
		end
	end

	-- Clean welds with certain names
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("WeldConstraint") or child:IsA("Weld") then
			if filterName and child.Name:find(filterName) then
				pcall(function()
					child:Destroy()
				end)
			end
		end
	end
end

--[[
    Check if a connection is still valid/connected
    
    @param connection: RBXScriptConnection to check
    @return boolean: true if connected
]]
function ConnectionManager.IsConnected(connection)
	if not connection then
		return false
	end
	if typeof(connection) ~= "RBXScriptConnection" then
		return false
	end
	return connection.Connected
end

--[[
    Get count of tracked connections by tag
    
    @param tag: Optional tag to filter
    @return number: Count of connections
]]
function ConnectionManager.GetCount(tag)
	if tag then
		return TrackedConnections[tag] and #TrackedConnections[tag] or 0
	end

	local total = 0
	for _, conns in pairs(TrackedConnections) do
		total = total + #conns
	end
	return total
end

--[[
    Get all tracked tags (for debugging)
    
    @return table: List of tags
]]
function ConnectionManager.GetTags()
	local tags = {}
	for tag in pairs(TrackedConnections) do
		table.insert(tags, tag)
	end
	for tag in pairs(TrackedInstances) do
		if not TrackedConnections[tag] then
			table.insert(tags, tag)
		end
	end
	return tags
end

--[[
    Debug: Print all tracked resources
]]
function ConnectionManager.DebugPrint()
	print("=== ConnectionManager Debug ===")
	print("Connections:")
	for tag, conns in pairs(TrackedConnections) do
		local connectedCount = 0
		for _, c in ipairs(conns) do
			if c and typeof(c) == "RBXScriptConnection" and c.Connected then
				connectedCount = connectedCount + 1
			end
		end
		print(string.format("  [%s]: %d total, %d connected", tag, #conns, connectedCount))
	end
	print("Instances:")
	for tag, insts in pairs(TrackedInstances) do
		local validCount = 0
		for _, i in ipairs(insts) do
			if i and typeof(i) == "Instance" and i.Parent then
				validCount = validCount + 1
			end
		end
		print(string.format("  [%s]: %d total, %d valid", tag, #insts, validCount))
	end
	print("Callbacks:")
	for tag in pairs(CleanupCallbacks) do
		print(string.format("  [%s]: registered", tag))
	end
	print("==============================")
end

return ConnectionManager
