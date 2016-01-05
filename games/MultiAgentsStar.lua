-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local MultiAgentsStar, parent = torch.class('MultiAgentsStar', 'MazeBase')

local su = paths.dofile('shooting_utils.lua')

function MultiAgentsStar:__init(opts, vocab)
    parent.__init(self, opts, vocab)
    self.agent_range = opts.agent_range
    self.enemy_range = opts.enemy_range
    self.restrict_actions = true
    self.enemy_speed = opts.enemy_speed or 1
    if opts.restrict_actions == 0 then
        self.restrict_actions = false
    end
    -- Add StarEnemy to game
    -- hardcoded max of 5
    self.max_possible_enemies = 5
    self.eno = torch.randperm(self.max_possible_enemies)
    self.nenemy = opts.nenemy
    for i = 1, self.nenemy do
        local enemy = self:place_item_rand({_factory = StarEnemy, name = 'enemy' .. self.eno[i]})
        enemy.action_noise = opts.enemy_action_noise
        enemy.health = opts.enemy_health -- starting health. each hit from agent decreases by 1
        enemy.killed = false -- alive/dead
        enemy.pMiss = opts.enemy_pMiss -- change of shoot & miss
        enemy.cooldown = 0 -- current cooldown
        enemy.cooldown_max = opts.enemy_cooldown_max -- value after firing gun
        enemy.range = opts.enemy_range
        enemy.speed = opts.enemy_speed or 1
    end

    self:add_default_items()

    for _, agent in pairs(self.agents) do
        agent.pMiss = opts.agent_pMiss -- miss probability when shooting
        agent.cooldown = 0 -- current cooldown
        agent.cooldown_max = opts.agent_cooldown_max -- cooldown after shooting gun
        agent.health = opts.agent_health -- starting health
        agent.killed = false --alive to start with
    end
    if opts.cover_map == 1 then
        self.cover_map = torch.zeros(self.map.height,self.map.width)
        local bks = self.items_bytype['block']
        if bks then
            for i,j in pairs(bks) do
                self.cover_map[j.loc.y][j.loc.x] = 1
            end
        end
    end
    self:update_text()
    self:add_shoot_action()
end

function MultiAgentsStar:add_shoot_action()
    -- Get enemies in maze
    for _, agent in pairs(self.agents) do
        -- Loop over #, adding shoot action for each one and naming them
        for i = 1, self.nenemy do
            local eid = self.eno[i]
            local enemyName = 'enemy' .. eid
            agent:add_action('shoot_enemy' .. eid, su.build_shoot_action(enemyName))
        end
        if not self.restrict_actions then
            for i = self.nenemy + 1, self.max_possible_enemies do
                local enemyName = 'enemy' .. self.eno[i]
                agent:add_action('shoot_enemy' .. self.eno[i], function() return end )
            end
        end
    end
end

function MultiAgentsStar:update()
    self.map.enemy_shots_d = nil
    if self.map.enemy_shots then
        self.map.enemy_shots_d = {}
        for s = 1, #self.map.enemy_shots do
            self.map.enemy_shots_d[s] = self.map.enemy_shots[s]
        end
    end
    self.map.agent_shots_d = nil
    if self.map.agent_shots then
        self.map.agent_shots_d = {}
        for s = 1, #self.map.agent_shots do
            self.map.agent_shots_d[s] = self.map.agent_shots[s]
        end
    end
    self.map.enemy_shots = nil
    self.map.agent_shots = nil

    parent.update(self)
    self.enemies_alive = 0
    for _, enemy in ipairs(self.items_bytype['StarEnemy']) do
        if not enemy.killed then
            self.enemies_alive = self.enemies_alive + 1
        end
    end

    self.agents_alive = 0
    for _, agent in pairs(self.agents) do
        if not agent.killed then
            -- check to see if still alive?
            if agent.health == 0 then
                agent.killed = true
                agent.finished = true
                agent.attr._invisible = true
            else
                -- reduce cooldown for each agent
                agent.cooldown = math.max(agent.cooldown - 1, 0)
                if self.enemies_alive == 0 then
                    -- is all enemies dead then this agent is done....
                    agent.finished = true
                end
                self.agents_alive = self.agents_alive + 1
            end
        end
    end

    self:update_text()
end

function MultiAgentsStar:update_text()
    for _, agent in ipairs(self.agents) do
        agent.attr.health = 'health' .. agent.health
        agent.attr.cooldown = 'cooldown' .. agent.cooldown
    end
    for _, enemy in ipairs(self.items_bytype['StarEnemy']) do
        enemy.attr.health = 'health' .. enemy.health
        enemy.attr.cooldown = 'cooldown' .. enemy.cooldown
    end
end

function MultiAgentsStar:get_reward(is_last)
    if self.agent.killed then
        if not self.agent.killed_cost_paid then
            -- pay cost for getting killed
            -- (no cost for each individual hit though)
            self.agent.killed_cost_paid = true -- pay once
            return -self.costs.killed
        else
            return 0
        end
    else
        return parent.get_reward(self,is_last)
    end
end

function MultiAgentsStar:is_active()
    if self.agent.finished then
        return false
    else
        return true
    end
end

function MultiAgentsStar:is_success()
    if self.agents_alive > 0 and self.enemies_alive == 0 then
        return true
    else
        return false
    end
end
