-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local MazeItem = torch.class('MazeItem')

-- An item can have attributes (optional except type) such as:
--   type: type of the item such as water, block
--   loc: absolute coordinate of the item
--   name: unique name for the item (optional)
-- All attributes are visible to the agents.
function MazeItem:__init(attr)
    self.type = attr.type
    self.name = attr.name
    self.attr = attr
    self.loc = self.attr.loc
    if self.type == 'block' then
        function self:is_reachable() return false end
    elseif self.type == 'door' then
        function self:is_reachable()
            if self.attr.open == 'open' then
                return true
            end
            return false
        end
    else
        function self:is_reachable() return true end
    end
end

-- Warning:  basic clone only shallow copies
-- properties in the attr.
-- only numerical, string properties, and
-- the .loc table (if it exists) will be copied
-- override this (probably make a class)
-- if you want more complicated behavior
function MazeItem:clone()
    local attr = {}
    for i,j in pairs(self.attr) do
        if type(j) == 'number' or type(j) == 'string' then
            attr[i] = j
        end
    end
    if self.attr.loc then
        attr.loc = {}
        attr.loc.x = self.attr.loc.x
        attr.loc.y = self.attr.loc.y
    end
    local e = self.new(attr)
    return e
end

-- use this to change item attributes
-- to match a new maze that the item
-- will belong to.
function MazeItem:change_owner(maze)
end

function MazeItem:to_sentence(dy, dx, disable_loc)
    local s = {}
    for k,v in pairs(self.attr) do
        if k == 'loc' then
            if not disable_loc then
                local y = self.loc.y - dy
                local x = self.loc.x - dx
                table.insert(s, 'y' .. y .. 'x' .. x)
            end
        elseif type(k) == 'string' and k:sub(1,1) == '_' then
            -- skip
        else
            table.insert(s, v)
        end
    end
    return s
end
