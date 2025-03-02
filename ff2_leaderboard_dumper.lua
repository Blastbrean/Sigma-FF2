local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local statsTransfer = replicatedStorage:WaitForChild("Remotes"):WaitForChild("StatsTransfer")
local statsData, _ = statsTransfer:invokeServer("global", "all")

if typeof(statsData) ~= "table" then
	return error("failed to fetch statsData!")
else
	warn("[ff2_global_dumper] fetched data successfully")
end

local globalIdsString = nil
local globalIdsCounter = 0

local function getIdFromName(name)
	local userIdSuccess, userIdResult = nil, nil

	while true do
		userIdSuccess, userIdResult = pcall(players.GetUserIdFromNameAsync, players, name)

		local userIdThrottled = typeof(userIdResult) == "string" and userIdResult:match("throttled")
		if not userIdThrottled then
			break
		end

		warn("[ff2_global_dumper] throttled! waiting 10 seconds...")

		task.wait(10)
	end

	if not userIdSuccess then
		return warn("[ff2_global_dumper] failed to fetch userid from name", name)
	end

	return userIdResult
end

for footballPosition, globals in next, statsData do
	warn(string.format("[ff2_global_dumper] dumping position %s with %i globals", footballPosition, #globals))

	for leaderboardPosition, global in next, globals do
		local other = global.other

		if not other then
			warn("[ff2_global_dumper] dumping user skipped, no other table.")
			continue
		end

		if typeof(other.name) ~= "string" then
			warn("[ff2_global_dumper] dumping user skipped, invalid name found.")
			continue
		end

		warn(
			string.format(
				"[ff2_global_dumper] dumping global %s who is #%i at being a %s",
				other.name,
				leaderboardPosition,
				footballPosition
			)
		)

		local userId = getIdFromName(other.name)

		if not userId then
			warn("[ff2_global_dumper] null userid", other.name)
			continue
		end

		if not globalIdsString then
			globalIdsString = userId
		else
			globalIdsString = globalIdsString .. " " .. userId
		end

		globalIdsCounter = globalIdsCounter + 1

		-- no more than 250 objects in 60 seconds.
		task.wait(0.4)
	end
end

if not globalIdsString then
	return warn("[ff2_global_dumper] no stream-snipe id list")
end

warn(string.format("[ff2_global_dumper] wrote stream-sniper id list (%i) to file", globalIdsCounter))

writefile("stream_snipe_ids.txt", globalIdsString)
