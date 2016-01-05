-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

if not g_opts then g_opts = {} end
g_opts.multigames = {}
-------------------
--some shared RangeOpts
--current min, current max, min max, max max, increment
local mapH = torch.Tensor{5,10,5,10,1}
local mapW = torch.Tensor{5,10,5,10,1}
local blockspct = torch.Tensor{0,.2,0,.2,.01}
local waterpct = torch.Tensor{0,.2,0,.2,.01}


-------------------
--some shared StaticOpts
local sso = {}
-------------- costs:
sso.costs = {}
sso.costs.goal = 0
sso.costs.empty = 0.1
sso.costs.block = 1000
sso.costs.water = 0.2
sso.costs.corner = 0
sso.costs.step = 0.1
---------------------
sso.crumb_action = 0
sso.flag_visited = 1
sso.enable_boundary = 0

-------------------------------------------------------
-- MultiGoals:
local MultiGoalsRangeOpts = {}
MultiGoalsRangeOpts.mapH = mapH:clone()
MultiGoalsRangeOpts.mapW = mapW:clone()
MultiGoalsRangeOpts.blockspct = blockspct:clone()
MultiGoalsRangeOpts.waterpct = waterpct:clone()
MultiGoalsRangeOpts.ngoals = torch.Tensor{2,5,3,6,1}
MultiGoalsRangeOpts.ngoals_active = torch.Tensor{1,3,1,3,1}

local MultiGoalsStaticOpts = {}
for i,j in pairs(sso) do MultiGoalsStaticOpts[i] = j end


MultiGoalsOpts ={}
MultiGoalsOpts.RangeOpts = MultiGoalsRangeOpts
MultiGoalsOpts.StaticOpts = MultiGoalsStaticOpts

g_opts.multigames.MultiGoals = MultiGoalsOpts


-------------------------------------------------------
-- CondGoals:
local CondGoalsRangeOpts = {}
CondGoalsRangeOpts.mapH = mapH:clone()
CondGoalsRangeOpts.mapW = mapW:clone()
CondGoalsRangeOpts.blockspct = blockspct:clone()
CondGoalsRangeOpts.waterpct = waterpct:clone()
CondGoalsRangeOpts.ngoals = torch.Tensor{2,5,3,6,1}
CondGoalsRangeOpts.ncolors = torch.Tensor{2,5,3,6,1}

local CondGoalsStaticOpts = {}
for i,j in pairs(sso) do CondGoalsStaticOpts[i] = j end


CondGoalsOpts ={}
CondGoalsOpts.RangeOpts = CondGoalsRangeOpts
CondGoalsOpts.StaticOpts = CondGoalsStaticOpts

g_opts.multigames.CondGoals = CondGoalsOpts


-------------------------------------------------------
-- Exclusion:
local ExclusionRangeOpts = {}
ExclusionRangeOpts.mapH = mapH:clone()
ExclusionRangeOpts.mapW = mapW:clone()
ExclusionRangeOpts.blockspct = blockspct:clone()
ExclusionRangeOpts.waterpct = waterpct:clone()
ExclusionRangeOpts.ngoals = torch.Tensor{2,5,3,6,1}
ExclusionRangeOpts.ngoals_active = torch.Tensor{1,3,1,3,0}

local ExclusionStaticOpts = {}
for i,j in pairs(sso) do ExclusionStaticOpts[i] = j end


ExclusionOpts ={}
ExclusionOpts.RangeOpts = ExclusionRangeOpts
ExclusionOpts.StaticOpts = ExclusionStaticOpts

g_opts.multigames.Exclusion = ExclusionOpts

-------------------------------------------------------
-- Switches:
local SwitchesRangeOpts = {}
SwitchesRangeOpts.mapH = mapH:clone()
SwitchesRangeOpts.mapW = mapW:clone()
SwitchesRangeOpts.blockspct = blockspct:clone()
SwitchesRangeOpts.waterpct = waterpct:clone()
SwitchesRangeOpts.nswitches = torch.Tensor{1,5,1,5,0}
SwitchesRangeOpts.ncolors = torch.Tensor{1,3,1,6,1}

local SwitchesStaticOpts = {}
for i,j in pairs(sso) do SwitchesStaticOpts[i] = j end


SwitchesOpts ={}
SwitchesOpts.RangeOpts = SwitchesRangeOpts
SwitchesOpts.StaticOpts = SwitchesStaticOpts

g_opts.multigames.Switches = SwitchesOpts

-------------------------------------------------------
-- LightKey:
local LightKeyRangeOpts = {}
LightKeyRangeOpts.mapH = mapH:clone()
LightKeyRangeOpts.mapW = mapW:clone()
LightKeyRangeOpts.blockspct = blockspct:clone()
LightKeyRangeOpts.waterpct = waterpct:clone()

local LightKeyStaticOpts = {}
for i,j in pairs(sso) do LightKeyStaticOpts[i] = j end

LightKeyOpts ={}
LightKeyOpts.RangeOpts = LightKeyRangeOpts
LightKeyOpts.StaticOpts = LightKeyStaticOpts

g_opts.multigames.LightKey = LightKeyOpts
return g_opts
