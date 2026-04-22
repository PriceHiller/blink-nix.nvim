local success, async = pcall(require, "blink.lib.task")

-- If we cant get the newer lib from `blink.lib` part of blink.cmp v2, then
-- fallback to the v1 equivalent
if not success then
    -- HACK: Using the `v1` branch of `blink.cmp` -- shim it for compatibility
    async = require("blink.cmp.lib.async")
    async.resolve = async.empty
    async.on_resolve = async.on_completion
    async.on_reject = async.on_failure
end

---@type blink.cmp.Source
---@diagnostic disable-next-line: missing-fields
local M = {}

---@class blink-nix.NixComps
local NixComps

function M.new(opts)
    local self = setmetatable({}, { __index = M })
    config = vim.tbl_deep_extend("keep", opts or {}, {
        insert = true,
    })
    if not NixComps then
        NixComps = require("blink-nix.nix").NixComps.new()
    end
    return self
end

---@param ctx blink.cmp.Context
function M:get_completions(ctx, callback)
    local task = async.resolve():map(function()
        local is_char_trigger = vim.list_contains(
            self:get_trigger_characters(),
            ctx.line:sub(ctx.bounds.start_col - 1, ctx.bounds.start_col - 1)
        )
        local items = {}
        if is_char_trigger and NixComps:ctx_valid(ctx) then
            items = NixComps:get_candidates(ctx)
        end
        callback({
            is_incomplete_forward = true,
            is_incomplete_backward = true,
            items = items,
            context = ctx,
        })
    end)
    return function()
        task:cancel()
    end
end

---`newText` is used for `ghost_text`, thus it is set to the emoji name in `emojis`.
---Change `newText` to the actual emoji when accepting a completion.
function M:resolve(item, callback)
    local resolved = vim.deepcopy(item)
    return callback(resolved)
end

function M:get_trigger_characters()
    return { "." }
end

return M
