if not g_opts then g_opts = {} end

g_opts.multigames = {}
-------------------
--some shared RangeOpts
--current min, current max, min max, max max, increment
local mapH = torch.Tensor{5,10,5,10,1}
local mapW = torch.Tensor{5,10,5,10,1}
--local blockspct = torch.Tensor{0,.2,0,.2,.01}
--local waterpct = torch.Tensor{0,.2,0,.2,.01}
local blockspct = torch.Tensor{0,.10,0,.2,.01}
local waterpct = torch.Tensor{0,.10,0,.2,.01}

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
sso.costs.BumpEnemy = 1
sso.costs.pushableblock = 1000
---------------------
sso.crumb_action = 0
sso.push_action = 0
sso.flag_visited = 1
sso.enable_boundary = 0
sso.enable_corners = 0

-------------------------------------------------------
-- MultiGoals:
local MultiGoalsRangeOpts = {}
MultiGoalsRangeOpts.mapH = mapH:clone()
MultiGoalsRangeOpts.mapW = mapW:clone()
MultiGoalsRangeOpts.blockspct = blockspct:clone()
MultiGoalsRangeOpts.waterpct = waterpct:clone()
MultiGoalsRangeOpts.ngoals = torch.Tensor{1,1,3,6,1}
MultiGoalsRangeOpts.ngoals_active = torch.Tensor{1,1,1,3,1}

local MultiGoalsStaticOpts = {}
for i,j in pairs(sso) do MultiGoalsStaticOpts[i] = j end


MultiGoalsOpts ={}
MultiGoalsOpts.RangeOpts = MultiGoalsRangeOpts
MultiGoalsOpts.StaticOpts = MultiGoalsStaticOpts

g_opts.multigames.MultiGoals = MultiGoalsOpts

return g_opts
