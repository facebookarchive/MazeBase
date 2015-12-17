local Bullet, parent = torch.class('Bullet','MazeItem')

--todo: attr._destructible

function Bullet:__init(attr,maze)
    -- dummy object that exists for one time step
    self.maze = maze
    self.map = maze.map
    self.type = 'Bullet'
    self.name = attr.name
    self.attr = attr
    self.loc = self.attr.loc
    self.nactions = 0
   -- why does bullet have an action list?
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
--      print('Bullet at ('..self.loc.x..','..self.loc.y..') removed!')
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
