--!strict
-- Short number text for the UI: 950, 12.5K, 3.4M, 1.2B and so on.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = (string.gsub(text, "0+$", ""))
		text = (string.gsub(text, "%.$", ""))
	end
	return text
end

function Format.number(n: number): string
	if n ~= n or n == math.huge then
		return "∞"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		-- Small numbers keep one decimal, so rates like 1.6/s read right.
		return sign .. trimZeros(string.format("%.1f", math.floor(n * 10) / 10))
	end
	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	local digits = if n < 10 then "%.2f" elseif n < 100 then "%.1f" else "%.0f"
	if tonumber(string.format(digits, n)) :: number >= 1000 and index < #SUFFIXES then
		-- 999,999 rounds up to 1M, not 1000K.
		n /= 1000
		index += 1
		digits = "%.2f"
	end
	return sign .. trimZeros(string.format(digits, n)) .. SUFFIXES[index]
end

-- Whole coins, e.g. "12.5K".
function Format.coins(n: number): string
	return Format.number(math.floor(n))
end

return Format
