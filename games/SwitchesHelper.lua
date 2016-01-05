-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local SwitchesHelper, parent = torch.class('SwitchesHelper', 'OptsHelper')

function SwitchesHelper:__init(opts)
    parent.__init(self, opts)
    assert(self.nswitches[1]>0)
    assert(self.ncolors[1]>0)
    -- explicit is if the environment decides the desired
    -- switch color or the agent gets to choose.
    self.generators.nswitches = self.nswitchesgen
    self.generators.ncolors = self.ncolorsgen
    self.generators.explicit_prob = self.explicitgen
end

function SwitchesHelper:nswitchesgen(lopts,name)
    lopts.nswitches = torch.random(self.nswitches[1],self.nswitches[2])
    return 'none'
end

function SwitchesHelper:ncolorsgen(lopts,name)
    lopts.ncolors = torch.random(self.ncolors[1],self.ncolors[2])
    return 'none'
end

function SwitchesHelper:explicitgen(lopts,name)
    if torch.uniform() < self.explicit_prob[2] then
        lopts.explicit = true
    else
        lopts.explicit = false
    end
    return 'none'
end
