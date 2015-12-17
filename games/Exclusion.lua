local Exclusion, parent = torch.class('Exclusion', 'MazeBase')

function Exclusion:__init(opts, vocab)
    parent.__init(self, opts, vocab)

    self.goal_cost = self.costs.goal
    self.costs.goal = 0
    self.wrong_goal_cost = opts.Exclusion_wrong_goal_cost or .5
    assert(self.ngoals > 0)
    self:add_default_items()

    for i = 1, self.ngoals do
        self:place_item_rand({type = 'goal', name = 'goal' .. i})
    end

    -- objective
    self.goals = self.items_bytype['goal']
    self.ngoals_active = opts.ngoals_active
    self.visited = torch.zeros(self.ngoals)
    self.goal_order = torch.randperm(self.ngoals)
    self:add_item({type = 'info', visit = 'visit', target = 'all', excluding = 'excluding'})
    for i = opts.ngoals_active+1, opts.ngoals do
        local g = self.goals[self.goal_order[i]]
        self:add_item({type = 'info', avoid = 'avoid', target = g.name})
    end
end

function Exclusion:update()
    parent.update(self)
    for s = 1, self.ngoals do
        local g= self.goals[s]
        if g.loc.y == self.agent.loc.y and g.loc.x == self.agent.loc.x then
            self.visited[s] = 1
            if self.flag_visited == 1 then
                g.attr.visited = 'visited'
            end

            self.finished = true
            for s =1, self.ngoals_active do
                local k = self.goal_order[s]
                if self.visited[k] == 0 then self.finished = false end
            end
        end
    end
end

function Exclusion:get_reward()
    local badgoal = false
    for i =self.ngoals_active+1,self.ngoals do
        local g = self.goals[self.goal_order[i]]
        if g.loc.y == self.agent.loc.y and g.loc.x == self.agent.loc.x then
            badgoal = true
        end
    end
    if self.finished then
        return -self.goal_cost
    elseif badgoal then
        return -self.wrong_goal_cost
    else
        return parent.get_reward(self)
    end
end

function  Exclusion:get_supervision()
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    -- so ugly, need to fix this:
    for i = self.ngoals_active+1, self.ngoals do
        local g = self.items_bytype['goal'][self.goal_order[i]]
        self.cmap[g.attr.loc.y][g.attr.loc.x] = .5
    end
    local acount = 0
    local H = self.map.height
    local W = self.map.width
    local X = {}
    local visited = torch.zeros(self.ngoals)
    for i = self.ngoals_active+1, self.ngoals do
        local g = self.goal_order[i]
        visited[g] = 1
    end
    local ans = torch.zeros(self.ngoals_active*H*W)
    local rew = torch.zeros(self.ngoals_active*H*W)
    for s = 1, self.goal_order:size(1) do
        local lg = self:nearest_unvisited(visited)
         if lg > 0 then
             local dh = self.items_bytype['goal'][lg].loc.y
             local dw = self.items_bytype['goal'][lg].loc.x
             acount = self:search_move_and_update(dh,dw,X,ans,rew,acount)
             if self.crumb_action==1 then
                 acount = acount + 1
                 X[acount] = self:to_sentence()
                 ans[acount] = self.agent.action_ids['breadcrumb']
                 self:act(ans[acount])
                 self:update()
                 rew[acount] = self:get_reward()
             end
             visited[lg] = 1
         end
    end
    -- if self.agent.action_ids['stop'] then
    --     acount = acount + 1
    --     X[acount] = self:to_sentence()
    --     ans[acount] = self.agent.action_ids['stop']
    --     rew[acount] = self:get_reward()
    -- end
    if acount == 0 then
        ans = nil
        rew = 0
    else
        ans = ans:narrow(1,1,acount)
        rew = rew:narrow(1,1,acount)
    end
    return X,ans,rew
end

function Exclusion:d2a(dy,dx)
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



function Exclusion:nearest_unvisited(visited)
    local sh = self.agent.loc.y
    local sw =  self.agent.loc.x
    local dists = torch.ones(self.ngoals):mul(10000)
    if visited:min() == 1 then return -1 end
    for t = 1, self.ngoals do
        if visited[t] == 0 then
            local dh = self.items_bytype['goal'][t].loc.y
            local dw = self.items_bytype['goal'][t].loc.x
            dists[t] = (dh-sh)^2+ (dw-sw)^2
        end
    end
    local md, cgoal = dists:min(1)
    cgoal = cgoal[1]
    return cgoal
end


--[===[


function Exclusion:get_supervision()
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local bigpath = self:find_big_path()
    local X, act = self:bpath_to_data(bigpath)
    return X,act
end

function Exclusion:find_big_path()
    -- this is greedy, not brute force.  it
    -- may find a suboptimal path!  goes to the
    -- nearest allowable goal in xy space without
    -- considering the map obstacles.
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    local ngoals = self.ngoals_active
    local pcount = 0
    local H = self.map.height
    local W = self.map.width
    local bigpath = torch.zeros(H*W*ngoals,2)
    local sh = self.item_byname['agent1'].loc.y
    local sw =  self.item_byname['agent1'].loc.x
    local visited = torch.zeros(ngoals)
    for s = 1, ngoals do
        -- find nearest unvisited allowed goal
        local dists = torch.ones(ngoals):mul(10000)
        for t = 1, ngoals do
            if visited[t] == 0 then
                local gid = self.goal_order[t]
                local dh = self.items_bytype['goal'][gid].loc.y
                local dw = self.items_bytype['goal'][gid].loc.x
                dists[t] = (dh-sh)^2+ (dw-sw)^2
            end
        end
        local md, mloc = dists:min(1)
        mloc = mloc[1]
        visited[mloc] = 1
        local gid = self.goal_order[mloc]
        local dh = self.items_bytype['goal'][gid].loc.y
        local dw = self.items_bytype['goal'][gid].loc.x
        if sh ~= dh or sw ~= dw then
            local dist,prev = self.ds.dsearch(self.cmap,sh,sw,dh,dw)
            local path = self.ds.backtrack(sh,sw,dh,dw,prev)
            local pl = path:size(1) - 1
            bigpath:sub(pcount + 1, pcount + pl):copy(path:sub(2,-1))
            if self.crumb_action then
                bigpath[pcount + pl+1]:copy(bigpath[pcount + pl])
                pcount = pcount + pl + 1
            else
                pcount = pcount + pl
            end
            sh = dh
            sw = dw
        else --agent already at local goal
            if self.crumb_action then
                bigpath[pcount + 1]:copy(torch.Tensor{sh,sw})
                pcount = pcount + 1
            end
        end
    end
    bigpath = bigpath:narrow(1,1,pcount)
    return bigpath
end

function Exclusion:bpath_to_data(bpath)
    local pl = bpath:size(1)
    local agent = self.items_bytype['agent'][1]
    agent.loc.y = bpath[1][1]
    agent.loc.x = bpath[1][2]
    local X = {}
    local act = torch.Tensor(pl)
    for t = 1, pl-1 do
        X[t] = self:to_sentence('agent1')
        local dy = bpath[t+1][1]-bpath[t][1]
        local dx = bpath[t+1][2]-bpath[t][2]
        local lact
        if dy< 0 then
            lact = 'up'
        elseif dy> 0 then
            lact = 'down'
         elseif dx> 0 then
            lact = 'right'
        elseif dx< 0 then
            lact = 'left'
        elseif t< pl-1 then
            lact = 'breadcrumb'
        else
            lact = 'stop'
        end
        act[t] = self.agent.action_ids[lact]
        self:act('agent1',act[t])
        self:update()
    end
    X[pl] = self:to_sentence('agent1')
    act[pl] = self.agent.action_ids['stop']
    return X,act
end
--]===]
