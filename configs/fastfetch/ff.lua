-- Fastfetch's shared Lua state: native collectors stay silent; fixed rows below
-- keep the palette aligned with the hat even when hardware is unavailable.
ff = {gpus = {}, displays = {}}

function ff.text(value)
  if value == nil or value == '' then return 'not detected' end
  local text = tostring(value):gsub('[%c]', ' ')
  local chars = {}
  for char in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
    chars[#chars + 1] = char
  end
  if #chars > 46 then
    return table.concat(chars, '', 1, 45) .. '…'
  end
  return text
end

function ff.name(value)
  if not value then return nil end
  return ((value.prettyName or value.name or '') .. ' ' .. (value.version or '')):gsub('%s+$', '')
end

function ff.cpuName()
  if not ff.cpu then return nil end
  return ff.cpu.name:gsub('%d+th Gen ', ''):gsub('%(R%)', ''):gsub('%(TM%)', '')
end

function ff.gpuNames()
  local names = {}
  for _, gpu in ipairs(ff.gpus) do
    local name = gpu.name:gsub('GeForce ', ''):gsub(' Lite Hash Rate', '')
    if gpu.vendor == 'Intel' then name = name:gsub('UHD Graphics ', 'Intel UHD ') end
    names[#names + 1] = name
  end
  return table.concat(names, ' + ')
end

function ff.displayNames()
  local order, counts = {}, {}
  for _, display in ipairs(ff.displays) do
    local hz = tonumber(display.refreshRate)
    local name = string.format('%d×%d', display.width, display.height)
    if hz then name = name .. string.format(' @ %g Hz', math.floor(hz * 10 + 0.5) / 10) end
    if not counts[name] then order[#order + 1] = name; counts[name] = 0 end
    counts[name] = counts[name] + 1
  end
  for i, name in ipairs(order) do
    if counts[name] > 1 then order[i] = counts[name] .. ' × ' .. name end
  end
  return table.concat(order, ' + ')
end

function ff.packageCounts()
  if not ff.packages then return nil end
  local rows, counted = {}, 0
  for _, item in ipairs({ {'rpm', 'rpm'}, {'dpkg', 'dpkg'}, {'pacman', 'pacman'},
                         {'apk', 'apk'}, {'flatpakAll', 'flatpak'}, {'nixAll', 'nix'}}) do
    local count = ff.packages[item[1]] or 0
    -- Flatpak's total includes runtimes; show installed apps when counted.
    local shown = item[1] == 'flatpakAll' and ff.flatpakApps or count
    if count > 0 then rows[#rows + 1] = shown .. ' ' .. item[2]; counted = counted + count end
  end
  local other = (ff.packages.all or 0) - counted
  if other > 0 then rows[#rows + 1] = other .. ' other' end
  return #rows > 0 and table.concat(rows, ' · ') or '0'
end

function ff.uptimeText()
  if not ff.uptime then return nil end
  local a = ff.uptime
  return (a.days > 0 and a.days .. 'd ' or '') .. a.hours .. 'h ' .. a.minutes .. 'm'
end

function ff.usage(value)
  if not value then return nil end
  return (value.used or value.sizeUsed) .. ' / ' .. (value.total or value.sizeTotal)
end
