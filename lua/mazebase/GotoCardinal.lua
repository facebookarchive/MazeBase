-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local GotoCardinal, parent = torch.class('GotoCardinal', 'MazeBase')
-- this game does an absolute goto.

function GotoCardinal:__init(opts, vocab)
    parent.__init(self, opts, vocab)
    self.has_supervision = false
    --add some switches as decoys.
    self.nswitches = opts.nswitches or 0
    self.ncolors = opts.ncolors or 1

    self:add_default_items()

    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
    end

    local dests = {'top','bottom','left','right'}
    self.dest = torch.random(4)
    local destination = dests[self.dest]
    local attr = {type = 'info'}
    attr[1] = 'obj1'
    attr[2] = 'go'
    attr[3] = destination
    self:add_item(attr)
end

function GotoCardinal:update()
    parent.update(self)
    self.finished = false
    local j = self.agent
    if self.dest == 1 and j.loc.y == 1 then
        self.finished = true
    end
    if self.dest == 2 and j.loc.y == self.map.height then
        self.finished = true
    end
    if self.dest == 3 and j.loc.x == 1 then
        self.finished = true
    end
    if self.dest == 4 and j.loc.x == self.map.width then
        self.finished = true
    end
end

function GotoCardinal:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end
