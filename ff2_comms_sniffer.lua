for i,v in next, getgc(true) do
    if typeof(v) ~= "table" then continue end
    if not getrawmetatable(v) then continue end
    if not getrawmetatable(v).__call then continue end
    getrawmetatable(v).__tostring = nil
end

for i,v in next, getgc(true) do
    if typeof(v) ~= "table" then continue end
    if not getrawmetatable(v) then continue end
    if not getrawmetatable(v).__call then continue end
    local old; old = hookfunction(getrawmetatable(v).__call, function(...)
        print(...)
        return old(...)
    end)
end