-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local StarEnemy, parent = torch.class('StarEnemy','MazeItem')

local su = paths.dofile('shooting_utils.lua')

function StarEnemy:__init(attr,maze)
    -- simple npc that moves around randomly
    self.speed = attr._speed or 1
    self.maze = maze
    self.cover_map = maze.cover_map
    self.range = attr._range or 1
    self.map = maze.map
    self.type = 'StarEnemy'
    self.name = attr.name
    self.attr = attr
    self.loc = self.attr.loc
    self.nactions = 0
    self.action_names = {}
    self.action_ids ={}
    self.actions ={}
    self.updateable = true
    self.closest_agent = 0 -- index of closest agent
    self.range_closest_agent = 0 -- L1 distance to closest agent
    self.can_shoot = true
    self.counter = -1
    self.add_action = MazeAgent.add_action
    MazeAgent.add_move_actions(self)
    function self:is_reachable() return true end
end

function StarEnemy:update()
    --- Logic for StarEnemy bot
    ---
    --- Overview: with some small probability, move in random direction
    ---           otherwise, find closest agent
    ---           if within shooting range, then fire at agent
    --            if not within range, then move towards it

    -- are we still alive?
    if self.health == 0 then
        self.killed = true
        self.attr._invisible = true
        return
    end

    -- update counter mod self.speed.  if counter == 0,
    -- continue to act.  note cooldown is only updated
    -- on action steps, so total time between shots
    -- is self.speed * self.max_cooldown

    self.counter = (self.counter + 1) % self.speed
    if self.counter ~= 0 then return end

    if self.action_noise > math.random() then
        -- take random action
        local m = torch.random(5)
        self.actions[m](self)
    else
        -- home in on an agent
        local rel_total = torch.Tensor(self.maze.nagents)
        local rel_x = torch.Tensor(self.maze.nagents)
        local rel_y = torch.Tensor(self.maze.nagents)
        -- figure out relative position between enemy and each agent
        for i, agent in pairs(self.maze.agents) do
            rel_x[i] = agent.loc.x - self.loc.x
            rel_y[i] = agent.loc.y - self.loc.y
            rel_total[i] = math.abs(rel_x[i]) + math.abs(rel_y[i])
            if agent.health == 0 then
                rel_total[i] = 999 -- to prevent enemy homing in on already dead agent
            end
        end
        -- figure out closest one (L1 metric)
        local rel_total_max, ind = torch.min(rel_total,1)
        -- set closest agent
        self.closest_agent = ind[1]
        self.range_closest_agent = rel_total_max[1]
        local ey = self.maze.agents[ind[1]].loc.y
        local ex = self.maze.agents[ind[1]].loc.x
        local sy = self.loc.y
        local sx = self.loc.x
        local ha,l = su.check_hittable(self.maze.cover_map,self.range,sy,sx,ey,ex)
        if ha and self.can_shoot and self.cooldown == 0 then
            -- within shooting range and not behind cover
            if not self.maze.map.enemy_shots then self.maze.map.enemy_shots = {} end
            table.insert(self.maze.map.enemy_shots,l)
            if math.random() > self.pMiss then
                -- shoot closest agent (assumes shoot_agent1 etc. are actions 6,7,8..)
                local agent = self.maze.agents[self.closest_agent]
                -- hit decreases health of agent
                agent.health = math.max(agent.health - 1, 0)
            end
            -- set cooldown to max value
            self.cooldown = self.cooldown_max + 1
        else
            -- just move towards agent
            -- decide if move in x or in y toward it
            if math.random() > (math.abs(rel_x[self.closest_agent])/self.range_closest_agent) then
                -- move in y
                if rel_y[self.closest_agent] > 0 then
                    self.actions[self.action_ids['down']](self)
                else
                    self.actions[self.action_ids['up']](self)
                end
            else
                -- move in x
                if rel_x[self.closest_agent] > 0 then
                    self.actions[self.action_ids['right']](self)
                else
                    self.actions[self.action_ids['left']](self)
                end
            end
        end
    end
    -- reduce cooldown
    self.cooldown = math.max(self.cooldown - 1, 0)
end

function StarEnemy:clone()
    local attr = {}
    attr._speed = self.speed
    attr._range = self.range
    attr.type = 'StarEnemy'
    attr.name = self.name
    attr.loc.x = self.attr.loc.x
    attr.loc.y = self.attr.loc.y
    local e = self.new(attr, self.maze)
    e.closest_agent = self.closest_agent
    e.range_closest_agent = self.range_closest_agent
    e.can_shoot = self.can_shoot
    e.counter = self.counter
    e.action_noise = self.action_noise
    e.health = self.health
    e.killed =  self.killed
    e.pMiss = self.pMiss
    e.cooldown = self.cooldown
    e.cooldown_max = self.cooldown_max
    e.range = self.range
    e.speed = self.speed
    return e
end

function StarEnemy:change_owner(maze)
    self.maze = maze
    self.map = maze.map
    self.cover_map = maze.cover_map
end
