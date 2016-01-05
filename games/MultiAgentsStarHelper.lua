-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local MultiAgentsStarHelper, parent = torch.class('MultiAgentsStarHelper', 'OptsHelper')

function MultiAgentsStarHelper:__init(opts)
    parent.__init(self, opts)
    self.generators.nenemy = self.nenemiesgen
    self.generators.enemy_health = self.ehealthgen
    self.generators.enemy_speed = self.espeedgen
end


function MultiAgentsStarHelper:ehealthgen(lopts,name)
    if self.enemy_health then
        lopts.enemy_health= torch.random(self.enemy_health[1],self.enemy_health[2])
    else
        lopts.enemy_health = 1
    end
    return 'none'
end

function MultiAgentsStarHelper:nenemiesgen(lopts,name)
    if self.nenemy then
        lopts.nenemy= torch.random(self.nenemy[1],self.nenemy[2])
    else
        lopts.nenemy = 1
    end
    return 'none'
end

function MultiAgentsStarHelper:espeedgen(lopts,name)
    if self.enemy_speed then
        assert(self.enemy_speed[1] <= self.enemy_speed[2])
        local speed = torch.random(self.enemy_speed[1],self.enemy_speed[2])
        lopts.enemy_speed = -speed
    else
        lopts.enemy_speed = 1
    end
    return 'none'
end
