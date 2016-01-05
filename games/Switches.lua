-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local Switches, parent = torch.class('Switches', 'MazeBase')

function Switches:__init(opts, vocab)
    parent.__init(self, opts, vocab)

    self.nswitches = opts.nswitches or 1
    self.ncolors = opts.ncolors or 2
    -- explicit is if the environment decides the desired
    -- switch color or the agent gets to choose.
    if not opts.explicit then
        self.explicit = false
    else
        self.explicit = opts.explicit
    end

    self:add_default_items()
    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
    end
    self.target_color = -1
    local clr_str = 'same'
    if self.explicit then
        self.target_color = torch.random(self.ncolors)
        clr_str = 'color' .. self.target_color
    end
    local attr = {type = 'info',
            task = 'task',
            what = 'switch',
            color = 'color',
            target = clr_str  }
    self:add_item(attr)
end

function Switches:update()
    parent.update(self)
    local c
    if not self.explicit then
        c = nil
    else
        c = self.target_color
    end
    self.finished = true
    for _, s in ipairs(self.items_bytype['switch']) do
        if c ~= nil and c ~= s.attr._c then
            self.finished = false
        end
        if not self.explicit then
            c = s.attr._c
        end
    end
end

function Switches:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end

function Switches:get_supervision()
    -- this is greedy, not brute force.  it
    -- will find a suboptimal path!
    -- 1: chooses the color of the farthest switch
    -- 2: goes to the
    -- nearest wrong-colored switch in xy space without
    -- considering the map obstacles.
    local X = {}
    local H = self.map.height
    local W = self.map.width
    local ans = torch.zeros(H*W*self.nswitches)
    local rew = torch.zeros(H*W*self.nswitches)
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    --find the majority color:
    local pcount = 0
    local H = self.map.height
    local W = self.map.width
    local sh = self.agent.loc.y
    local sw =  self.agent.loc.x
    local toggled = torch.zeros(self.nswitches)
    local dists = torch.zeros(self.nswitches)
    for i,j in pairs(self.items_bytype.switch) do
        dists[i] = (j.loc.y-sh)^2+ (j.loc.x-sw)^2
    end
    local dv, dl = dists:max(1)
    dl = dl[1]
    local cl = self.items_bytype.switch[dl].attr._c
    --------------------
    -- if explicit cl , ignore the above,
    if self.explicit then cl = self.target_color end
    for s = 1, self.nswitches do
        if self.items_bytype.switch[s].attr._c == cl then
            toggled[s] = 1
        end
    end
    local acount = 0;
    local passable = true
    while toggled:min()<1 do
        local sl = self:nearest_untoggled(toggled)
        local target_switch = self.items_bytype['switch'][sl]
        local dh = target_switch.loc.y
        local dw = target_switch.loc.x
        acount, passable = self:search_move_and_update(dh,dw,X,ans,rew,acount)
        if not passable then
            --agent is stuck, best policy is to stop
            acount = 1
            X = {}
            X[acount] = self:to_sentence()
            ans[acount] = self.agent.action_ids['stop']
            rew[acount] = self:get_reward()
            ans = ans:narrow(1,1,acount)
            rew = rew:narrow(1,1,acount)
            return X,ans,rew
        end
        -- agent is at the switch; toggle it
        while target_switch.attr._c ~= cl do
            acount = acount + 1
            X[acount] = self:to_sentence()
            ans[acount] = self.agent.action_ids['toggle']
            self:act(ans[acount])
            self:update()
            rew[acount] = self:get_reward()
        end
        toggled[sl] = 1
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

function Switches:nearest_untoggled(toggled)
    local sh = self.agent.loc.y
    local sw =  self.agent.loc.x
    local dists = torch.ones(self.nswitches):mul(10000)
    for t = 1, self.nswitches do
        if toggled[t] == 0 then
            local dh = self.items_bytype['switch'][t].loc.y
            local dw = self.items_bytype['switch'][t].loc.x
            dists[t] = (dh-sh)^2+ (dw-sw)^2
        end
    end
    local md, cswitch = dists:min(1)
    cswitch = cswitch[1]
    return cswitch
end

function Switches:d2a(dy,dx)
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
