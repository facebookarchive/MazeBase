-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local PushBlock, parent = torch.class('PushBlock', 'MazeBase')
-- push any pushable block to the specified location

function PushBlock:__init(opts, vocab)
    parent.__init(self, opts, vocab)
    self.has_supervision =true
     local ey, ex = self.map:get_empty_loc(1)
    self:place_item({_factory = PushableBlock}, ey, ex)
    self:add_default_items()
    self.nswitches = 1
    self.ncolors = opts.ncolors or 1
    local h, w = self.map:get_empty_loc()
    self.ygoal = h
    self.xgoal = w
     local c = torch.random(self.ncolors)
    self.target_color = c
    self:place_item({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors},h,w)
    local clr_str = 'color' .. self.target_color
    local attr = {type = 'info'}
    attr[1] = 'push'
    attr[2] = 'block'
    attr[3] = clr_str
    attr[4] = 'switch'
    self:add_item(attr)
    self.ox = self.agent.loc.x
    self.oy = self.agent.loc.y
    -- for display
    self.map.ygoal = h
    self.map.xgoal = w
end

function PushBlock:update()
    parent.update(self)
    self.finished = false
    -- if there is a pushable item in the location, game is done.
    for i,j in pairs(self.map.items[self.ygoal][self.xgoal]) do
        if j.type == 'pushableblock' then
            self.finished = true
        end
    end
end

function PushBlock:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end

function PushBlock:get_supervision()
    local X = {}
    local H = self.map.height
    local W = self.map.width
    local ans = torch.zeros(3*H*W)
    local rew = torch.zeros(3*H*W)
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local e = self.items_bytype['pushableblock'][1]
    self.block_pcount = 0
    local dist,prev = self.ds.dsearch(self.cmap,e.loc.y,e.loc.x,self.ygoal,self.xgoal)
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

function PushBlock:get_push_location(e,target)
    local ply = e.loc.y + (e.loc.y - target[1])
    local plx = e.loc.x + (e.loc.x - target[2])
    if self.map:is_loc_reachable(ply,plx) then
        return ply,plx
    else
        -- can't push to the next location...
        return nil
    end
end

function PushBlock:quick_return_block_stuck()
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

function PushBlock:d2a_push(dy,dx)
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
