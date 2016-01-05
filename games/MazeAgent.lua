-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local MazeAgent, parent = torch.class('MazeAgent', 'MazeItem')

function MazeAgent:__init(attr, maze)
    attr.type = 'agent'
    parent.__init(self, attr)
    self.maze = maze
    self.map = maze.map

    -- List of possible actions and corresponding functions to execute
    self.action_names = {}  -- id -> name
    self.action_ids = {}    -- name -> id
    self.actions = {}       -- id -> func
    self.nactions = 0
    self:add_move_actions()
    self:add_toggle_action()
    if maze.crumb_action == 1 then
        self:add_breadcrumb_action()
    end
    if maze.push_action == 1 then
        self:add_push_actions()
    end
end

-- for basic MazeAgent, nothing is in attr except
-- loc, type, and name.
function MazeAgent:clone()
    local attr = {}
    attr.type = 'agent'
    attr.name = self.attr.name
    attr.loc = {}
    attr.loc.x = self.attr.loc.x
    attr.loc.y = self.attr.loc.y
    local e = self.new(attr,self.maze)
    return e
end

function MazeAgent:change_owner(maze)
    self.maze = maze
    self.map = maze.map
end

function MazeAgent:add_action(name, f)
    if not self.action_ids[name] then
        self.nactions = self.nactions + 1
        self.action_names[self.nactions] = name
        self.actions[self.nactions] = f
        self.action_ids[name] = self.nactions
    else
        self.actions[self.action_ids[name]] = f
    end
end

function MazeAgent:add_move_actions()
    self:add_action('up',
        function(self)
            if self.map:is_loc_reachable(self.loc.y - 1, self.loc.x) then
                self.map:remove_item(self)
                self.loc.y = self.loc.y - 1
                self.map:add_item(self)
            end
        end)
    self:add_action('down',
        function(self)
            if self.map:is_loc_reachable(self.loc.y + 1, self.loc.x) then
                self.map:remove_item(self)
                self.loc.y = self.loc.y + 1
                self.map:add_item(self)
            end
        end)
    self:add_action('left',
        function(self)
            if self.map:is_loc_reachable(self.loc.y, self.loc.x - 1) then
                self.map:remove_item(self)
                self.loc.x = self.loc.x - 1
                self.map:add_item(self)
            end
        end)
    self:add_action('right',
        function(self)
            if self.map:is_loc_reachable(self.loc.y, self.loc.x + 1) then
                self.map:remove_item(self)
                self.loc.x = self.loc.x + 1
                self.map:add_item(self)
            end
        end)
    self:add_action('stop',
        function(self)
            -- do nothing
        end)
end

function MazeAgent:add_toggle_action()
    self:add_action('toggle',
        function(self)
            local l = self.map.items[self.loc.y][self.loc.x]
            for _, e in ipairs(l) do
                if e.type == 'switch' then
                    local c = e.attr._c
                    c = (c % e.attr._cn) + 1
                    e.attr._c = c
                    e.attr.color = 'color' .. c
                end
            end
        end)
end

function MazeAgent:add_breadcrumb_action()
    self:add_action('breadcrumb',
        function(self)
            local e = {type='crumb'}
            self.maze:place_item(e, self.loc.y, self.loc.x)
        end)
end

function MazeAgent:add_push_actions()
    self:add_action('push_up',
        function(self)
            local y = self.loc.y
            local x = self.loc.x
            if self.map:is_loc_reachable(y - 2, x) then
                for i,j in pairs(self.map.items[y-1][x]) do
                    if j.pushable then
                        j.pushed = true
                        j.agent_y = y
                        j.agent_x = x
                    end
                end
            end
        end)
    self:add_action('push_down',
        function(self)
            local y = self.loc.y
            local x = self.loc.x
            if self.map:is_loc_reachable(y + 2, x) then
                for i,j in pairs(self.map.items[y+1][x]) do
                    if j.pushable then
                        j.pushed = true
                        j.agent_y = y
                        j.agent_x = x
                    end
                end
            end
        end)
    self:add_action('push_left',
        function(self)
            local y = self.loc.y
            local x = self.loc.x
            if self.map:is_loc_reachable(y, x - 2) then
                for i,j in pairs(self.map.items[y][x-1]) do
                    if j.pushable then
                        j.pushed = true
                        j.agent_y = y
                        j.agent_x = x
                    end
                end
            end
        end)

    self:add_action('push_right',
        function(self)
            local y = self.loc.y
            local x = self.loc.x
            if self.map:is_loc_reachable(y, x + 2) then
                for i,j in pairs(self.map.items[y][x+1]) do
                    if j.pushable then
                        j.pushed = true
                        j.agent_y = y
                        j.agent_x = x
                    end
                end
            end
        end)
end

-- Agents call this function to perform action
function MazeAgent:act(action_id)
    local f = self.actions[action_id]
    if f == nil then
       print('Available actions are: ')
       for k,v in pairs(self.actions) do
	  print(k)
       end
       error('Could not find action for action_id: ' .. action_id)
    end
    f(self)
end
