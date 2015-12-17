local GotoCardinal, parent = torch.class('GotoCardinal', 'MazeBase')
-- this game does an absolute goto.

function GotoCardinal:__init(opts, vocab)
    parent.__init(self, opts, vocab)
    self.has_supervision = false
    --add some switches as decoys.
    self.nswitches = opts.nswitches or 0
    self.ncolors = opts.ncolors or 1

    self:add_default_items()
    --should we make special corner block type?

--    self.enable_boundary = true


    for i = 1, self.nswitches do
        local c = torch.random(self.ncolors)
        self:place_item_rand({type = 'switch', _c = c, color = 'color' .. c, _cn = self.ncolors})
    end

    local dests = {'top','bottom','left','right'}
    self.dest = torch.random(4)
    local destination = dests[self.dest]
    local attr = {type = 'info'}
    attr[1] = 'obj1'
    attr[2] = 'go'
    attr[3] = destination
    self:add_item(attr)
end


function GotoCardinal:update()
    parent.update(self)
    self.finished = false
    local j = self.agent
    if self.dest == 1 and j.loc.y == 1 then
        self.finished = true
    end
    if self.dest == 2 and j.loc.y == self.map.height then
        self.finished = true
    end
    if self.dest == 3 and j.loc.x == 1 then
        self.finished = true
    end
    if self.dest == 4 and j.loc.x == self.map.width then
        self.finished = true
    end
end


function GotoCardinal:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end
--[==[
function GotoCardinal:get_supervision()
    local X = {}
    local H = self.map.height
    local W = self.map.width
    local ans = torch.zeros(H*W)
    local rew = torch.zeros(H*W)
    if not self.ds then
        local ds = paths.dofile('search.lua')
        self.ds = ds
    end
    self:flatten_cost_map()
    local acount = 0
    acount = self:search_move_and_update(self.ygoal,self.xgoal,X,ans,rew,acount)
    if acount == 0 then
        ans = nil
        rew = 0
    else
        ans = ans:narrow(1,1,acount)
        rew = rew:narrow(1,1,acount)
    end
    return X,ans,rew
end
--]==]
