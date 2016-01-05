-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local PushBlockCardinal, parent = torch.class('PushBlockCardinal', 'MazeBase')
-- push any pushable block to the specified location

function PushBlockCardinal:__init(opts, vocab)
    parent.__init(self, opts, vocab)
    self.has_supervision = true
    local ey, ex = self.map:get_empty_loc(1)
    self:place_item({_factory = PushableBlock}, ey, ex)
    self:add_default_items()
    local dests = {'top','bottom','left','right'}
    self.dest = torch.random(4)
    local destination = dests[self.dest]
    local attr = {type = 'info'}
    attr[1] = 'push'
    attr[2] = 'block'
    attr[3] = destination
    self:add_item(attr)
    self.ox = self.agent.loc.x
    self.oy = self.agent.loc.y

    -- for display
    self.map.ygoal = h
    self.map.xgoal = w
end

function PushBlockCardinal:update()
    parent.update(self)
    self.finished = false
    -- if there is a pushable item in the location, game is done.
    for i,j in pairs(self.items_bytype['pushableblock']) do
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
end

function PushBlockCardinal:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end

function PushBlockCardinal:get_supervision()
    local X = {}
    local H = self.map.height
    local W = self.map.width
    local hs = torch.zeros(H)
    local ws = torch.zeros(W)
    local ans = torch.zeros(3*H*W)
    local rew = torch.zeros(3*H*W)
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local e = self.items_bytype['pushableblock'][1]
    local dist = 10000
    local prev
    if self.dest == 1 then
        for s = 1, W do
            dist,prev = self:update_dist(e,dist,prev,1,s)
        end
    end
    if self.dest == 2 then
        for s = 1, W do
            dist,prev = self:update_dist(e,dist,prev,H,s)
        end
    end
    if self.dest == 3 then
        for s = 1, H do
            dist,prev = self:update_dist(e,dist,prev,s,1)
        end
    end
    if self.dest == 4 then
        for s = 1, H do
            dist,prev = self:update_dist(e,dist,prev,s,W)
        end
    end
    self.block_pcount = 0
    if dist > 800 then return self:quick_return_block_stuck() end
    local blockpath = self.ds.backtrack(e.loc.y,e.loc.x,self.ygoal,self.xgoal,prev)
    local acount = 0
    local bcount = 0
    while e.loc.y ~= self.ygoal or e.loc.x ~= self.xgoal do
        bcount = bcount + 1
        local py, px = self:get_push_location(e,blockpath[bcount+1])
        local passable = true
        if py then
            acount, passable = self:search_move_and_update(py,px,X,ans,rew,acount)
            if not passable then return self:quick_return_block_stuck() end
        else
            return self:quick_return_block_stuck()
        end
        local dy = self.agent.loc.y - e.loc.y
        local dx = self.agent.loc.x - e.loc.x
        local a = self:d2a_push(dy,dx)
        acount = acount + 1
        ans[acount] = a
        X[acount] = self:to_sentence()
        self:act(ans[acount])
        self:update()
        self:flatten_cost_map()
        rew[acount] = self:get_reward()
        -- so annoying... what if there were more than 1?
        e = self.items_bytype['pushableblock'][1]
    end
    if acount == 0 then
        X = {}
        X[1] = self:to_sentence()
        ans = torch.Tensor{self.agent.action_ids['stop']}
        rew = 0
    else
        ans = ans:narrow(1,1,acount)
        rew = rew:narrow(1,1,acount)
    end
    return X,ans,rew
end

function PushBlockCardinal:get_push_location(e,target)
    local ply = e.loc.y + (e.loc.y - target[1])
    local plx = e.loc.x + (e.loc.x - target[2])
    if self.map:is_loc_reachable(ply,plx) then
        return ply,plx
    else
        -- can't push to the next location...
        return nil
    end
end

function PushBlockCardinal:update_dist(e,dist,prev,s,t)
    if self.map:is_loc_reachable(s,t) then
        local ndist,nprev = self.ds.dsearch(self.cmap,e.loc.y,e.loc.x,s,t)
        if ndist < dist then
            prev = nprev
            dist = ndist
            self.ygoal = s
            self.xgoal = t
        end
    end
    return dist, prev
end

function PushBlockCardinal:quick_return_block_stuck()
    -- use this if agent has moved block badly
    acount = 1
    local ans = torch.Tensor(1)
    local rew = torch.Tensor(1)
    local X = {}
    X[acount] = self:to_sentence()
    ans[acount] = self.agent.action_ids['stop']
    rew[acount] = self:get_reward()
    return X,ans,rew
end

function PushBlockCardinal:d2a_push(dy,dx)
    local lact
    if dy> 0 then
        lact = 'push_up'
    elseif dy< 0 then
        lact = 'push_down'
    elseif dx< 0 then
        lact = 'push_right'
    elseif dx> 0 then
        lact = 'push_left'
    end
    return self.agent.action_ids[lact]
end
