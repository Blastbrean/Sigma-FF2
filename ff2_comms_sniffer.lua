local old
old = hookfunction(string.reverse, function(...)
	local args = { ... }
	if #args[1] > 3 then
		if args[1]:gsub("\0", "") ~= old("BodyMover") then
			print("reverse", args[1]:gsub("\0", ""))
		end
	end
	return old(...)
end)
local old2
old2 = hookfunction(string.find, function(...)
	local args = { ... }
	args[1] = nil
	print("find", table.unpack(args))
	return old2(...)
end)
task.wait(2)
print("placed")
for i, v in next, getgc(true) do
	if typeof(v) ~= "table" then
		continue
	end
	if not getrawmetatable(v) then
		continue
	end
	if not getrawmetatable(v).__call then
		continue
	end
	getrawmetatable(v).__tostring = nil
end

for i, v in next, getgc(true) do
	if typeof(v) ~= "table" then
		continue
	end
	if not getrawmetatable(v) then
		continue
	end
	if not getrawmetatable(v).__call then
		continue
	end
	local old
	old = hookfunction(getrawmetatable(v).__call, function(...)
		print(...)
		return old(...)
	end)
end
