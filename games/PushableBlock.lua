local PushableBlock, parent = torch.class('PushableBlock','MazeItem')

--todo: attr._destructible

function PushableBlock:__init(attr,maze)
    self.maze = maze
    self.map = maze.map
    self.name = attr.name
    self.attr = attr
    -- todo?  two words?  some compositionality in language?
    self.type = 'pushableblock'
    self.attr[1] =  'pushable'
    self.attr[2] =  'block'
    self.loc = self.attr.loc
    self.updateable = true
    self.pushable = true
    self.pushed = false
    function self:is_reachable() return false end
    -- this function is called to move the item if
    -- the agent has pushed it.
    function self:move()
        -- note: it is up to the pushing agent
        -- to register its location in this item.
        local dx = self.loc.x - self.agent_x
        local dy = self.loc.y - self.agent_y
        assert(math.abs(dx) < 2)
        assert(math.abs(dy) < 2)
        local nx = self.loc.x + dx
        local ny = self.loc.y + dy
        if self.map:is_loc_reachable(ny,nx) then
            self.map:remove_item(self)
            self.loc.y = ny
            self.loc.x = nx
            self.map:add_item(self)
        end
    end
    function PushableBlock:update()
        if self.pushed == true then self:move() end
        self.pushed = false
    end
end

function PushableBlock:clone()
    local attr = {}
    attr.name = self.name
    attr.loc = {}
    attr.loc.x = self.attr.loc.x
    attr.loc.y = self.attr.loc.y
    local e = self.new(attr, self.maze)
    e.updateable = self.updateable
    e.pushable = self.pushable
    e.pushed = self.pushed
    return e
end

function PushableBlock:change_owner(maze)
    self.maze = maze
    self.map = maze.map
end
