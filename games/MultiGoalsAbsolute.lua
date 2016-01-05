-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local MultiGoalsAbsolute, parent = torch.class('MultiGoalsAbsolute', 'MazeBase')

function MultiGoalsAbsolute:__init(opts, vocab)
    parent.__init(self, opts, vocab)

    self.goal_cost = self.costs.goal
    self.costs.goal = 0

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

    -- objective
    self.goals = self.items_bytype['goal']
    self.ngoals_active = opts.ngoals_active

    self.goal_order = torch.randperm(self.ngoals):narrow(1,1,self.ngoals_active)
    for i = 1, opts.ngoals_active do
        if i > self.ngoals_active then
            self:add_item({type = 'info'})
        else
            local g = self.goals[self.goal_order[i]]
            self:add_item({type = 'info', name = 'obj' .. i, target = g.name})
        end
    end

    self.goal_reached = 0
end

function MultiGoalsAbsolute:update()
    parent.update(self)
    if self.goal_reached < self.ngoals_active then
        local k = self.goal_order[self.goal_reached + 1]
        local g = self.goals[k]
        if g.loc.y == self.agent.loc.y and g.loc.x == self.agent.loc.x then
            self.goal_reached = self.goal_reached + 1
            if self.flag_visited == 1 then
                g.attr.visited = 'visited'
                g.attr._invisible = false
            end
            if self.goal_reached == self.ngoals_active then
                self.finished = true
            end
        end
    end
end

function MultiGoalsAbsolute:get_reward()
    if self.finished then
        return -self.goal_cost
    else
        return parent.get_reward(self)
    end
end

function MultiGoalsAbsolute:get_supervision()
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local acount = 0
    local H = self.map.height
    local W = self.map.width
    local X = {}
    local ans = torch.zeros(self.ngoals_active*H*W)
    local rew = torch.zeros(self.ngoals_active*H*W)
    for s = 1, self.goal_order:size(1) do
        local gid = self.goal_order[s]
        local dh = self.items_bytype['goal'][gid].loc.y
        local dw = self.items_bytype['goal'][gid].loc.x
        acount = self:search_move_and_update(dh,dw,X,ans,rew,acount)
        if self.crumb_action==1 then
            acount = acount + 1
            X[acount] = self:to_sentence()
            ans[acount] = self.agent.action_ids['breadcrumb']
            self:act(ans[acount])
            self:update()
            rew[acount] = self:get_reward()
        end
    end
    if acount == 0 then
        ans = nil
        rew = 0
    else
        ans = ans:narrow(1,1,acount)
        rew = rew:narrow(1,1,acount)
    end
    return X,ans,rew
end

function MultiGoalsAbsolute:d2a(dy,dx)
    local lact
    if dy< 0 then
        lact = 'up'
    elseif dy> 0 then
        lact = 'down'
    elseif dx> 0 then
        lact = 'right'
    elseif dx< 0 then
        lact = 'left'
    end
    return self.agent.action_ids[lact]
end
