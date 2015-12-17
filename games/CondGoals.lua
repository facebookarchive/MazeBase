local CondGoals, parent = torch.class('CondGoals', 'MazeBase')

function CondGoals:__init(opts, vocab)
    self:setOpts(opts, vocab)
end

function CondGoals:setOpts(opts, vocab)
    parent.__init(self, opts, vocab)

    self.goal_cost = self.costs.goal
    self.costs.goal = 0
    self.bad_goal_cost = opts.bad_goal_cost or .2

    self.nswitches = 1
    self.ncolors = opts.ncolors or 2

    assert(self.ngoals > 0)

    self:add_default_items()

    for i = 1, self.ngoals do
        self:place_item_rand({type = 'goal', name = 'goal' .. i})
    end
    for i = 1, self.nswitches do --fixed at 1 for now
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
        self.switch_color = c
    end

    -- objective
    self.goals = self.items_bytype['goal']
    self.ngoals_active = 1
    for s = 1, self.ncolors do
        local gn = torch.random(self.ngoals)
        attr = {type = 'info',
                conditional = 'if',
                predicate = 'switch',
                color = 'color' .. s,
                target = 'goal' .. gn }
        self:add_item(attr)
        if s==self.switch_color then self.cond_goal = gn end
    end
    self.goal_reached = 0
end

function CondGoals:update()
    parent.update(self)
    local g = self.goals[self.cond_goal]
    if g.loc.y == self.agent.loc.y and g.loc.x == self.agent.loc.x then
        self.goal_reached = 1
        self.finished = true
    end
end

function CondGoals:get_reward()
    local badgoal = false
     for s = 1, self.ngoals do
         if s~= self.cond_goal then
             local g = self.goals[s]
             if g.loc.y == self.agent.loc.y and g.loc.x == self.agent.loc.x then
                 badgoal = true
             end
         end
    end

    if self.finished then
        return -self.goal_cost
    elseif badgoal then
        return -self.bad_goal_cost
    else
        return parent.get_reward(self)
    end
end


function CondGoals:get_supervision()
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
    local gid = self.cond_goal
    local dh = self.items_bytype['goal'][gid].loc.y
    local dw = self.items_bytype['goal'][gid].loc.x
    acount = self:search_move_and_update(dh,dw,X,ans,rew,acount)
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

function CondGoals:d2a(dy,dx)
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



--[===[
function CondGoals:get_supervision()
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local path = self:find_path()
    local X, act = self:bpath_to_data(path)
    return X,act
end

function CondGoals:find_path()
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    local pcount = 0
    local H = self.map.height
    local W = self.map.width
    local sh = self.item_byname['agent1'].loc.y
    local sw =  self.item_byname['agent1'].loc.x
    local gid = self.cond_goal
    local dh = self.items_bytype['goal'][gid].loc.y
    local dw = self.items_bytype['goal'][gid].loc.x
    local path
    if sh ~= dh or sw ~= dw then
        local dist,prev = self.ds.dsearch(self.cmap,sh,sw,dh,dw)
        path = self.ds.backtrack(sh,sw,dh,dw,prev)
    else --agent already at local goal
        path = torch.Tensor{sh,sw}
    end
    return path
end

function CondGoals:bpath_to_data(bpath)
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
