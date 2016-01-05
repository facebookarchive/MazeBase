-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local GotoHelper, parent = torch.class('GotoHelper', 'OptsHelper')

function GotoHelper:__init(opts)
    parent.__init(self, opts)
    if not self.nswitches then self.nswitches =torch.zeros(4) end
    if not self.ncolors then self.ncolors =torch.zeros(4) end
    self.generators.nswitches = self.nswitchesgen
    self.generators.ncolors = self.ncolorsgen
end

function GotoHelper:nswitchesgen(lopts,name)
    lopts.nswitches = torch.random(self.nswitches[1],self.nswitches[2])
    return 'none'
end

function GotoHelper:ncolorsgen(lopts,name)
    lopts.ncolors = torch.random(self.ncolors[1],self.ncolors[2])
    return 'none'
end
