-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local SingleGoal, parent = torch.class('SingleGoal', 'MazeBase')

function SingleGoal:__init(opts, vocab)
    parent.__init(self, opts, vocab)
    self:add_default_items()
    self.goal = self:place_item_rand({type = 'goal'})
end

function SingleGoal:update()
    parent.update(self)
    if not self.finished then
        if self.goal.loc.y == self.agent.loc.y and self.goal.loc.x == self.agent.loc.x then
            self.finished = true
        end
    end
end

function SingleGoal:get_reward()
    if self.finished then
        return -self.costs.goal
    else
        return parent.get_reward(self)
    end
end
