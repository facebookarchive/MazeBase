-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

function batch_init(size)
    local batch = {}
    for i = 1, size do
        batch[i] = new_game()
    end
    return batch
end

function batch_input(batch, active, t)
    if g_opts.model == 'conv' then
        return batch_input_conv(batch, active, t)
    elseif g_opts.model == 'mlp' then
        return batch_input_mlp(batch, active, t)
    end
    active = active:view(#batch, g_opts.nagents)
    local input = torch.Tensor(#batch, g_opts.nagents, g_opts.memsize, g_opts.max_attributes)
    input:fill(g_vocab['nil'])
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            if active[i][a] == 1 then
                g:to_sentence(input[i][a])
            end
        end
    end
    local dummy = torch.Tensor(#batch * g_opts.nagents, g_opts.hidsz):fill(0.1)
    input:resize(#batch * g_opts.nagents, g_opts.memsize * g_opts.max_attributes)
    return {dummy, input}
end

function batch_input_conv(batch, active, t)
    active = active:view(#batch, g_opts.nagents)
    local input = torch.Tensor(#batch, g_opts.nagents, g_opts.conv_sz, g_opts.conv_sz, g_opts.max_attributes)
    local context = torch.Tensor(#batch, g_opts.nagents, g_opts.memsize, g_opts.max_attributes)
    input:fill(g_vocab['nil'])
    context:fill(g_vocab['nil'])
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            local m = nil
            if active[i][a] == 1 then
                m = g:to_map()
            end
            if m then
                local dy = math.floor((g_opts.conv_sz - m:size(1)) / 2) + 1
                local dx = math.floor((g_opts.conv_sz - m:size(2)) / 2) + 1
                input[i][a]:narrow(1, dy, m:size(1)):narrow(2, dx, m:size(2)):copy(m)
                if g.items_bytype['info'] then
                    for j, e in pairs(g.items_bytype['info']) do
                        for k, w in pairs(e:to_sentence(0, 0, true)) do
                            context[i][a][j][k] = g_vocab[w]
                        end
                    end
                end
            end
        end
    end
    return {input:view(#batch * g_opts.nagents, -1), context:view(#batch * g_opts.nagents, -1)}
end

function batch_input_mlp(batch, active, t)
    -- total number of words in dictionary:
    local mapwords = g_opts.conv_sz*g_opts.conv_sz*g_opts.nwords
    local nilword = mapwords + g_opts.memsize*g_opts.nwords + 1
    active = active:view(#batch, g_opts.nagents)
    local input = torch.Tensor(#batch, g_opts.nagents, g_opts.memsize * g_opts.max_attributes)
    input:fill(nilword)
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            if active[i][a] == 1 then
                g:to_map_onehot(input[i][a])
            end
        end
    end
    return input:view(#batch * g_opts.nagents, -1)
end

function batch_act(batch, action, active)
    active = active:view(#batch, g_opts.nagents)
    action = action:view(#batch, g_opts.nagents)
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            if active[i][a] == 1 then
                g:act(action[i][a])
            end
        end
    end
end

function batch_reward(batch, active, is_last)
    active = active:view(#batch, g_opts.nagents)
    local reward = torch.Tensor(#batch, g_opts.nagents):zero()
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            if active[i][a] == 1 then
                reward[i][a] = g:get_reward(is_last)
            end
        end
    end
    return reward:view(-1)
end

function batch_update(batch, active)
    active = active:view(#batch, g_opts.nagents)
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            if active[i][a] == 1 then
                g:update()
                break
            end
        end
    end
end

function batch_active(batch)
    local active = torch.Tensor(#batch, g_opts.nagents):zero()
    for i, g in pairs(batch) do
        if (not g.sv_on) and (not g.qa_on) then
            for a = 1, g_opts.nagents do
                g.agent = g.agents[a]
                if g:is_active() then
                    active[i] = 1
                end
            end
        end
    end
    return active:view(-1)
end

function batch_success(batch)
    local success = torch.Tensor(#batch):fill(0)
    for i, g in pairs(batch) do
        if g:is_success() then
            success[i] = 1
        end
    end
    return success
end
