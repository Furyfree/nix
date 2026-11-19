-- Fastfetch's shared Lua state: native collectors stay silent; fixed rows below
-- keep the palette aligned with the hat even when hardware is unavailable. Only
-- the DE row drops out, on systems without a desktop environment.
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

function ff.osName()
  local info = ff.os
  if not info then return nil end
  if info.versionId and info.versionId ~= '' then return info.name .. ' ' .. info.versionId end
  -- Windows has no version ID; its version and release, such as 11 26H2.
  return (info.name .. ' ' .. (info.version or '') .. ' ' .. (info.codename or '')):gsub('%s+$', '')
end

-- Whole days from 1970-01-01 to a calendar date (days_from_civil).
local function daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = y // 400
  local yoe = y - era * 400
  local doy = (153 * (m > 2 and m - 3 or m + 9) + 2) // 5 + d - 1
  return era * 146097 + yoe * 365 + yoe // 4 - yoe // 100 + doy - 719468
end

-- ff.sh counts the days on NixOS, Ubuntu and macOS. Windows keeps no install
-- date fastfetch reads, but Setup formats the system volume, so its creation
-- date stands in.
function ff.ageText()
  local days = ff.ageDays
  if not days and ff.os and ff.os.name == 'Windows' and ff.disk and ff.disk.createTime and ff.now then
    local y, m, d = ff.disk.createTime:match('^(%d+)-(%d+)-(%d+)')
    if y then
      days = daysFromCivil(tonumber(ff.now.year), tonumber(ff.now.month), tonumber(ff.now.dayInMonth))
        - daysFromCivil(tonumber(y), tonumber(m), tonumber(d))
    end
  end
  if not days or days < 0 then return 'not recorded' end
  if days == 0 then return '<1 day (estimate)' end
  if days == 1 then return '~1 day' end
  return '~' .. days .. ' days'
end

-- Nothing on Windows and macOS, which have no desktop environment to name; the
-- row then disappears.
function ff.deText()
  local de = ff.name(ff.de) or ff.noctalia
  if de then return ff.text(de) end
end

function ff.cpuName()
  if not ff.cpu then return nil end
  return ff.cpu.name:gsub('%d+th Gen ', ''):gsub('%(R%)', ''):gsub('%(TM%)', '')
end

function ff.gpuNames()
  local names = {}
  for _, gpu in ipairs(ff.gpus) do
    -- Windows names the Intel GPU "Intel(R) UHD Graphics 770", Linux "UHD Graphics 770".
    local name = gpu.name:gsub('GeForce ', ''):gsub(' Lite Hash Rate', ''):gsub('%(R%)', ''):gsub('^Intel%s+', '')
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
                         {'apk', 'apk'}, {'flatpakAll', 'flatpak'}, {'nixAll', 'nix'},
                         {'brew', 'brew'}, {'brewCask', 'cask'}, {'winget', 'winget'}}) do
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
