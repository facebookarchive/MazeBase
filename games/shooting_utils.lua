-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local S = {}

local function bresenham(y0,x0,y1,x1)
    -- computes the points on a grid on the line
    --between y0,x0 and y1, x1
    local dy = y1 - y0
    local dx = x1 - x0
    local sdx = 0
    local sdy = 0
    if math.abs(dy) > 0 then
        sdy = dy/math.abs(dy)
    end
    if math.abs(dx) > 0 then
        sdx = dx/math.abs(dx)
    end
    local er = 0
    local maxcount = math.max(math.abs(dy),math.abs(dx))+ 1
    local line = torch.zeros(maxcount,2)
    local count = 0
    if math.abs(dx) > 0  and math.abs(dx) <= math.abs(dy) then
        local y = y0
        for x = x0,x1,sdx do
            er = er + math.abs(dy/dx)
            while er > .5 do
                er = er - 1
                count = count + 1
                line[count][1] = y
                line[count][2] = x
                y = y + sdy
                if count == maxcount then break end
            end
        end
    elseif math.abs(dy) > 0  and math.abs(dx) > math.abs(dy) then
        local x = x0
        for y = y0,y1,sdy do
            er = er + math.abs(dx/dy)
            while er > .5 do
                er = er - 1
                count = count  +1
                line[count][1] = y
                line[count][2] = x
                x = x + sdx
                if count == maxcount then break end
            end
        end
    elseif dy == 0 and math.abs(dx) >0 then
        for x = x0,x1,sdx do
            count = count + 1
            line[count][1] = y0
            line[count][2] = x
            if count == maxcount then break end
        end
    else
        for y = y0,y1,sdy do
            count = count + 1
            line[count][1] = y
            line[count][2] = x0
            if count == maxcount then break end
        end
    end
    return line
end

local function check_hittable(map,range,sy,sx,ey,ex)
    -- map[i][j] is 1 if there is a cover object there
    -- if no map, just checks range
    -- if no range, just checks if the line has no cover
    local rel_x = ex - sx
    local rel_y = ey - sy
    local line = bresenham(sy,sx,ey,ex)
    -- target within range???
    local range = range or 5000000
    if rel_x^2 + rel_y^2 > range^2 then
        return false,line
    end
    if map then
        for s = 1, line:size(1) do
            if map[line[s][1]][line[s][2]] == 1 then
                return false,line:sub(1,s)
            end
        end
    end
    return true,line
end
S.check_hittable = check_hittable

local function build_shoot_action(enemyName)
    local function shoot_action(self)
        local range = self.maze.agent_range or 1
        if self.cooldown == 0 then
            -- get enemy item
            local enemy = self.maze.item_byname[enemyName]
            if not enemy.killed then -- check it hasn't already been killed
                -- get relative positions of agent/enemy
                local sx =  self.loc.x
                local sy =  self.loc.y
                local ex =  enemy.loc.x
                local ey =  enemy.loc.y
                -- target hittable?
                local ha, l = check_hittable(self.maze.cover_map, range, sy, sx, ey, ex)
                    if ha then
                    -- if so, fire gun!
                        if not self.map.agent_shots then self.map.agent_shots = {} end
                        table.insert(self.map.agent_shots,l)
                        if (math.random() > self.pMiss) then
                        -- Hit!!!
                        enemy.health = math.max(enemy.health - 1, 0)
                    end
                end
            end
            self.cooldown = self.cooldown_max + 1
        end
    end
    return shoot_action
end

S.build_shoot_action = build_shoot_action

return S
