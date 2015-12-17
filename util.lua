function tensor_to_words(input, show_prob)
    for i = 1, input:size(1) do
        local line = i .. ':'
        for j = 1, input:size(2) do
            line = line .. '\t'  .. g_ivocab[input[i][j]]
        end
        if show_prob then
            for h = 1, g_opts.nhop do
                line = line .. '\t' .. string.format('%.2f', g_modules[h]['prob'].output[1][i])
            end
        end
        print(line)
    end
end

function rmsprop(opfunc, x, config, state)
    -- (0) get/update state
    local config = config or {}
    local state = state or config
    local lr = config.learningRate or 1e-2
    local alpha = config.alpha or 0.99
    local epsilon = config.epsilon or 1e-8

    -- (1) evaluate f(x) and df/dx
    local fx, dfdx = opfunc(x)

    -- (2) initialize mean square values and square gradient storage
    if not state.m then
      state.m = torch.Tensor():typeAs(x):resizeAs(dfdx):zero()
      state.tmp = torch.Tensor():typeAs(x):resizeAs(dfdx)
    end

    -- (3) calculate new (leaky) mean squared values
    state.m:mul(alpha)
    state.m:addcmul(1.0-alpha, dfdx, dfdx)

    -- (4) perform update
    state.tmp:sqrt(state.m):add(epsilon)
    x:addcdiv(-lr, dfdx, state.tmp)

    -- return x*, f(x) before optimization
    return x, {fx}
end

function g_update_param()
    g_paramdx:div(g_opts.nworker)
    if g_opts.max_grad_norm > 0 then
        if g_paramdx:norm() > g_opts.max_grad_norm then
            g_paramdx:div(g_paramdx:norm() / g_opts.max_grad_norm)
        end
    end
    if g_opts.optim == 'sgd' then
        g_paramx:add(g_paramdx:mul(-g_opts.lrate))
    elseif g_opts.optim == 'rmsprop' then
        local f = function(x) return g_paramx, g_paramdx end
        local config = {
           learningRate = g_opts.lrate,
           alpha = g_opts.beta,
           epsilon = g_opts.eps
        }
        rmsprop(f, g_paramx, config, g_rmsprop_state)
    else
        error('wrong optim')
    end
    if g_opts.nil_zero == 1 and g_opts.model == 'memnn' then
        g_modules['A_LT'].data.module.weight[g_vocab['nil']]:zero()
        g_modules['B_LT'].data.module.weight[g_vocab['nil']]:zero()
    end
    if g_opts.model == 'linear_lut' then
        local mapwords = g_opts.conv_sz*g_opts.conv_sz*g_opts.nwords
        local nilword = mapwords + g_opts.memsize*g_opts.nwords + 1
        if g_modules.atab then g_modules.atab.weight[nilword]:zero() end
        if g_modules.btab then g_modules.btab.weight[nilword]:zero() end
    end
end

function g_load_model()
    if g_opts.load ~= '' then
        if paths.filep(g_opts.load) == false then
            print('WARNING: Failed to load from ' .. g_opts.load)
            return
        end
        local f = torch.load(g_opts.load)
        g_paramx:copy(f.paramx)
        g_log = f.log
        g_plot_stat = {}
        for i = 1, #g_log do
            g_plot_stat[i] = {g_log[i].epoch, g_log[i].reward, g_log[i].success, g_log[i].bl_cost}
        end
        if f['rmsprop_state'] then g_rmsprop_state = f['rmsprop_state'] end
        print('model loaded from ', g_opts.load)
    end
end

function g_save_model()
    if g_opts.save ~= '' then
        f = {opts=g_opts, paramx=g_paramx, log=g_log}
        if g_rmsprop_state then f['rmsprop_state'] = g_rmsprop_state end
        torch.save(g_opts.save, f)
        print('model saved to ', g_opts.save)
    end
end
