-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local CondGoalsHelper, parent = torch.class('CondGoalsHelper', 'OptsHelper')

function CondGoalsHelper:__init(opts)
    parent.__init(self, opts)
    assert(self.ngoals[1]>0)
    assert(self.ncolors[1]>0)
    self.generators.ngoals = self.ngoalsgen
    self.generators.ncolors = self.ncolorsgen
end
function CondGoalsHelper:ngoalsgen(lopts,name)
    local ngoals = torch.random(self.ngoals[1],self.ngoals[2])
    lopts.ngoals = ngoals
    return 'none'
end


function CondGoalsHelper:ncolorsgen(lopts,name)
    local ncolors = torch.random(self.ncolors[1],self.ncolors[2])
    lopts.ncolors = ncolors
    return 'none'
end
