-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

function test()
    local dummy = torch.Tensor(g_opts.nagents, g_opts.hidsz):fill(0.1)
    local batch = batch_init(1)
    local reward = 0
    for t = 1, g_opts.max_steps do
        if g_disp then
            g_disp.image(batch[1].map:to_image(), {win = 'maze' .. g_opts.disp})
        end
        local active = batch_active(batch)
        if active:sum() == 0 then break end
        local stat = '[' .. t .. ']\t'
        local input = batch_input(batch, active, t)

        local out = g_model:forward(input)
        local action = torch.multinomial(torch.exp(out[1]), 1)
        for i = 1, g_opts.nagents do
            if active[i] == 1 then
                local agent = batch[1].agents[i]
                print(i .. ' action: ' .. agent.action_names[action[i][1]])
            end
        end
        batch_act(batch, action:view(-1), active)
        batch_update(batch, active)
        local r = batch_reward(batch, active,t == g_opts.max_steps):sum()
        reward = reward + r
        print('Reward: ', r)
        print('Overall reward: ',reward)
        print(stat)
        os.execute('sleep 0.2')
    end
    if g_disp then
        g_disp.image(batch[1].map:to_image(), {win = 'maze' .. g_opts.disp})
    end
    print('reward:', reward)
    print('success:', batch_success(batch)[1])
end
