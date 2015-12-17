function batch_init(size)
    local batch = {}
    for i = 1, size do
        local g = new_game()
        local r = torch.uniform()
        if g_opts.supervision_ratio > r and g.has_supervision then
            g.sv_on = true
            g.sv_inputs, g.sv_actions, g.sv_rewards = g:get_supervision()
        elseif g_opts.question_ratio > r - g_opts.supervision_ratio then
            local X, ans, gt
            if g_opts.babi then
                local M, S
                M, S, ans, gt = g_babi:get_story()
                X = torch.Tensor(M:size(1) + S:size(1), math.max(M:size(2), S:size(2)))
                X:fill(g_vocab['nil'])
                X[{ {1,M:size(1)}, {1,M:size(2)} }]:copy(M)
                X[{ {1+M:size(1),S:size(1)+M:size(1)}, {1,S:size(2)} }]:copy(S)
            else
                local gg
                X, ans, gg, gt = g_questions:random_question()
                g = gg
            end
            g.qa_on = true
            g.qa_input = X
            g.qa_ans = ans
            g.qa_type = gt
            g.qa_t = 1 -- when to ask
        end
        batch[i] = g
    end
    return batch
end

function batch_input(batch, active, t)
    if g_opts.model == 'conv' or g_opts.model == 'conv_attend' then
        return batch_input_conv(batch, active, t)
    elseif g_opts.model == 'conv_multihops' then
        return batch_input_conv_multihops(batch, active, t)
    elseif g_opts.model == 'linear' then
        return batch_input_linear(batch, active, t)
    elseif g_opts.model == 'linear_lut' then
        return batch_input_linear_lut(batch, active, t)
    end
    active = active:view(#batch, g_opts.nagents)
    local input = torch.Tensor(#batch, g_opts.nagents, g_opts.memsize, g_opts.max_attributes)
    input:fill(g_vocab['nil'])
    for i, g in pairs(batch) do
        if g.sv_on then
            if t <= #g.sv_inputs then
                local x = g.sv_inputs[t]
                input[i][1]:narrow(1, 1, x:size(1)):copy(x)
            end
        elseif g.qa_on then
            if t == 1 then
                local x = g.qa_input
                input[i][1]:narrow(1, 1, x:size(1)):copy(x)
            end
        else
            for a = 1, g_opts.nagents do
                g.agent = g.agents[a]
                if active[i][a] == 1 then
                    g:to_sentence(input[i][a])
                end
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
            if g.sv_on then
                if t <= #g.sv_inputs then
                    m = g.sv_inputs[t]
                end
            elseif g.qa_on then
                error('not supported')
            else
                if active[i][a] == 1 then
                    m = g:to_map()
                end
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

function batch_input_conv_multihops(batch, active, t)
    local x = batch_input_conv(batch, active, t)
    local dummy = torch.Tensor(#batch * g_opts.nagents, g_opts.hidsz):fill(0.1)
    return {dummy, x[2], x[1]}
end

function batch_input_linear(batch, active, t)
    active = active:view(#batch, g_opts.nagents)
    local input = torch.Tensor(#batch, g_opts.nagents, g_opts.conv_sz, g_opts.conv_sz, g_opts.nwords)
    local context = torch.Tensor(#batch, g_opts.nagents, g_opts.memsize, g_opts.nwords)
    input:fill(0)
    context:fill(0)
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            local m = nil
            if g.sv_on then
                if t <= #g.sv_inputs then
                    m = g.sv_inputs[t]
                end
            elseif g.qa_on then
                error('not supported')
            else
                if active[i][a] == 1 then
                    m = g:to_map_onehot()
                end
            end
            if m then
                local dy = math.floor((g_opts.conv_sz - m:size(1)) / 2) + 1
                local dx = math.floor((g_opts.conv_sz - m:size(2)) / 2) + 1
                input[i][a]:narrow(1, dy, m:size(1)):narrow(2, dx, m:size(2)):copy(m)
                if g.items_bytype['info'] then
                    for j, e in pairs(g.items_bytype['info']) do
                        for k, w in pairs(e:to_sentence(0, 0, true)) do
                            context[i][a][j][g_vocab[w]] = 1
                        end
                    end
                end
            end
        end
    end
    return {input:view(#batch * g_opts.nagents, -1), context:view(#batch * g_opts.nagents, -1)}
end


function batch_input_linear_lut(batch, active, t)
    -- total number of words in dictionary:
    -- g_opts.conv_sz*g_opts.conv.sz*g_opts.nwords + g_opts.memsize*g_opts.nwords + 1
    -- last is nil word
    local mapwords = g_opts.conv_sz*g_opts.conv_sz*g_opts.nwords
    local nilword = mapwords + g_opts.memsize*g_opts.nwords + 1
    local MAXS = g_opts.MAXS --max spatial length
    local MAXM = g_opts.MAXM --max context buffer length
    local memsize = g_opts.memsize -- max info items
    active = active:view(#batch, g_opts.nagents)
    local input = torch.Tensor(#batch, g_opts.nagents, MAXS + MAXM)
    input:fill(nilword)
    for i, g in pairs(batch) do
        for a = 1, g_opts.nagents do
            g.agent = g.agents[a]
            local m = nil
            if g.sv_on then
              error('not supported')
--                if t <= #g.sv_inputs then
--                    m = g.sv_inputs[t]
--                end
            elseif g.qa_on then
                error('not supported')
            else
                if active[i][a] == 1 then
                    m = g:to_map_onehot_lut()
                end
            end
            if m then
                local count = m:size(1)
                input[i][a]:narrow(1, 1, count):copy(m)
                if g.items_bytype['info'] then
                    for j, e in pairs(g.items_bytype['info']) do
                        for k, w in pairs(e:to_sentence(0, 0, true)) do
                            count = count + 1
                            input[i][a][count]=mapwords+(j-1)*g_opts.nwords+g_vocab[w]
                        end
                    end
                end
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
