-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local GotoHidden, parent = torch.class('GotoHidden', 'MazeBase')

function GotoHidden:__init(opts, vocab)
    self:setOpts(opts, vocab)
end

function GotoHidden:setOpts(opts, vocab)
    parent.__init(self, opts, vocab)

    self.goal_cost = self.costs.goal
    self.costs.goal = 0
    self.bad_goal_cost = opts.bad_goal_cost or 0

    self.nswitches = opts.nswitches or 0
    self.ncolors = opts.ncolors or 1

    assert(self.ngoals > 0)
    self:add_default_items()

    for i = 1, self.ngoals do
        local e = self:place_item_rand({type = 'goal', name = 'goal' .. i, _invisible = true})
        local destination = 'ay' .. e.loc.y .. 'x' .. e.loc.x
        local attr = {type = 'info'}
        attr[1] =  'goal' .. i
        attr[2] = 'at'
        attr[3] = 'absolute'
        attr[4] = destination
        self:add_item(attr)
    end
    self.goals = self.items_bytype['goal']
    self.true_goal = torch.random(self.ngoals)
    local attr = {type = 'info'}
    attr[1] =  'go'
    attr[2] = 'goal' .. self.true_goal
    self:add_item(attr)
    -- some decoys, if desired
    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
        self.switch_color = c
    end

    self.goal_reached = 0
end

function GotoHidden:update()
    parent.update(self)
    local g = self.goals[self.true_goal]
    if g.loc.y == self.agent.loc.y and g.loc.x == self.agent.loc.x then
        self.goal_reached = 1
        self.finished = true
    end
end

function GotoHidden:get_reward()
    local badgoal = false
     for s = 1, self.ngoals do
         if s~= self.true_goal then
             local g = self.goals[s]
             if g.loc.y == self.agent.loc.y and g.loc.x == self.agent.loc.x then
                 badgoal = true
             end
         end
    end

    if self.finished then
        return -self.goal_cost
    elseif badgoal then
        return parent.get_reward(self) -self.bad_goal_cost
    else
        return parent.get_reward(self)
    end
end

function GotoHidden:get_supervision()
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local acount = 0
    local H = self.map.height
    local W = self.map.width
    local X = {}
    local ans = torch.zeros(H*W)
    local rew = torch.zeros(H*W)
    local gid = self.true_goal
    local dh = self.items_bytype['goal'][gid].loc.y
    local dw = self.items_bytype['goal'][gid].loc.x
    acount = self:search_move_and_update(dh,dw,X,ans,rew,acount)
    if acount == 0 then
        ans = nil
        rew = 0
    else
        ans = ans:narrow(1,1,acount)
        rew = rew:narrow(1,1,acount)
    end
    return X,ans,rew
end
