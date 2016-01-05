-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local Bullet, parent = torch.class('Bullet','MazeItem')

function Bullet:__init(attr,maze)
    -- dummy object that exists for one time step
    self.maze = maze
    self.map = maze.map
    self.type = 'Bullet'
    self.name = attr.name
    self.attr = attr
    self.loc = self.attr.loc
    self.nactions = 0
    self.action_names = {}
    self.action_ids ={}
    self.actions ={}
    self.updateable = true

    self.killed = false
    self.lifespan = 0

    function self:is_reachable() return true end
end

function Bullet:update()
   if self.lifespan==0 then
      self.killed = true
      self.map:remove_item(self)
   end
   self.lifespan = self.lifespan - 1
end

function Bullet:clone()
    local attr = {}
    attr.type = 'Bullet'
    attr.name = self.name
    attr.loc = {}
    attr.loc.x = self.attr.loc.x
    attr.loc.y = self.attr.loc.y
    local e = self.new(attr, self.maze)
    e.killed = self.killed
    e.lifespan = self.lifespan
    return e
end

function Bullet:change_owner(maze)
    self.maze = maze
    self.map = maze.map
end
