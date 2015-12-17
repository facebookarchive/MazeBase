local BumpEnemy, parent = torch.class('BumpEnemy','MazeItem')

--todo: attr._destructible

function BumpEnemy:__init(attr,maze)
    -- simple npc that moves around randomly
    self.maze = maze
    self.map = maze.map
    self.type = 'BumpEnemy'
    self.name = attr.name
    self.attr = attr
     self.loc = self.attr.loc
    self.nactions = 0
    self.action_names = {}
    self.action_ids ={}
    self.actions ={}
    self.updateable = true
    self:add_move_actions()
    function self:is_reachable() return true end
end

function BumpEnemy:add_action(name, f)
    if not self.action_ids[name] then
        self.nactions = self.nactions + 1
        self.action_names[self.nactions] = name
        self.actions[self.nactions] = f
        self.action_ids[name] = self.nactions
    else
        self.actions[self.action_ids[name]] = f
    end
end

function BumpEnemy:update()

   -- take random action
   local m = torch.random(5)
   f = self.actions[m]
   f(self)

end


function BumpEnemy:add_move_actions()
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

function BumpEnemy:clone()
    local attr = {}
    attr.type = 'BumpEnemy'
    attr.name = self.name
    attr.loc = {}
    attr.loc.x = self.attr.loc.x
    attr.loc.y = self.attr.loc.y
    local e = self.new(attr, self.maze)
    return e
end

function BumpEnemy:change_owner(maze)
    self.maze = maze
    self.map = maze.map
end
