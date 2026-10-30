-- Lune port of upload.py, for machines without Python: uploads the files in a manifest through Open Cloud.
-- Resumable: results are kept in the results file and done entries are skipped.
--   ROBLOX_API_KEY must be set (never printed). ROBLOX_USER_ID defaults to the Oathbound account.
--   lune run tools/reupload/upload.luau <manifest.json> <results.json>
-- Each manifest entry: { file, display, type?, ctype?, desc? }; `file` is relative to the manifest's folder.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local KEY = process.env.ROBLOX_API_KEY
assert(KEY and #KEY > 0, "ROBLOX_API_KEY is not set")
local USER_ID = process.env.ROBLOX_USER_ID or "102707091"
local BASE = "https://apis.roblox.com/assets/v1/"

local manifestPath, resultsPath = process.args[1], process.args[2]
local folder = string.match(manifestPath, "^(.*)[/\\]") or "."

local function request(url: string, method: string, body: string?, contentType: string?)
	local headers = { ["x-api-key"] = KEY }
	if contentType then
		headers["Content-Type"] = contentType
	end
	local response = net.request({ url = url, method = method, headers = headers, body = body })
	local ok, decoded = pcall(serde.decode, "json", response.body)
	return response.statusCode, if ok then decoded else { error = string.sub(response.body, 1, 300) }
end

local function create(entry)
	local boundary = "oathbound" .. tostring(math.random(1e9))
	local meta = serde.encode("json", {
		assetType = entry.type or "Animation",
		displayName = string.sub(entry.display, 1, 50),
		description = entry.desc or "Oathbound prototype",
		creationContext = { creator = { userId = USER_ID } },
	})
	local file = fs.readFile(folder .. "/" .. entry.file)
	local body = "--" .. boundary .. "\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n" .. meta .. "\r\n"
		.. "--" .. boundary .. "\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"" .. entry.file .. "\"\r\n"
		.. "Content-Type: " .. (entry.ctype or "model/x-rbxm") .. "\r\n\r\n" .. file .. "\r\n--" .. boundary .. "--\r\n"
	local status, js
	for attempt = 1, 5 do
		status, js = request(BASE .. "assets", "POST", body, "multipart/form-data; boundary=" .. boundary)
		if status ~= 429 and status < 500 then
			break
		end
		task.wait(2 ^ (attempt + 1))
	end
	if status ~= 200 then
		return { status = status, error = js.error or js.message }
	end
	local op = js.path or js.operationId
	for _ = 1, 60 do
		if js.done then
			break
		end
		task.wait(2)
		status, js = request(BASE .. (if string.find(op, "^operations/") then op else "operations/" .. op), "GET")
	end
	return js
end

local manifest = serde.decode("json", fs.readFile(manifestPath))
local results = if fs.isFile(resultsPath) then serde.decode("json", fs.readFile(resultsPath)) else {}
for _, entry in manifest do
	local done = results[entry.file]
	if not (done and done.assetId) then
		local js = create(entry)
		local assetId = js.response and js.response.assetId
		results[entry.file] = { assetId = assetId, error = if assetId then nil else (js.error or js.status or "no asset id") }
		print(entry.display, "->", assetId or ("FAILED " .. tostring(results[entry.file].error)))
		fs.writeFile(resultsPath, serde.encode("json", results, true))
		task.wait(1)
	end
end
