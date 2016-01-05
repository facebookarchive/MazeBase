-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local MultiGoalsHelper, parent = torch.class('MultiGoalsHelper', 'OptsHelper')

function MultiGoalsHelper:__init(opts)
    parent.__init(self, opts)
    self.generators.ngoals = self.ngoalsgen
    self.generators.ngoals_active = self.ngoals_activegen
end

function MultiGoalsHelper:ngoalsgen(lopts,name)
    local ngoals = torch.random(self.ngoals[1],self.ngoals[2])
    lopts.ngoals = ngoals
    return 'none'
end

function MultiGoalsHelper:ngoals_activegen(lopts,name)
    if not lopts.ngoals then return 'ngoals' end
    local nga = torch.random(self.ngoals_active[1],self.ngoals_active[2])
    nga = math.min(nga, lopts.ngoals)
    lopts.ngoals_active = math.max(nga,1)
    return 'none'
end
