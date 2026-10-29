-- Test runner for the pure shared modules, run outside Roblox with Lune:
--   lune run tests/run
-- Shared modules use Roblox-style requires (require(script.Parent.X)). This runner fakes `script`
-- so the same files load from disk unchanged.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = "src/shared"

local cache = {}
local makeNode

local function loadModule(path: string, scriptNode)
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = fs.readFile(path)
	local chunk = luau.load(source, {
		debugName = path,
		environment = {
			script = scriptNode,
			require = function(target)
				if type(target) == "table" and target.__isNode then
					return target:require()
				end
				return require(target)
			end,
		},
	})
	local result = chunk()
	cache[path] = result
	return result
end

-- A fake Instance pointing at a path without extension (a file "X.luau" or a folder "X/").
local NodeMeta = {}
NodeMeta.__index = function(node, key)
	if key == "Parent" then
		local parent = string.match(node.__path, "^(.*)/[^/]+$")
		return parent and makeNode(parent) or nil
	end
	if key == "Name" then
		return string.match(node.__path, "([^/]+)$")
	end
	if key == "require" then
		return function(self)
			local file = self.__path .. ".luau"
			if fs.isFile(file) then
				return loadModule(file, self)
			end
			local init = self.__path .. "/init.luau"
			if fs.isFile(init) then
				return loadModule(init, self)
			end
			error("module not found: " .. self.__path)
		end
	end
	return makeNode(node.__path .. "/" .. key)
end

function makeNode(path: string)
	return setmetatable({ __path = path, __isNode = true }, NodeMeta)
end

-- Load a shared module by name, the way ReplicatedStorage.Shared.X would.
local function shared(name: string)
	return makeNode(ROOT .. "/" .. name):require()
end

-- Tiny assertion helpers
local passed, failed = 0, 0
local current = ""

local function near(actual: number, expected: number, tolerance: number?, what: string?)
	local tol = tolerance or 1e-6
	if math.abs(actual - expected) > tol then
		error(string.format("%s: expected %.6f, got %.6f (tolerance %g)", what or "value", expected, actual, tol), 2)
	end
end

local function equal(actual, expected, what: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. current .. " / " .. name)
	else
		failed += 1
		print("  FAIL " .. current .. " / " .. name .. "\n       " .. tostring(err))
	end
end

local ctx = { shared = shared, test = test, near = near, equal = equal }

local specs = fs.readDir("tests/specs")
table.sort(specs)
for _, file in specs do
	if string.match(file, "%.luau$") then
		current = string.gsub(file, "%.spec%.luau$", "")
		local chunk = luau.load(fs.readFile("tests/specs/" .. file), { debugName = file })
		chunk()(ctx)
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
process.exit(failed == 0 and 0 or 1)
