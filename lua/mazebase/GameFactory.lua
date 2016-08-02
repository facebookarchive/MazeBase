-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local GameFactory = torch.class('GameFactory')

function GameFactory:__init(opts,vocab,games,helpers)
    self.glist = {}
    self.iglist = {}
    self.games = {}
    self.helpers = {}
    self.vocab = vocab
    local count = 0
    local mg = opts.multigames
    for i,j in pairs(mg) do
        count = count + 1
        self.glist[count] = i
        self.iglist[i] =count
        --this is the class for the game i:
        self.games[i] = games[i]
        -- and an instantiated opts helper:
        self.helpers[i] = helpers[i](j)
    end
    self.ngames = count
    if not opts.play_probabilities then
        self.probs = torch.ones(self.ngames)
    else
    end
end

function GameFactory:init_game(gname)
     local gopts = self.helpers[gname]:generate_gameopts()
    local g = self.games[gname](gopts,self.vocab)
    return g
end

function GameFactory:init_random_game()
    local n = torch.multinomial(self.probs,1)[1]
    local gname = self.glist[n]
    local gopts = self.helpers[gname]:generate_gameopts()
    local g = self.games[gname](gopts,self.vocab)
    return g
end

function GameFactory:check_state(gname)
    return self.helpers[gname]:check_state()
end

function GameFactory:unfreeze(gname)
    self.helpers[gname]:unfreeze()
end

function GameFactory:freeze(gname)
    self.helpers[gname]:freeze()
end

function GameFactory:easier(gname)
    self.helpers[gname]:easier_random()
end

function GameFactory:harder(gname)
    self.helpers[gname]:harder_random()
end

function GameFactory:easiest(gname)
    self.helpers[gname]:easiest()
end

function GameFactory:hardest(gname)
    self.helpers[gname]:hardest()
end

function GameFactory:collect_result(gname,r)
    -- if r == 1 adds 1 to the success counter
    -- and the total counter
    -- if r == 0 adds 1 to the total counter
    self.helpers[gname]:collect_result(r)
end

function GameFactory:reset_counters(gname)
    self.helpers[gname]:reset_counters(gname)
end

function GameFactory:count(gname)
    return self.helpers[gname].count
end

function GameFactory:total_count(gname)
    return self.helpers[gname].total_count
end

function GameFactory:success_percent(gname)
    local pct = self.helpers[gname].success_count
    pct = pct/math.max(self.helpers[gname].count)
    return pct
end
