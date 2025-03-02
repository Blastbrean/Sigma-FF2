---! FF2 hider part.
---@note: Code is messy and ugly, but it was made hastily and for fun.

if game.PlaceId ~= 8204899140 and game.PlaceId ~= 104709320604721 and game.PlaceId ~= 8206123457 then
	return
end

if not hookfunction or not hookmetamethod or not firetouchinterest then
	local players = game:GetService("Players")
	local local_player = players and players.LocalPlayer
	return local_player and local_player:Kick("unsupported exploit")
end

if not LPH_OBFUSCATED then
	loadstring("LPH_NO_VIRTUALIZE = function(...) return ... end")()
end

local environment = getgenv()

---@note: if we simply increase the sizes of the parts the TouchInterest is touching / is on, it's not going to replicate properly
--- we must manually replicate it with (firetouchinterest) - R.I.P
---it's going to flag you if you have too many suspicious far / false touches lol.

---@todo: dynamic speed-up based on distance to nearest player to be slightly ahead.
---@note: check if we're behind the qb line and rushing, increase speed up.
---@note: check if anyone has the football equipped (we want to run / tackle), increase speed up.
---@note: check if we're selecting captains, increase speed up.
---@note: check if other team is kicking, increase speed up.

---@todo: only jp/boost when a ball in the air is in distance
---@todo: cap jump power amount if we're going to jump over the ball (never go below default)
---@todo: don't increase jump power if they're kicking

---@todo: perfect kick timing
---@todo: auto-catch input in end-zone / within first down range.
---@todo: reduce dive cooldown
---@todo: reduce stunned cooldown
---@todo: ball prediction
---@todo: qb trajectories & qb aimbot
---@todo: dive velocity increase

local sigma = {
	["speed"] = false,
	["speed_amount"] = 21,
	["jump_power"] = false,
	["jump_power_amount"] = 50 * 1.1,
	["boost_on_height"] = true,
	["boost_amount"] = 1.15,
	["increase_catch_size"] = Vector3.new(10, 10, 10),
	["visualize_catch_zone"] = true,
	["reduce_catch_tackle"] = true,
}

if not environment.sigma then
	environment.sigma = sigma
end

local MIN_CPU_OFFSET = 100
local MAX_CPU_OFFSET = 9999
local DEFAULT_CPU_OFFSET = 3600

---@todo: automatically reset cpu_offset when the user is banned.
---@todo: store cpu history so we don't use another offset multiple times.
if not isfile("cpu_offset.txt") then
	writefile("cpu_offset.txt", math.random(MIN_CPU_OFFSET, MAX_CPU_OFFSET))
end

local success, cpu_offset = pcall(readfile, "cpu_offset.txt")

if not success then
	cpu_offset = DEFAULT_CPU_OFFSET
end

cpu_offset = tonumber(cpu_offset)

if not cpu_offset then
	cpu_offset = DEFAULT_CPU_OFFSET
end

cpu_offset = math.round(cpu_offset)
cpu_offset = math.clamp(cpu_offset, MIN_CPU_OFFSET, MAX_CPU_OFFSET)

local content_provider = game:GetService("ContentProvider")
local log_service = game:GetService("LogService")
local script_context = game:GetService("ScriptContext")
local core_gui = game:GetService("CoreGui")
local starter_player = game:GetService("StarterPlayer")
local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local http_service = game:GetService("HttpService")
local is_a = game.IsA

local fake_instance = Instance.new("Part")
local fake_signal = fake_instance:GetAttributeChangedSignal("FAKE_SIGNAL_")
local core_gui_instances_cache = {}

for _, instance in next, core_gui:GetChildren() do
	-- filter out the bad shutter sound later.
	if instance.Name == "RobloxGui" then
		continue
	end

	core_gui_instances_cache[#core_gui_instances_cache + 1] = instance
end

local default_walkspeed = starter_player.CharacterWalkSpeed
local default_jump_power = starter_player.CharacterJumpPower

---@possible_detection: fake request internal - poor implementation.
local fake_request_internal = newcclosure(function()
	error("The current thread cannot call 'RequestInternal' (lacking capability RobloxScript)")
end)

-- hook detection fix.
local cached_namecall_function = nil

-- cache namecall function.
xpcall(function()
	game:_()
end, function()
	cached_namecall_function = debug.info(2, "f")
end)

-- sanity check.
if not cached_namecall_function then
	return warn("[ff2_hider] failed to cache namecall function")
end

-- hide *some* changes made by us - let the game not see our changes.
local reflection_map = {}
local default_index_map = {}

-- store parts to update or track.
local catch_parts_data = {}
local football_parts_data = {}
local is_catching = false

local orig_debug_info = nil
local orig_os_clock = nil
local orig_is_a = nil
local orig_get_property_changed_signal = nil
local orig_preload_async = nil
local orig_log_service = nil
local orig_game_namecall = nil
local orig_game_index = nil
local orig_game_newindex = nil
local orig_catch = nil

local function log_warn(str, ...)
	return warn("[ff2_hider]" .. " " .. string.format(str, ...))
end

local table_shallow_clone = LPH_NO_VIRTUALIZE(function(tbl)
	local new_tbl = {}

	for idx, value in next, tbl do
		new_tbl[idx] = value
	end

	return new_tbl
end)

local function patch_content_id_list(content_id_list)
	if typeof(content_id_list) ~= "table" then
		return error("list is not a table")
	end

	local core_gui_pos = table.find(content_id_list, core_gui)

	if not core_gui_pos then
		return error("no core-gui was found in this list")
	end

	local contend_id_list_clone = table_shallow_clone(content_id_list)
	contend_id_list_clone[core_gui_pos] = nil

	local add_core_gui_cache = LPH_NO_VIRTUALIZE(function()
		for _, instance in next, core_gui_instances_cache do
			table.insert(contend_id_list_clone, instance)
		end
	end)

	add_core_gui_cache()

	log_warn(
		"patch_content_id_list(content_id_list[%i]) -> replaced with core_gui_instances_cache[%i]",
		#content_id_list,
		#contend_id_list_clone,
		#core_gui_instances_cache
	)

	return contend_id_list_clone
end

local function patch_preload_async_args(args, content_id_list_pos)
	log_warn("patch_preload_async_args(args[%i] -> index[%i])", #args, content_id_list_pos, #args[content_id_list_pos])

	local content_id_list = args[content_id_list_pos]

	args[content_id_list_pos] = patch_content_id_list(content_id_list)
end

local function patch_is_a_ret(args, is_a_ret)
	local self = args[1]
	local class_name = args[2]

	if typeof(self) ~= "Instance" then
		return error("self is not an instance")
	end

	if typeof(class_name) ~= "string" then
		return error("class name is not an instance")
	end

	local stripped_class_name = string.gsub(class_name, "\0", "")

	if self.Name:sub(1, 2) ~= "FF" and stripped_class_name == "BodyMover" then
		return false
	end

	return is_a_ret
end

local function anticheat_caller(caller_script_info)
	local const_success, consts = pcall(debug.getconstants, caller_script_info.func)
	if not const_success or not consts then
		return false
	end

	local first_const = consts[1]
	if typeof(first_const) ~= "string" then
		return false
	end

	return first_const:match("_______________________________")
end

local any_anticheat_caller = LPH_NO_VIRTUALIZE(function()
	for idx = 1, math.huge do
		if not debug.isvalidlevel(idx) then
			break
		end

		local caller_script_info = debug.getinfo(idx)
		if not caller_script_info then
			break
		end

		if not anticheat_caller(caller_script_info) then
			continue
		end

		return true
	end
end)

local on_os_clock = LPH_NO_VIRTUALIZE(function(...)
	local os_clock_ret = orig_os_clock(...)

	if checkcaller() then
		return os_clock_ret
	end

	log_warn("on_os_clock(...) -> orig_cpu_time[%f] + cpu_offset[%f]", os_clock_ret, cpu_offset)

	return os_clock_ret + cpu_offset
end)

local patch_log_service_return = LPH_NO_VIRTUALIZE(function(log_service_ret)
	if typeof(log_service_ret) ~= "table" then
		return error("returned value is not a table")
	end

	local new_log_service_ret = {}
	local patched_log_history = false

	for _, log_service_entry in next, log_service_ret do
		local log_message = log_service_entry.message

		if not log_message then
			continue
		end

		local log_entry_ok = not log_message:find("Script ''", 2, true)
			and not log_message:find("\n, line", 1, true)
			and not log_message:find("Electron[,:]")
			and not log_message:find("Valyse[,:]")
			and not log_message:find('%[string "')
			and not log_message:find(":loadstring[,:]")

		if log_entry_ok then
			table.insert(new_log_service_ret, log_service_entry)
			continue
		end

		---@todo: more elegant solution? this can quickly keep going and going and lag the user.
		if not log_message:find("[ff2_hider]") then
			log_warn("patch_log_service_return(...) -> next -> filtered: log_service_ret[idx]")
			log_warn("log_entry_service.message -> %s", log_message)
		end

		patched_log_history = true
	end

	if #new_log_service_ret == 0 then
		return error("no valid log entries")
	end

	if not patched_log_history then
		return error("nothing to patch")
	end

	return new_log_service_ret
end)

local on_log_service = LPH_NO_VIRTUALIZE(function(...)
	local log_service_ret = orig_log_service(...)

	if checkcaller() then
		return log_service_ret
	end

	local patch_success, patch_result = pcall(patch_log_service_return, log_service_ret)

	log_warn("on_log_service(...) -> patch return result: (%s, %s)", tostring(patch_success), tostring(patch_result))

	if not patch_success then
		return log_service_ret
	else
		return patch_result
	end
end)

local on_preload_async = LPH_NO_VIRTUALIZE(function(...)
	if checkcaller() then
		return orig_preload_async(...)
	end

	local args = { ... }
	local patch_success, patch_result = pcall(patch_preload_async_args, args, 2)

	log_warn("on_preload_async(...) -> patch args result: (%s, %s)", tostring(patch_success), tostring(patch_result))

	if not patch_success then
		return orig_preload_async(...)
	else
		return orig_preload_async(table.unpack(args))
	end
end)

local on_game_namecall = LPH_NO_VIRTUALIZE(function(...)
	if checkcaller() then
		return orig_game_namecall(...)
	end

	local args = { ... }
	local self = args[1]

	if typeof(self) ~= "Instance" then
		return orig_game_namecall(...)
	end

	local method = getnamecallmethod()

	if
		self == run_service
		and (method == "bindToRenderStep" or method == "BindToRenderStep")
		and any_anticheat_caller()
		and typeof(args[2]) == "string"
	then
		return log_warn("on_game_namecall(...) -> method[%s] -> stop bind: %s", method, args[2])
	end

	if
		orig_is_a(self, "RemoteEvent")
		and (method == "fireServer" or method == "FireServer")
		and typeof(args[2]) == "string"
		and typeof(args[3]) == "string"
		and args[3]:match("catch")
	then
		is_catching = true

		log_warn("on_game_namecall(...) -> method[%s] -> is_catching[%s]", method, tostring(is_catching))

		return orig_game_namecall(...)
	end

	if self == content_provider and (method == "preloadAsync" or method == "PreloadAsync") then
		local patch_success, patch_result = pcall(patch_preload_async_args, args, 2)

		log_warn(
			"on_game_namecall(...) -> method[%s] -> patch args result: (%s, %s)",
			tostring(patch_success),
			method,
			tostring(patch_result)
		)

		if not patch_success then
			return orig_game_namecall(...)
		else
			return orig_game_namecall(table.unpack(args))
		end
	elseif self == log_service and (method == "GetLogHistory" or method == "getLogHistory") then
		local log_service_ret = orig_game_namecall(...)
		local patch_success, patch_result = pcall(patch_log_service_return, log_service_ret)

		log_warn(
			"on_game_namecall(...) -> method[%s] -> patch return result: (%s, %s)",
			tostring(patch_success),
			method,
			tostring(patch_result)
		)

		if not patch_success then
			return log_service_ret
		else
			return patch_result
		end
	elseif method == "IsA" or method == "isA" then
		local is_a_ret = orig_game_namecall(...)
		local patch_success, patch_result = pcall(patch_is_a_ret, args, is_a_ret)

		---@note: this spams.
		-- log_warn("on_game_namecall(...) -> method[%s] -> patch return result: (%s, %s)", tostring(patch_success), method, tostring(patch_result))

		if not patch_success then
			return is_a_ret
		else
			return patch_result
		end
	end

	return orig_game_namecall(...)
end)

---@possible_detection: is orig_game_newindex(...) detectable based on returning or not?
local on_game_newindex = LPH_NO_VIRTUALIZE(function(...)
	if checkcaller() then
		return orig_game_newindex(...)
	end

	local args = { ... }
	local self = args[1]
	local index = args[2]
	local new_value = args[3]

	if typeof(self) ~= "Instance" then
		return orig_game_newindex(...)
	end

	if typeof(index) ~= "string" then
		return orig_game_newindex(...)
	end

	local stripped_index = string.gsub(index, "\0", "")
	local property_reflection = reflection_map[self] or {}

	if not reflection_map[self] then
		reflection_map[self] = property_reflection
	end

	local numeric_change = typeof(new_value) == "number"
	local velocity_change = typeof(new_value) == "Vector3"

	local is_assembly_angular_velocity = (
		stripped_index == "AssemblyAngularVelocity" or stripped_index == "AssemblyAngularVelocity"
	)
	local is_walk_speed = (stripped_index == "WalkSpeed" or stripped_index == "walkSpeed")
	local is_jump_power = (stripped_index == "JumpPower" or stripped_index == "jumpPower")
	local is_assembly_linear_velocity = (
		stripped_index == "AssemblyLinearVelocity" or stripped_index == "assemblyLinearVelocity"
	)

	if numeric_change and is_walk_speed and sigma.speed then
		orig_game_newindex(self, index, new_value <= 0 and new_value or sigma.speed_amount)
	elseif numeric_change and is_jump_power and sigma.jump_power then
		orig_game_newindex(self, index, new_value <= 0 and new_value or sigma.jump_power_amount)
	elseif velocity_change and is_assembly_linear_velocity then
		if sigma.jump_power and sigma.jump_power_amount > 50 then
			log_warn("on_game_newindex(...) -> force-denied velocity change: %s", tostring(new_value))
		elseif (sigma.jump_power and sigma.jump_power_amount <= 50) or sigma.boost_on_height then
			args[3] = self[index] * sigma.boost_amount or 1.1
			log_warn(
				"on_game_newindex(...) -> negated change & boosted old velocity: %s -> %s",
				tostring(new_value),
				tostring(args[3])
			)
			orig_game_newindex(unpack(args))
		else
			log_warn("on_game_newindex(...) -> allowed velocity change: %s", tostring(new_value))
			orig_game_newindex(...)
		end
	elseif velocity_change and is_assembly_angular_velocity then
		log_warn("on_game_newindex(...) -> allowed angular velocity change: %s", tostring(new_value))
		orig_game_newindex(...)
	else
		orig_game_newindex(...)
	end

	if numeric_change and is_walk_speed then
		new_value = math.max(new_value, 0.0)
	end

	property_reflection[stripped_index] = new_value
end)

local on_is_a = LPH_NO_VIRTUALIZE(function(...)
	local is_a_ret = orig_is_a(...)

	if checkcaller() then
		return is_a_ret
	end

	local args = { ... }
	local patch_success, patch_result = pcall(patch_is_a_ret, args, is_a_ret)

	---@note: this spams.
	-- log_warn("orig_is_a(...) -> patch return result: (%s, %s)", tostring(patch_success), tostring(patch_result))

	if not patch_success then
		return is_a_ret
	else
		return patch_result
	end
end)

---@todo: add this to namecall aswell.
local on_get_property_changed_signal = LPH_NO_VIRTUALIZE(function(...)
	if checkcaller() then
		return orig_get_property_changed_signal(...)
	end

	local args = { ... }
	local self = args[1]
	local property = args[2]

	if typeof(self) ~= "Instance" then
		return orig_get_property_changed_signal(...)
	end

	if typeof(property) ~= "string" then
		return orig_get_property_changed_signal(...)
	end

	---@todo: de-duplicate this code.

	if orig_is_a(self, "Workspace") then
		log_warn(
			"on_get_property_changed_signal(...) -> self[%s] -> property[%s] -> fake_signal[%s]",
			tostring(self),
			property,
			tostring(fake_signal)
		)

		return fake_signal
	end

	if self.Name == "HumanoidRootPart" and orig_is_a(self, "Part") then
		log_warn(
			"on_get_property_changed_signal(...) -> self[%s] -> property[%s] -> fake_signal[%s]",
			tostring(self),
			property,
			tostring(fake_signal)
		)

		return fake_signal
	end

	local is_catch_part = self.Name:sub(1, 5) == "Catch"
	local is_block_part = self.Name:sub(1, 6) == "BlockP"

	if (self.Name == "Football" or is_catch_part or is_block_part) and orig_is_a(self, "BasePart") then
		log_warn(
			"on_get_property_changed_signal(...) -> self[%s] -> property[%s] -> fake_signal[%s]",
			tostring(self),
			property,
			tostring(fake_signal)
		)

		return fake_signal
	end

	log_warn(
		"on_get_property_changed_signal(...) -> self[%s] -> property[%s] -> orig_get_property_changed_signal(...)",
		tostring(self),
		property
	)

	return orig_get_property_changed_signal(...)
end)

local on_game_index = LPH_NO_VIRTUALIZE(function(...)
	if checkcaller() then
		return orig_game_index(...)
	end

	local args = { ... }
	local self = args[1]
	local index = args[2]

	if typeof(self) ~= "Instance" then
		return orig_game_index(...)
	end

	if typeof(index) ~= "string" then
		return orig_game_index(...)
	end

	local stripped_index = string.gsub(index, "\0", "")

	---@todo: de-duplicate this code.

	if self == script_context and stripped_index == "Error" then
		log_warn(
			"on_game_index(...) -> self[%s] -> index[%s] -> fake_signal[%s]",
			tostring(self),
			stripped_index,
			tostring(fake_signal)
		)

		return fake_signal
	end

	if self == run_service and stripped_index == "Heartbeat" and any_anticheat_caller() then
		log_warn(
			"on_game_index(...) -> self[%s] -> index[%s] -> fake_signal[%s]",
			tostring(self),
			stripped_index,
			tostring(fake_signal)
		)

		return fake_signal
	end

	if self == http_service and (stripped_index == "RequestInternal" or stripped_index == "requestInternal") then
		log_warn(
			"on_game_index(...) -> self[%s] -> index[%s] -> fake_request_internal[%s]",
			tostring(self),
			stripped_index,
			tostring(fake_request_internal)
		)

		return fake_request_internal
	end

	local should_spoof_ret = false

	if orig_is_a(self, "Camera") and (stripped_index == "FieldOfView" or stripped_index == "fieldOfView") then
		should_spoof_ret = true
	end

	if orig_is_a(self, "Workspace") and (stripped_index == "Gravity" or stripped_index == "gravity") then
		should_spoof_ret = true
	end

	if
		orig_is_a(self, "Part")
		and (
			stripped_index == "Size"
			or stripped_index == "size"
			or stripped_index == "CanCollide"
			or stripped_index == "canCollide"
		)
	then
		should_spoof_ret = true
	end

	if orig_is_a(self, "Humanoid") and (stripped_index ~= "MoveDirection") then
		should_spoof_ret = true
	end

	local reflections = reflection_map[self]
	local reflection = reflections and reflections[stripped_index] or nil

	---@todo: logging without spamming
	if should_spoof_ret and reflection then
		return reflection
	end

	local default_indexes = default_index_map[self] or {}

	if not default_index_map[self] then
		default_index_map[self] = {}
	end

	---@possible_detection: can orig_game_index(...) return multiple values?
	---@todo: logging without spamming
	if should_spoof_ret then
		local default_index = default_indexes[stripped_index] or orig_game_index(...)

		if not default_indexes[stripped_index] then
			default_indexes[stripped_index] = default_index
		end

		-- sanity checks - cap default index so we don't get banned from the game lol.
		if stripped_index == "WalkSpeed" or stripped_index == "walkSpeed" then
			default_index = math.min(default_index, default_walkspeed)
		end

		if stripped_index == "JumpPower" or stripped_index == "jumpPower" then
			default_index = math.min(default_index, default_jump_power)
		end

		if stripped_index == "HipHeight" or stripped_index == "hipHeight" then
			default_index = math.min(default_index, 0.0)
		end

		local name = orig_game_index(self, "Name")

		if stripped_index == "Size" or stripped_index == "size" then
			if name:sub(1, 5) == "Catch" then
				default_index = Vector3.new(
					math.min(default_index.X, 1.4),
					math.min(default_index.Y, 1.65),
					math.min(default_index.Z, 1.4)
				)
			end

			if name == "BlockPart" then
				default_index = Vector3.new(
					math.min(default_index.X, 0.75),
					math.min(default_index.Y, 5),
					math.min(default_index.Z, 1.5)
				)
			end
		end

		return default_index
	end

	return orig_game_index(...)
end)

local on_catch_touch = LPH_NO_VIRTUALIZE(function(toucher, touching, state)
	local transmitter = touching:FindFirstChildWhichIsA("TouchTransmitter")
	if not transmitter then
		log_warn("on_catch_touch(...) -> no touch transmiter to replicate to.")
		return
	end

	if not firetouchinterest then
		log_warn("on_catch_touch(...) -> no firetouchinterest. no replication to server with increased size!")
		return
	end

	if getexecutorname():match("Wave") then
		log_warn(
			"on_catch_touch(...) -> method['0'] -> succesfully replicated touch state %s to server.",
			tostring(state)
		)
		return firetouchinterest(toucher, touching, state)
	end

	local replicate_success, _ = pcall(firetouchinterest, toucher, transmitter, state)

	if replicate_success then
		log_warn(
			"on_catch_touch(...) -> method[1] -> succesfully replicated touch state %s to server.",
			tostring(state)
		)
		return
	end

	local alt_replicate_success, _ = pcall(firetouchinterest, transmitter, touching, state)

	if alt_replicate_success then
		log_warn(
			"on_catch_touch(...) -> method[2] -> succesfully replicated touch state %s to server.",
			tostring(state)
		)
		return
	end

	local fallback_replicate_success, _ = pcall(firetouchinterest, touching, toucher, state)
	local alt_fallback_replicate_success, _ = pcall(firetouchinterest, toucher, touching, state)

	if fallback_replicate_success or alt_fallback_replicate_success then
		log_warn(
			"on_catch_touch(...) -> method[3] -> succesfully replicated touch state %s to server.",
			tostring(state)
		)
		return
	end
end)

local get_nearest_football_data = LPH_NO_VIRTUALIZE(function()
	local nearest_inst = nil
	local nearest_vis_inst = nil
	local nearest_distance = nil

	for index, football_part_data in next, football_parts_data do
		local inst, vis_inst = football_part_data.inst, football_part_data.vis_inst
		if not inst or not vis_inst then
			continue
		end

		if inst.Parent ~= workspace then
			table.remove(football_parts_data, index)
			continue
		end

		local local_player = players.LocalPlayer
		if not local_player then
			continue
		end

		local character = local_player.Character
		if not character then
			continue
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local distance = (inst.Position - hrp.Position).Magnitude

		if not nearest_distance or distance < nearest_distance then
			nearest_distance = distance
			nearest_inst = inst
			nearest_vis_inst = vis_inst
		end
	end

	return nearest_inst, nearest_vis_inst, nearest_distance
end)

local on_update_sigma = LPH_NO_VIRTUALIZE(function()
	local local_player = players.LocalPlayer
	if not local_player then
		return
	end

	local character = local_player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	if sigma.speed and humanoid.WalkSpeed > 0 and humanoid.WalkSpeed ~= sigma.speed_amount then
		humanoid.WalkSpeed = sigma.speed_amount
	end

	if sigma.jump_power and humanoid.JumpPower > 0 and humanoid.JumpPower ~= sigma.jump_power_amount then
		humanoid.JumpPower = sigma.jump_power_amount
	end

	-- Hide all visual instances.
	for _, football_part_data in next, football_parts_data do
		local vis_inst = football_part_data.vis_inst
		if not vis_inst then
			continue
		end

		vis_inst.Transparency = 1.0
	end

	-- Update through all catch parts.
	for _, catch_part_data in next, catch_parts_data do
		local inst = catch_part_data.inst
		if not inst then
			continue
		end

		if sigma["reduce_catch_tackle"] and character:FindFirstChild("Football") then
			inst.Size = Vector3.new(0.01, 0.01, 0.01)
		else
			inst.Size = catch_part_data.original_size
		end
	end

	-- Update football extended catching.
	local nearest_fb, nearest_vis_inst, nearest_distance = get_nearest_football_data()
	if not nearest_fb or not nearest_vis_inst or not nearest_distance then
		return
	end

	if not nearest_fb:FindFirstChildWhichIsA("TouchTransmitter") then
		return
	end

	if nearest_fb.Position.Y <= 3.5 then
		return
	end

	nearest_vis_inst.Size = nearest_fb.Size + sigma.increase_catch_size
	nearest_vis_inst.Transparency = sigma.visualize_catch_zone and 0.3 or 1.0
	nearest_vis_inst.Color = BrickColor.DarkGray().Color
	nearest_vis_inst.Position = nearest_fb.Position
	nearest_vis_inst.Material = Enum.Material.SmoothPlastic
	nearest_vis_inst.Anchored = true
	nearest_vis_inst.CanCollide = false

	local overlap_params = OverlapParams.new()
	overlap_params.FilterType = Enum.RaycastFilterType.Include
	overlap_params.FilterDescendantsInstances = { character }

	local parts = workspace:GetPartsInPart(nearest_vis_inst, overlap_params)
	if not is_catching or #parts <= 0 then
		return
	end

	for _, part in next, parts do
		on_catch_touch(part, nearest_fb, true)

		log_warn(
			"nearest_football[%s] -> %.2f studs away -> touched with %s",
			nearest_fb.Name,
			nearest_distance,
			part.Name
		)

		on_catch_touch(part, nearest_fb, false)
	end
end)

local on_workspace_child_added_sigma = LPH_NO_VIRTUALIZE(function(inst)
	if not inst:IsA("BasePart") then
		return
	end

	if inst.Name ~= "Football" then
		return
	end

	log_warn("on_workspace_child_added_sigma(inst) -> %s[%s]", tostring(inst.Name), tostring(inst.Size))
	football_parts_data[#football_parts_data + 1] = { inst = inst, vis_inst = Instance.new("Part", inst) }
end)

local on_workspace_descendant_added_sigma = LPH_NO_VIRTUALIZE(function(inst)
	if not inst:IsA("BasePart") then
		return
	end

	if not players.LocalPlayer or players.LocalPlayer.Character ~= inst.Parent then
		return
	end

	if inst.Name:sub(1, 5) == "Catch" then
		log_warn("on_workspace_descendant_added_sigma(inst) -> %s[%s]", tostring(inst.Name), tostring(inst.Size))
		catch_parts_data[#catch_parts_data + 1] = { original_size = inst.Size, inst = inst }
	end
end)

local on_debug_info = LPH_NO_VIRTUALIZE(function(...)
	local args = { ... }
	local info_ret = orig_debug_info(...)
	local checking_function = args[1] == 2 and args[2] == "f"

	if not checking_function and not any_anticheat_caller() then
		return info_ret
	end

	log_warn(
		"on_debug_info(...) -> info_ret[%s] -> cached_namecall_function[%s]",
		tostring(info_ret),
		tostring(cached_namecall_function)
	)

	return cached_namecall_function
end)

for _, connection in next, getconnections(script_context.Error) do
	local disable_success, disable_result = pcall(connection.Disable, connection)

	if disable_success then
		log_warn("getconnections(script_context.Error) -> next -> disabled: connection[%s]", tostring(connection))
	else
		log_warn("getconnections(script_context.Error) -> next -> failed: disable_result[%s]", tostring(disable_result))
	end
end

orig_debug_info = hookfunction(debug.info, newcclosure(on_debug_info))
orig_os_clock = hookfunction(os.clock, newcclosure(on_os_clock))
orig_is_a = hookfunction(is_a, newcclosure(on_is_a))
orig_get_property_changed_signal =
	hookfunction(game.GetPropertyChangedSignal, newcclosure(on_get_property_changed_signal))
orig_preload_async = hookfunction(content_provider.PreloadAsync, newcclosure(on_preload_async))
orig_log_service = hookfunction(log_service.GetLogHistory, newcclosure(on_log_service))
orig_game_namecall = hookmetamethod(game, "__namecall", newcclosure(on_game_namecall))
orig_game_index = hookmetamethod(game, "__index", newcclosure(on_game_index))
orig_game_newindex = hookmetamethod(game, "__newindex", newcclosure(on_game_newindex))

log_warn("placed hooks successfully")

workspace.DescendantAdded:Connect(on_workspace_descendant_added_sigma)
workspace.ChildAdded:Connect(on_workspace_child_added_sigma)
run_service.PreSimulation:Connect(on_update_sigma)

for _, inst in next, workspace:GetDescendants() do
	on_workspace_descendant_added_sigma(inst)
end

repeat
	task.wait()
until players.LocalPlayer

local local_player = players.LocalPlayer
local player_scripts = local_player.PlayerScripts
local client_main = player_scripts:WaitForChild("ClientMain")
local catch_controls_module =
	require(client_main:FindFirstChild("GameControls") or client_main:FindFirstChild("OtherControls"))

orig_catch = hookfunction(
	catch_controls_module.Catch,
	LPH_NO_VIRTUALIZE(function(...)
		---@todo: i am lazy.
		local timestamp = os.clock()

		orig_catch(...)

		if os.clock() - timestamp > 0.1 then
			is_catching = false
		end

		log_warn("on_catch(...) -> is_catching[%s]", tostring(is_catching))
	end)
)

log_warn("loaded gta 5 cheat codes successfully")

local place_failsafe_func = LPH_NO_VIRTUALIZE(function()
	for _, value in next, getgc(true) do
		if typeof(value) ~= "table" then
			continue
		end

		local metatable = getrawmetatable(value)
		if not metatable or not metatable.__call then
			continue
		end

		-- Remove __tostring metamethod to prevent detection.
		metatable.__tostring = nil

		-- Log hook.
		log_warn("hooked metatable[%s].__call", tostring(metatable))

		-- Place hook to sniff out and thwart any attempts to detect us. No upvalues.
		local old = nil
		old = hookfunction(metatable.__call, function(...)
			local arguments = { ... }

			-- On detection.
			local function on_detection(code)
				warn(string.format("[%i] metatable.__call -> attempted to detect us", code))

				for idx, val in next, debug.getstack(3) do
					if typeof(val) == "userdata" or typeof(val) == "table" then
						continue
					end

					warn(string.format("[%s] stack -> %s", tostring(idx), tostring(val)))
				end
			end

			-- Check one.
			if arguments[2] == 760 and arguments[3] == 759 then
				return on_detection(1)
			end

			-- Check two.
			if arguments[2] == 798 and arguments[3] == 711 then
				return on_detection(2)
			end

			return old(...)
		end)
	end
end)

place_failsafe_func()

log_warn("placed failsafe")

---! Boring library - actual cheat part stuff.
-- snake_case -> PascalCase transition here, who cares.

local Library = loadstring(
	game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau", true)
)()

local SaveManager = loadstring(
	game:HttpGetAsync(
		"https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"
	)
)()

local InterfaceManager = loadstring(
	game:HttpGetAsync(
		"https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"
	)
)()

-- Window.
local Window = Library:CreateWindow({
	Title = `Sigma Open Sourced (and Full AC Bypass)`,
	SubTitle = `Powered by Fluent {Library.Version} - created by @Blastbrean`,
	TabWidth = 160,
	Size = UDim2.fromOffset(830, 525),
	Resize = true,
	MinSize = Vector2.new(470, 380),
	Acrylic = true,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.RightControl,
})

-- Game tab.
local GameTab = Window:CreateTab({
	Title = "Game",
	Icon = "phosphor-users-bold",
})

GameTab:CreateToggle("Speed", {
	Title = "Enable Speedhack",
	Enabled = false,
	Callback = function(Value)
		sigma["speed"] = Value
	end,
})

GameTab:CreateSlider("SpeedAmount", {
	Title = "Speedhack Amount",
	Description = "How fast in studs do you want to move?",
	Default = 21,
	Min = 1,
	Max = 240,
	Rounding = 1,
	Callback = function(Value)
		sigma["speed_amount"] = Value
	end,
})

GameTab:CreateToggle("JumpPower", {
	Title = "Enable Jump Power",
	Enabled = false,
	Callback = function(Value)
		sigma["jump_power"] = Value
	end,
})

GameTab:CreateSlider("JumpPowerAmount", {
	Title = "Jump Power Amount",
	Description = "How high in studs do you want to jump?",
	Default = 55,
	Min = 1,
	Max = 240,
	Rounding = 1,
	Callback = function(Value)
		sigma["jump_power_amount"] = Value
	end,
})

GameTab:CreateToggle("BoostOnHeight", {
	Title = "Boost On Height",
	Enabled = false,
	Callback = function(Value)
		sigma["boost_on_height"] = Value
	end,
})

GameTab:CreateSlider("BoostAmount", {
	Title = "Boost Amount",
	Description = "How much do you want to boost?",
	Default = 1.15,
	Min = 1,
	Max = 10,
	Rounding = 2,
	Callback = function(Value)
		sigma["boost_amount"] = Value
	end,
})

GameTab:CreateInput("FPSCap", {
	Title = "FPS Cap",
	Description = "Set the FPS cap. Setting this to zero is unlimited.",
	Default = 0,
	Min = 0,
	Max = 540,
	Numeric = true,
	Finished = true,
	Callback = function(Value)
		setfpscap(Value)
	end,
})

-- Catching tab.
local CatchingTab = Window:CreateTab({
	Title = "Catching",
	Icon = "phosphor-hand-arrow-down",
})

CatchingTab:CreateToggle("ReduceCatchTackle", {
	Title = "Reduce Catch Tackle",
	Enabled = false,
	Callback = function(Value)
		sigma["reduce_catch_tackle"] = Value
	end,
})

CatchingTab:CreateSlider("IncreaseCatchSizeX", {
	Title = "Increase Catch Size X",
	Description = "How much do you want to increase the catch size on the X axis?",
	Default = 6.5,
	Min = 0,
	Max = 45,
	Rounding = 2,
	Callback = function(Value)
		sigma["increase_catch_size"] =
			Vector3.new(Value, sigma["increase_catch_size"].Y, sigma["increase_catch_size"].Z)
	end,
})

CatchingTab:CreateSlider("IncreaseCatchSizeY", {
	Title = "Increase Catch Size Y",
	Description = "How much do you want to increase the catch size on the Y axis?",
	Default = 4.5,
	Min = 0,
	Max = 45,
	Rounding = 2,
	Callback = function(Value)
		sigma["increase_catch_size"] =
			Vector3.new(sigma["increase_catch_size"].X, Value, sigma["increase_catch_size"].Z)
	end,
})

CatchingTab:CreateSlider("IncreaseCatchSizeZ", {
	Title = "Increase Catch Size Z",
	Description = "How much do you want to increase the catch size on the Z axis?",
	Default = 6.5,
	Min = 0,
	Max = 45,
	Rounding = 2,
	Callback = function(Value)
		sigma["increase_catch_size"] =
			Vector3.new(sigma["increase_catch_size"].X, sigma["increase_catch_size"].Y, Value)
	end,
})

-- Visuals tab.
local VisualsTab = Window:CreateTab({
	Title = "Visuals",
	Icon = "phosphor-eye",
})

VisualsTab:CreateToggle("VisualizeCatchZone", {
	Title = "Visualize Catch Zone",
	Enabled = false,
	Callback = function(Value)
		sigma["visualize_catch_zone"] = Value
	end,
})

VisualsTab:CreateSlider("FieldOfView", {
	Title = "Field Of View",
	Description = "Set the field of view.",
	Default = 120,
	Min = 1,
	Max = 240,
	Rounding = 1,
	Callback = function(Value)
		workspace.CurrentCamera.FieldOfView = Value
	end,
})

-- Settings tab.
local SettingsTab = Window:CreateTab({
	Title = "Settings",
	Icon = "settings",
})

-- Interface manager.
InterfaceManager:SetLibrary(Library)
InterfaceManager:SetFolder("FF2Hider/Interface")
InterfaceManager:BuildInterfaceSection(SettingsTab)

-- Save manager.
SaveManager:SetFolder("FF2Hider/Save")
SaveManager:SetLibrary(Library)
SaveManager:SetIgnoreIndexes({})
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(SettingsTab)
SaveManager:LoadAutoloadConfig()

-- Select tab.
Window:SelectTab(1)

-- Loaded library.
log_warn("loaded library successfully")
