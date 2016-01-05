-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local OptsHelper = torch.class('OptsHelper')

function OptsHelper:__init(opts)
    local count = 0
    self.dparams = {}
    self.idparams = {}
    for i,j in pairs(opts.RangeOpts) do
        --format:
        --current min, current max, min min, max max, increment
        count = count + 1
        self[i] = j:clone()
        self.dparams[count] = i
        self.idparams[i] = count
    end
    local scount = 0
    self.sparams = {}
    self.isparams = {}
    for i,j in pairs(opts.StaticOpts) do
        scount = scount + 1
        self[i] = j --this should not be a tensor
        self.sparams[scount] = i
        self.isparams[i] = count
    end
    self.ndparams = count
    self.nsparams = scount
    self.square = opts.square
    self.success_count = 0
    self.star_count = 0
    self.count = 0
    self.total_count = 0
    --register some generators:
    self.generators = {}
    self.generators.mapH = self.sizegen
    self.generators.mapW = self.sizegen
    self.generators.blockspct = self.nblocksgen
    self.generators.waterpct = self.nwatergen
    self.frozen = false
end

-- generators should return their dependencies, if they
-- are not met
function OptsHelper:sizegen(lopts,name)
    if name == 'mapH' then
        if self.square and lopts.map_width then
            lopts.map_height = lopts.map_width
        else
            local H = torch.random(self.mapH[1],self.mapH[2])
            lopts.map_height = H
        end
    elseif name == 'mapW'  then
        if self.square and lopts.map_height then
            lopts.map_width = lopts.map_height
        else
            local W = torch.random(self.mapW[1],self.mapW[2])
            lopts.map_width = W
        end
    end
    return 'none'
end

function OptsHelper:nblocksgen(lopts,name)
    if not lopts.map_height then return 'mapH' end
    if not lopts.map_width then return 'mapW' end
    if self.blockspct then
        local pctdiff = self.blockspct[2] - self.blockspct[1]
        local msize = lopts.map_height*lopts.map_width
        if self.enable_boundary == 1 then
            msize = (lopts.map_height-2)*(lopts.map_width-2)
        end
        local nb = torch.uniform()*pctdiff*msize
        nb = nb + self.blockspct[1]*msize
        nb = math.ceil(nb)
        lopts.nblocks = nb
    else
        lopts.nblocks = 0
    end
    return 'none'
end

function OptsHelper:nwatergen(lopts,name)
    if not lopts.map_height then return 'mapH' end
    if not lopts.map_width then return 'mapW' end
    if self.waterpct then
        local pctdiff = self.waterpct[2] - self.waterpct[1]
        local msize = lopts.map_height*lopts.map_width
        if self.enable_boundary == 1 then
            msize = (lopts.map_height-2)*(lopts.map_width-2)
        end
        local nw = torch.uniform()*pctdiff*msize
        nw = nw + self.waterpct[1]*msize
        nw = math.ceil(nw)
        lopts.nwater = nw
        lopts.water_risk_factor = 0
    else
        lopts.nwater = 0
        lopts.water_risk_factor = 0
    end
    return 'none'
end


function OptsHelper:generate_gameopts()
    -- this is cavalier about dependencies- will
    -- try to generate options in random order
    -- if an option has a dependency on another,
    -- will return that dep and try to add it
    -- it will give up after 1000 tries
    local numparams = #self.dparams
    local missing = torch.ones(numparams)
    local lopts = {}
    local s= torch.random(numparams)
    local dep
    local count =0
    while missing:max() == 1 do
        count = count+1
        local name = self.dparams[s]
        if self.generators[name] then
            dep = self.generators[name](self,lopts,name)
        else
            local p = torch.random(self[name][1],self[name][2])
            dep = 'none'
        end
        if dep == 'none' then
            missing[s] = 0
            if missing:max() > 0 then
                s = torch.multinomial(missing,1)[1]
            end
        else
            s = self.idparams[dep]
        end
        if count > 1000 then
            error('is there a circular dependency?')
        end
    end
    --now add the static options
    for s = 1, self.nsparams do
        local name = self.sparams[s]
        lopts[name] = self[name]
    end
    return lopts
end

function OptsHelper:harder_random()
    -- here:
    -- hardest just means the hardest possible selection
    -- gets hardest.  the easiest possible selection
    -- stays the same
    if self.frozen then return end
    local m = torch.random(#self.dparams)
    local name = self.dparams[m]
    self[name][2] = self[name][2] + self[name][5]
    self[name][2] = math.min(self[name][2],self[name][4])
end

function OptsHelper:easier_random()
    -- here:
    -- easier just means the hardest possible selection
    -- gets easier.  the easiest possible selection
    -- stays the same
    if self.frozen then return end
    local m = torch.random(#self.dparams)
    local name = self.dparams[m]
    self[name][2] = self[name][2] - self[name][5]
    self[name][2] = math.max(self[name][2],self[name][3])
end

function OptsHelper:collect_result(r)
    self.count = self.count + 1
    -- this one is never reset:
    self.total_count = self.total_count + 1
    if r>0 then
        self.success_count = self.success_count + 1
    end
    if r>1 then
        self.star_count = self.star_count + 1
    end
end

function OptsHelper:check_state()
    local hardest = true
    local easiest = true
    for s = 1, #self.dparams do
        local name = self.dparams[s]
        if self[name][2] < self[name][4] then
            hardest = false
        end
        if self[name][2] > self[name][3] then
            easiest = false
        end
    end
    if hardest then return 1 end
    if easiest then return -1 end
    return 0
end


function OptsHelper:hardest()
    -- here:
    -- hardest just means the hardest possible selection
    -- gets hardest.  the easiest possible selection
    -- stays the same
    if self.frozen then return end
    for s = 1, #self.dparams do
        local name = self.dparams[s]
        self[name][2] = self[name][4]
    end
end

function OptsHelper:easiest()
    -- here:
    -- hardest just means the hardest possible selection
    -- gets hardest.  the easiest possible selection
    -- stays the same
    if self.frozen then return end
    for s = 1, #self.dparams do
        local name = self.dparams[s]
        self[name][2] = self[name][3]
    end
end

function OptsHelper:freeze()
    self.frozen = true
end

function OptsHelper:unfreeze()
    self.frozen = false
end

function OptsHelper:reset_counters()
    self.success_count = 0
    self.star_count = 0
    self.count = 0
end
