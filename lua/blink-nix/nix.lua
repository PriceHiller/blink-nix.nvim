---@alias blink-nix.comps table<string, table<string, string[]>>

---@class blink-nix.NixComps
---@field job vim.SystemObj?
local NixComps = {}

---@param candidate string
---@return blink.cmp.CompletionItem
function NixComps._transform_candidate(candidate)
    return {
        label = candidate,
        insertText = candidate,
        source_name = "nix",
    }
end

---@type string[]
local cached_pkgs = {}

---@param nix_attr_path string[]
---@return string[]
function NixComps:_candidates(nix_attr_path)
    if self.job then
        self.job:kill(9)
    end

    -- TODO: Abstract this out to allow users to provide their own expr's.
    -- For now, this will do.
    ---@type string[]
    local candidates = {
        pkgs = [[builtins.attrNames ((import <nixpkgs> { }))]],
        lib = [[builtins.attrNames ((import <nixpkgs/lib>)%s)]],
        builtins = [[builtins.attrNames (builtins%s)]],
    }

    if #nix_attr_path <= 1 then
        return candidates
    end

    local mod = table.remove(nix_attr_path, 1)

    if mod == "pkgs" and #cached_pkgs > 0 then
        if #nix_attr_path == 1 then
            return cached_pkgs
        elseif #nix_attr_path > 1 then
            mod = table.remove(nix_attr_path, 1)
        end
    end

    if not candidates[mod] then
        return {}
    end

    table.remove(nix_attr_path)

    local attr_path = vim.iter(nix_attr_path):join(".")

    self.job = vim.system({
        "nix",
        "eval",
        "--impure",
        "--json",
        "--expr",
        (candidates[mod]):format(attr_path ~= "" and "." .. attr_path or ""),
    })
    local out = self.job:wait()

    if out.code > 0 then
        return {}
    end

    candidates = vim.json.decode(out.stdout)
    if mod == "pkgs" then
        cached_pkgs = candidates
    end
    return candidates
end

---@param ctx blink.cmp.Context
---@return string[]
function NixComps:get_candidates(ctx)
    local before = vim.trim(ctx.line:sub(1, ctx.cursor[2]))
    local prefix = before:match("[%w%._-]+$")
    local nix_attr_path = vim.split(prefix, "%.")
    return vim.iter(self:_candidates(nix_attr_path)):map(self._transform_candidate):totable()
end

---@param ctx blink.cmp.Context
---@return boolean
function NixComps:ctx_valid(ctx)
    local bo = vim.bo[ctx.bufnr]
    return (bo and bo.filetype == "nix")
end
function NixComps.new()
    return setmetatable({}, { __index = NixComps })
end

local M = {
    NixComps = NixComps,
}
return M
