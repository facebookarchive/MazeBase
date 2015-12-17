local ExclusionHelper, parent = torch.class('ExclusionHelper', 'OptsHelper')
--todo: deal with some parameters making it harder when smaller
function ExclusionHelper:__init(opts)
    parent.__init(self, opts)
    assert(self.ngoals[1]>0)
    self.generators.ngoals = self.ngoalsgen
    self.generators.ngoals_active = self.ngoals_activegen
end
function ExclusionHelper:ngoalsgen(lopts,name)
    local ngoals = torch.random(self.ngoals[1],self.ngoals[2])
    lopts.ngoals = ngoals
    return 'none'
end


function ExclusionHelper:ngoals_activegen(lopts,name)
    if not lopts.ngoals then return 'ngoals' end
    local nga = torch.random(self.ngoals_active[1],self.ngoals_active[2])
    nga = math.min(nga, lopts.ngoals-1)
    lopts.ngoals_active = math.max(nga,1)
    return 'none'
end
