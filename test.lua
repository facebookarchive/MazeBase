function get_prob_map(input, offy, offx, maze)
    local M = 32
    local prob = torch.Tensor(3, maze.map.height*M, maze.map.width*M):fill(0)
    for h = 1, g_opts.nhop do
        local mod
        if g_modules[h]['prob_conv'] then
            mod = g_modules[h]['prob_conv']
        else
            mod = g_modules[h]['prob']
        end
        for i = 1, g_opts.memsize do
            for j = 1, input:size(2) do
                if g_ivocabx[input[i][j]] ~= nil then
                    local x = offx + g_ivocabx[input[i][j]]
                    local y = offy + g_ivocaby[input[i][j]]
                    if g_ivocab[input[i][j]]:sub(1,1) == 'a' then
                        -- absolute location
                        x = g_ivocabx[input[i][j]]
                        y = g_ivocaby[input[i][j]]
                    end
                    prob[((h-1)%3)+1][{ {(y-1)*M+1,y*M}, {(x-1)*M+1,x*M} }]:add(mod.output[1][i])
                end
            end
        end
    end
    -- for h = 1, 3 do
    --     prob[h]:div(prob[h]:max())
    -- end
    return prob
end

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

        for i = 1, g_opts.nagents do
            local mem = input[2][i]:view(g_opts.memsize, g_opts.max_attributes)
            print('memory of agent', i)
            if g_opts.model == 'conv' or g_opts.model == 'conv_attend' then
                tensor_to_words(mem)
            else
                local nilnum = g_vocab['nil']
                local tmpmem = torch.Tensor(mem:size())
                local maxrow = 0
                for t = 1, mem:size(1) do
                    if mem[t][1] ~= nilnum then
                        maxrow = maxrow + 1
                        tmpmem[maxrow]:copy(mem[t])
                    end
                end
                if maxrow > 0 then
                    local smallmem = tmpmem:sub(1,maxrow,1,-1)
                    tensor_to_words(smallmem)
                end
            end
        end

        local out = g_model:forward(input)
        local action
        if g_opts.qlearn then
            local _, a = out:max(2)
            action = a
        else
            action = torch.multinomial(torch.exp(out[1]), 1)
        end
        for i = 1, g_opts.nagents do
            if active[i] == 1 then
                local agent = batch[1].agents[i]
                if g_opts.hand then
                    print('input action for agent', i)
                    local k = io.read()
                    if k == 'a' then
                        action[i][1] = agent.action_ids['left']
                    elseif k == 'd' then
                        action[i][1] = agent.action_ids['right']
                    elseif k == 'w' then
                        action[i][1] = agent.action_ids['up']
                    elseif k == 's' then
                        action[i][1] = agent.action_ids['down']
                    elseif k == 't' then
                        action[i][1] = agent.action_ids['toggle']
                    elseif k == '1' then
                        action[i][1] = agent.action_ids['shoot_enemy1']
                    elseif k == '2' then
                        action[i][1] = agent.action_ids['shoot_enemy2']
                    elseif k == '3' then
                        action[i][1] = agent.action_ids['shoot_enemy3']
                    elseif k == '4' then
                        action[i][1] = agent.action_ids['shoot_enemy4']
                    elseif k == '5' then
                        action[i][1] = agent.action_ids['shoot_enemy5']
                    end
                end
                print(i .. ' action: ' .. agent.action_names[action[i][1]])
                if g_opts.model == 'conv' or g_opts.model == 'conv_attend' then
                else
                    local mem = input[2][i]:view(g_opts.memsize, g_opts.max_attributes)
                    local prob = get_prob_map(mem, agent.loc.y, agent.loc.x, batch[1])
                    g_disp.image(prob:clamp(0,1), {win = 'agent' .. i .. g_opts.disp})
                end
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
