-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local GotoSwitch, parent = torch.class('GotoSwitch', 'MazeBase')

function GotoSwitch:__init(opts, vocab)
    parent.__init(self, opts, vocab)
    self.has_supervision = false
    self.nswitches = opts.nswitches or 1
    self.ncolors = opts.ncolors or 2
    -- explicit is if the environment decides the desired
    -- switch color or the agent gets to choose.
    self:add_default_items()
    self.colors = torch.zeros(self.nswitches)
    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self.colors[i] = c
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
    end
    self.target_color = self.colors[torch.random(self.nswitches)]
    clr_str = 'color' .. self.target_color
    local attr = {type = 'info'}
    attr[1] = 'obj1'
    attr[2] = 'go'
    attr[3] = clr_str
    attr[4] = 'switch'
    self:add_item(attr)
end

function GotoSwitch:update()
    parent.update(self)
    self.finished = false
    local a = self.agent
    local y = self.agent.loc.y
    local x = self.agent.loc.y
    for i,j in pairs(self.map.items[y][x]) do
        if j.type == 'switch' and j.attr._c == self.target_color then
            self.finished = true
        end
    end
end

function GotoSwitch:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end
