-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local GotoHiddenHelper, parent = torch.class('GotoHiddenHelper', 'OptsHelper')

function GotoHiddenHelper:__init(opts)
    parent.__init(self, opts)
    assert(self.ngoals[1]>0)
    if not self.nswitches then self.nswitches =torch.zeros(4) end
    if not self.ncolors then self.ncolors =torch.zeros(4) end
    self.generators.nswitches = self.nswitchesgen
    self.generators.ncolors = self.ncolorsgen
    self.generators.ngoals = self.ngoalsgen
end

function GotoHiddenHelper:ngoalsgen(lopts,name)
    local ngoals = torch.random(self.ngoals[1],self.ngoals[2])
    lopts.ngoals = ngoals
    return 'none'
end

function GotoHiddenHelper:nswitchesgen(lopts,name)
    lopts.nswitches = torch.random(self.nswitches[1],self.nswitches[2])
    return 'none'
end

function GotoHiddenHelper:ncolorsgen(lopts,name)
    lopts.ncolors = torch.random(self.ncolors[1],self.ncolors[2])
    return 'none'
end
