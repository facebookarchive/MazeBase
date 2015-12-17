function test(g)
    local g = g or nil
    local dummy = torch.Tensor(g_opts.nagents, g_opts.hidsz):fill(0.1)
    local batch = batch_init(1)
    if g then batch[1] = g end
    local reward = 0
    for t = 1, g_opts.max_steps do
        g_disp.image(batch[1].map:to_image(), {win = 'maze' .. g_opts.disp})
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
    g_disp.image(batch[1].map:to_image(), {win = 'maze' .. g_opts.disp})
    print('reward:', reward)
    print('success:', batch_success(batch)[1])
end
