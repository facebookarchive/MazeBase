-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local LightKey, parent = torch.class('LightKey', 'MazeBase')

function LightKey:__init(opts, vocab)
    parent.__init(self, opts, vocab)

    self.nswitches = 1
    self.ngoals = 1
    self.ncolors = opts.ncolors or 2

    self:place_wall()

    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
        self:update_door(c)
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

    self.agent:add_action('toggle',
        function(agent)
            local l = agent.map.items[agent.loc.y][agent.loc.x]
            for _, e in ipairs(l) do
                if e.type == 'switch' then
                    local c = e.attr._c
                    c = (c % e.attr._cn) + 1
                    e.attr._c = c
                    e.attr.color = 'color' .. c
                    self:update_door(c)
                end
            end
        end
    )

    -- objective
    self.goals = self.items_bytype['goal']
    self.ngoals_active = 1
    local g=self.goals[1]
    self:add_item({type = 'info', name = 'obj' .. 1, target = g.name})
    self.goal_reached = 0
    self.finish_by_goal = true
end

function LightKey:update_door(c)
    for s,t in pairs(self.items_bytype.door) do
        if t.attr._c == c then
            t.attr.open = 'open'
            if self.cmap then
                self.cmap[t.attr.loc.y][t.attr.loc.x] = self.costs.step
            end
        else
            if self.cmap then
                self.cmap[t.attr.loc.y][t.attr.loc.x] = self.costs.block
            end
            t.attr.open = 'closed'
        end
    end
end

function LightKey:place_wall()
    local orientation = torch.round(torch.uniform())
    self.orientation = orientation
    local H = self.map.height
    local W = self.map.width
    local h,w,dloc
    if orientation == 1 then
        h = torch.random(H-2)+1
        dloc = torch.random(W)
        if self.enable_boundary == 1 then
            h = torch.random(H-4)+2
            dloc = torch.random(W-2)+1
        end
        self.wall_position = h
        for t =1, W do
            if t ==dloc then
                local dc = torch.random(self.ncolors)
                local attr = {type='door', _c = dc,color = 'color' .. dc}
                self:place_item(attr,h,t)
            else
                self:place_item({type = 'block'},h,t)
                self.nblocks = math.max(0, self.nblocks - 1)
            end
        end
    else
        w = torch.random(W-2)+1
        dloc = torch.random(H)
        if self.enable_boundary == 1 then
            w = torch.random(W-4)+2
            dloc = torch.random(H-2)+1
        end
        self.wall_position = w
        for t =1, H do
            if t ==dloc then
                local dc = torch.random(self.ncolors)
                local attr = {type='door', _c = dc,color = 'color' .. dc}
                self:place_item(attr,t,w)
            else
                self:place_item({type = 'block'},t,w)
                self.nblocks = math.max(0, self.nblocks - 1)
            end
        end
    end
end

function LightKey:get_supervision()
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
        --go to light key
        local kh = self.items_bytype['switch'][1].loc.y
        local kw = self.items_bytype['switch'][1].loc.x
        acount, passable = self:search_move_and_update(kh,kw,X,ans,rew,acount)
        if not passable then return self:quick_return_not_passable() end
        local cl = self.items_bytype['door'][1].attr._c
        --toggle light key
        while self.items_bytype['switch'][1].attr._c ~= cl do
            acount = acount + 1
            X[acount] = self:to_sentence()
            ans[acount] = self.agent.action_ids['toggle']
            self:act(ans[acount])
            self:update()
            rew[acount] = self:get_reward()
        end
        --go to door
        local dh = self.items_bytype['door'][1].loc.y
        local dw = self.items_bytype['door'][1].loc.x
        acount, passable = self:search_move_and_update(dh,dw,X,ans,rew,acount)
        if not passable then return self:quick_return_not_passable() end
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

function LightKey:quick_return_not_passable()
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

function LightKey:d2a(dy,dx)
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
