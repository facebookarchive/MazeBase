-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local Goto, parent = torch.class('Goto', 'MazeBase')
-- this game does an absolute goto.

function Goto:__init(opts, vocab)
    parent.__init(self, opts, vocab)

    --add some switches as decoys.
    self.nswitches = opts.nswitches or 0
    self.ncolors = opts.ncolors or 1

    self:add_default_items()

    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
    end
    local h, w = self.map:get_empty_loc()
    self.ygoal = h
    self.xgoal = w
    local destination = 'ay' .. h .. 'x' .. w
    local attr = {type = 'info',
             name =  'obj1',
            task = 'go',
            what = 'absolute',
            aloc = destination }
    self:add_item(attr)
end

function Goto:update()
    parent.update(self)
    self.finished = false
    if self.agent.loc.x == self.xgoal and self.agent.loc.y == self.ygoal then
        self.finished = true
    end
end

function Goto:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end

function Goto:get_supervision()
    local X = {}
    local H = self.map.height
    local W = self.map.width
    local ans = torch.zeros(H*W)
    local rew = torch.zeros(H*W)
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local acount = 0
    acount = self:search_move_and_update(self.ygoal,self.xgoal,X,ans,rew,acount)
    if acount == 0 then
        ans = nil
        rew = 0
    else
        ans = ans:narrow(1,1,acount)
        rew = rew:narrow(1,1,acount)
    end
    return X,ans,rew
end
