-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local BlockedDoor, parent = torch.class('BlockedDoor', 'MazeBase')

function BlockedDoor:__init(opts, vocab)
    parent.__init(self, opts, vocab)

    self.ngoals = 1
    self.ncolors = opts.ncolors or 2
    self.has_supervision = true
    self:place_wall()
    -- a distractor switch...
    self.nswitches = 1
    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
    end
    for i = 1, self.ngoals do
        self:place_item_rand({type = 'goal', name = 'goal' .. i})
    end
    --place agent on same side of wall as switch:
    local ah,aw
    local sh = self.items_bytype.switch[1].loc.y
    local sw = self.items_bytype.switch[1].loc.x
    for i = 1, 100 do
        if self.orientation ==1 then
            if sh<self.wall_position then
                ah = torch.random(1,self.wall_position-1)
            else
                local k = self.map.height-self.wall_position
                ah = torch.random(1,k)+self.wall_position
            end
            aw =torch.random(self.map.width)
        else
            if sw<self.wall_position then
                aw = torch.random(1,self.wall_position-1)
            else
                local k = self.map.width-self.wall_position
                aw = torch.random(1,k)+self.wall_position
            end
            ah =torch.random(self.map.height)
        end
        if #self.map.items[ah][aw] == 0 then
            break
        end
        if i == 100 then
            error('failed to place agent')
        end
    end
    self.agent = self:place_item({type = 'agent', name = 'agent1'},ah,aw)
    self.agents = {self.agent}
    self:add_default_items()

    -- objective
    self.goals = self.items_bytype['goal']
    self.ngoals_active = 1
    local g=self.goals[1]
    self:add_item({type = 'info', name = 'obj' .. 1, target = g.name})
    self.goal_reached = 0
    self.finish_by_goal = true
end

function BlockedDoor:place_wall()
    local orientation = torch.round(torch.uniform())
    self.orientation = orientation
    local H = self.map.height
    local W = self.map.width
    local h,w,dloc
    if orientation == 1 then
        h = torch.random(H-4)+2
        if h<1 then error('map too small') end
        dloc = torch.random(W)
        if self.enable_boundary == 1 then
            h = torch.random(H-6)+3
            dloc = torch.random(W-2)+1
        end
        self.wall_position = h
        for t =1, W do
            if t ==dloc then
                self:place_item({_factory = PushableBlock}, h, t)
                self.doorloc = torch.Tensor{h,t}
            else
                self:place_item({type = 'block'},h,t)
                self.nblocks = math.max(0, self.nblocks - 1)
            end
        end
    else
        w = torch.random(W-4)+2
        if w<1 then error('map too small') end
        dloc = torch.random(H)
        if self.enable_boundary == 1 then
            w = torch.random(W-6)+3
            dloc = torch.random(H-2)+1
        end
        self.wall_position = w
        for t =1, H do
            if t ==dloc then
                self:place_item({_factory = PushableBlock}, t, w)
                self.doorloc = torch.Tensor{t,w}
            else
                self:place_item({type = 'block'},t,w)
                self.nblocks = math.max(0, self.nblocks - 1)
            end
        end
    end
end

function BlockedDoor:get_supervision()
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local pcount = 0
    local H = self.map.height
    local W = self.map.width
    local X = {}
    local ans = torch.zeros(H*W*3)
    local rew = torch.zeros(H*W*3)
    local sh = self.agent.loc.y
    local sw =  self.agent.loc.x

    local gh = self.items_bytype['goal'][1].loc.y
    local gw = self.items_bytype['goal'][1].loc.x
    local dist,prev = self.ds.dsearch(self.cmap,sh,sw,gh,gw)
    local acount = 0
    local passable = true
    if dist < self.costs.block then
        -- are the agent and the goal on the same side?
        -- if so, return the path to the goal.
        -- note: had to be passable here....
        acount = self:search_move_and_update(gh,gw,X,ans,rew,acount)
    else
        -- agent and goal on opposite sides.
        --go next to door
        local e = self.items_bytype['pushableblock'][1]
        local dh = self.doorloc[1]
        local dw = self.doorloc[2]
        local ploc = {}
        ploc[1] = torch.Tensor{dh,dw-1}
        ploc[2] = torch.Tensor{dh,dw+1}
        ploc[3] = torch.Tensor{dh-1,dw}
        ploc[4] = torch.Tensor{dh+1,dw}
        local c = -1
        for s =1, 4 do
            local tgh = ploc[s][1]
            local tgw = ploc[s][2]
            if tgh > 0 and tgh <= self.map.height then
                if tgw > 0 and tgw <= self.map.width then
                    if self.ds.dsearch(self.cmap,sh,sw,tgh,tgw)< 500 then
                        c = s
                        break
                    end
                end
            end
        end
        if c < 0 then return self:quick_return_not_passable() end
        local sdh = ploc[c][1]
        local sdw = ploc[c][2]
        local pdy = dh - sdh
        local pdx = dw - sdw
        acount, passable = self:search_move_and_update(sdh,sdw,X,ans,rew,acount)
        if not passable then return self:quick_return_not_passable() end
        -- push block:
        for s = 1, 2 do
            if not self.map:is_loc_reachable(e.loc.y + pdy, e.loc.x + pdx) then
                return self:quick_return_not_passable()
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
            local ny = self.agent.loc.y + pdy
            local nx = self.agent.loc.x + pdx
            acount = self:search_move_and_update(ny,nx,X,ans,rew,acount)
        end
        --go to goal
        local gh = self.items_bytype['goal'][1].loc.y
        local gw = self.items_bytype['goal'][1].loc.x
        acount, passable = self:search_move_and_update(gh,gw,X,ans,rew,acount)
        if not passable then return self:quick_return_not_passable() end
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

function BlockedDoor:quick_return_not_passable()
    -- use this if agent is stuck.
    acount = 1
    local ans = torch.Tensor(1)
    local rew = torch.Tensor(1)
    local X = {}
    X[acount] = self:to_sentence()
    ans[acount] = self.agent.action_ids['stop']
    rew[acount] = self:get_reward()
    return X,ans,rew
end

function BlockedDoor:get_push_location(e,target)
    local ply = e.loc.y + (e.loc.y - target[1])
    local plx = e.loc.x + (e.loc.x - target[2])
    if self.map:is_loc_reachable(ply,plx) then
        return ply,plx
    else
        -- can't push to the next location...
        return nil
    end
end

function BlockedDoor:quick_return_block_stuck()
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

function BlockedDoor:d2a_push(dy,dx)
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
