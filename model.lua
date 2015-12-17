require('nn')
require('fbnn')
require('nngraph')

local LookupTable = nn.LookupTable

local function share(name, mod)
    if g_shareList[name] == nil then g_shareList[name] = {} end
    table.insert(g_shareList[name], mod)
end

local function nonlin()
    if g_opts.nonlin == 'tanh' then
        return nn.Tanh()
    elseif g_opts.nonlin == 'relu' then
        return nn.ReLU()
    elseif g_opts.nonlin == 'none' then
        return nn.Identity()
    else
        error('wrong nonlin')
    end
end

local function build_lookup_bow(input, context, hop)
    local A_LT = LookupTable(g_opts.nwords, g_opts.hidsz)(context)
    share('A_LT', A_LT)
    g_modules['A_LT'] = A_LT
    local A_V = nn.View(-1, g_opts.max_attributes, g_opts.hidsz):setNumInputDims(2)(A_LT)
    local Ain = nn.Sum(3)(A_V)

    local B_LT = LookupTable(g_opts.nwords, g_opts.hidsz)(context)
    share('B_LT', B_LT)
    g_modules['B_LT'] = B_LT
    local B_V = nn.View(-1, g_opts.max_attributes, g_opts.hidsz):setNumInputDims(2)(B_LT)
    local Bin = nn.Sum(3)(B_V)

    local hid3dim = nn.View(1, -1):setNumInputDims(1)(input)
    local MMaout = nn.MM(false, true)
    local Aout = MMaout({hid3dim, Ain})
    local Aout2dim = nn.View(-1):setNumInputDims(2)(Aout)
    local P = nn.SoftMax()(Aout2dim)
    g_modules[hop]['prob'] = P.data.module
    local probs3dim = nn.View(1, -1):setNumInputDims(1)(P)
    local MMbout = nn.MM(false, false)
    return MMbout({probs3dim, Bin})
end

local function build_memory(input, context)
    local hid = {}
    hid[0] = input

    for h = 1, g_opts.nhop do
        g_modules[h] = {}
        local Bout = build_lookup_bow(hid[h-1], context, h)
        local C = nn.LinearNB(g_opts.hidsz, g_opts.hidsz)(hid[h-1])
        share('proj', C)
        local D = nn.CAddTable()({C, Bout})
        hid[h] = nonlin()(D)
    end
    return hid
end

function build_conv(input)
    local out_dim
    local d = g_opts.conv_sz

    local conv1 = nn.SpatialConvolution(g_opts.hidsz, g_opts.convdim, 3, 3, 1, 1)(input)
    share('conv1', conv1)
    local nonl1 = nonlin()(conv1)
    d = d - 2

    if d > 13 then
        nonl1 = nn.SpatialMaxPooling(2, 2, 2, 2)(nonl1)
        d = math.floor(d / 2)
    end

    local conv2 = nn.SpatialConvolution(g_opts.convdim, g_opts.convdim, 3, 3, 1, 1)(nonl1)
    share('conv2', conv2)
    local nonl2 = nonlin()(conv2)
    d = d - 2

    if d > 7 then
        nonl2 = nn.SpatialMaxPooling(2, 2, 2, 2)(nonl2)
        d = math.floor(d / 2)
    end

    local conv3 = nn.SpatialConvolution(g_opts.convdim, g_opts.convdim, 3, 3, 1, 1)(nonl2)
    share('conv3', conv3)
    local nonl3 = nonlin()(conv3)
    d = d - 2
    assert(d > 1 and d < 6)

    out_dim = d * d * g_opts.convdim
    local fc0 = nn.View(out_dim):setNumInputDims(3)(nonl3)
    local fc1 = nn.Linear(out_dim, g_opts.hidsz)(fc0)
    share('fc1', fc1)
    return nonlin()(fc1)
end

local function build_lookup_conv(input, context, hop)
    local A_LT_conv = LookupTable(g_opts.nwords, g_opts.hidsz)(context)
    share('A_LT_conv', A_LT_conv)
    local A_V = nn.View(-1, g_opts.max_attributes, g_opts.hidsz):setNumInputDims(2)(A_LT_conv)
    local Ain = nn.Sum(3)(A_V)

    local B_LT_conv = LookupTable(g_opts.nwords, g_opts.hidsz)(context)
    share('B_LT_conv', B_LT_conv)
    local B_V = nn.View(-1, g_opts.max_attributes, g_opts.hidsz):setNumInputDims(2)(B_LT_conv)
    local Bin = nn.Sum(3)(B_V)

    local hid3dim = nn.View(1, -1):setNumInputDims(1)(input)
    local MMaout = nn.MM(false, true)
    local Aout = MMaout({hid3dim, Ain})
    local Aout2dim = nn.View(-1):setNumInputDims(2)(Aout)
    local P = nn.SoftMax()(Aout2dim)
    g_modules[hop]['prob_conv'] = P.data.module

    local attention = nn.Replicate(g_opts.hidsz, 2, 1)(P)
    local in_attend = nn.CMulTable()({Bin, attention})
    local in_attend2 = nn.View(g_opts.conv_sz, g_opts.conv_sz, g_opts.hidsz):setNumInputDims(2)(in_attend)
    local in_conv = nn.Transpose({2,4})(in_attend2)
    local conv_out = build_conv(in_conv)
    return conv_out
end

local function build_memory_conv(input, context, context_conv)
    local hid = {}
    hid[0] = input
    for h = 1, g_opts.nhop do
        g_modules[h] = {}
        local Bout = build_lookup_bow(hid[h-1], context, h)
        local Bout_conv = build_lookup_conv(hid[h-1], context_conv, h)
        local C = nn.LinearNB(g_opts.hidsz, g_opts.hidsz)(hid[h-1])
        share('proj', C)
        local D = nn.CAddTable()({C, Bout, Bout_conv})
        hid[h] = nonlin()(D)
    end
    return hid
end

local function build_model_memnn()
    local input = nn.Identity()()
    local context = nn.Identity()()
    local hid = build_memory(input, context)
    return {input, context}, hid[#hid]
end

local function build_model_conv()
    local input = nn.Identity()()
    local context = nn.Identity()()

    -- process 2D spatial information
    local in_emb = LookupTable(g_opts.nwords, g_opts.hidsz)(input)
    local in_A = nn.View(-1, g_opts.max_attributes, g_opts.hidsz):setNumInputDims(2)(in_emb)
    local in_bow = nn.Sum(3)(in_A)
    local in_bow2d = nn.View(g_opts.conv_sz, g_opts.conv_sz, g_opts.hidsz):setNumInputDims(2)(in_bow)
    local in_conv = nn.Transpose({2,4})(in_bow2d)

    if g_opts.conv_nonlin == 1 then
        in_conv = nonlin()(in_conv)
    end

    local conv_out = build_conv(in_conv)

    local cont_emb2d = LookupTable(g_opts.nwords, g_opts.hidsz)(context)
    local cont_emb = nn.View(-1, g_opts.max_attributes, g_opts.hidsz):setNumInputDims(2)(cont_emb2d)
    local cont_bow = nn.Sum(3)(cont_emb) -- sum over attributes
    local cont_fc = nn.View(-1):setNumInputDims(2)(cont_bow)

    if g_opts.conv_nonlin == 1 then
        cont_fc = nonlin()(cont_fc)
    end

    local cont_out = nonlin()(nn.Linear(g_opts.memsize * g_opts.hidsz, g_opts.hidsz)(cont_fc))

    local output = nonlin()(nn.CAddTable()({
        nn.Linear(g_opts.hidsz, g_opts.hidsz)(conv_out),
        nn.Linear(g_opts.hidsz, g_opts.hidsz)(cont_out)
        }))
    return {input, context}, output
end

function g_build_model()
    if g_opts.model == 'linear' then
        return g_build_model_linear()
    end
    if g_opts.model == 'linear_lut' then
        return g_build_model_linear_lut()
    end
    local input, output
    g_shareList = {}
    g_modules = {}
    if g_opts.model == 'memnn' then
        input, output = build_model_memnn()
    elseif g_opts.model == 'conv' then
        input, output = build_model_conv()
    else
        error('wrong model name')
    end

    local hid_act = nonlin()(nn.Linear(g_opts.hidsz, g_opts.hidsz)(output))
    local action = nn.Linear(g_opts.hidsz, g_opts.nactions)(hid_act)
    local model
    if g_opts.qlearn then
        model = nn.gModule(input, {action})
    else
        local action_prob = nn.LogSoftMax()(action)
        local hid_bl = nonlin()(nn.Linear(g_opts.hidsz, g_opts.hidsz)(output))
        local baseline = nn.Linear(g_opts.hidsz, 1)(hid_bl)
        if g_opts.question_ratio > 0 then
            -- Add a head for question answers
            local answers = nn.LogSoftMax()(nn.Linear(g_opts.hidsz, g_opts.nwords)(hid_act))
            model = nn.gModule(input, {action_prob, baseline, answers})
        else
            model = nn.gModule(input, {action_prob, baseline})
        end
    end

    -- IMPORTANT! do weight sharing after model is in cuda
    for _, l in pairs(g_shareList) do
        if #l > 1 then
            local m1 = l[1].data.module
            for j = 2,#l do
                local m2 = l[j].data.module
                m2:share(m1,'weight','bias','gradWeight','gradBias')
            end
        end
    end
    return model
end

function g_build_model_linear()
    local input = nn.Identity()()
    local context = nn.Identity()()
    g_modules = {}
    local action1 = nn.Linear(g_opts.conv_sz * g_opts.conv_sz * g_opts.nwords, g_opts.nactions)(input)
    local action2 = nn.Linear(g_opts.memsize * g_opts.nwords, g_opts.nactions)(context)
    local action = nn.CAddTable()({ action1, action2})
    local baseline1 = nn.Linear(g_opts.conv_sz * g_opts.conv_sz * g_opts.nwords, 1)(input)
    local baseline2 = nn.Linear(g_opts.memsize * g_opts.nwords, 1)(context)
    local baseline = nn.CAddTable()({ baseline1, baseline2})
    local action_prob = nn.LogSoftMax()(action)
    local model = nn.gModule({input, context}, {action_prob, baseline})
    return model
end

function g_build_model_linear_lut()
    local MH = g_opts.conv_sz
    local MW = g_opts.conv_sz
    local memsize = g_opts.memsize
    local na = g_opts.nactions
    local nwords = g_opts.nwords
    local input = nn.Identity()()
    local baseline, action

    g_modules = {}

    local in_dim = MH*MW*nwords + memsize*nwords + 1
    if g_opts.starcraft then
        in_dim = nwords * g_opts.nwords_loc + 1 -- for nil word
    end

    if g_opts.linear_lut_two_layer or g_opts.linear_lut_three_layer then
        local a = nn.Sequential()
        local atab = nn.LookupTable(in_dim, g_opts.hidsz)
        g_modules.atab = atab
        a:add(atab)
        a:add(nn.Sum(2))
        a:add(nn.Add(g_opts.hidsz)) -- need bias maybe
        a:add(nonlin())
        if g_opts.linear_lut_three_layer then
            a:add(nn.Linear(g_opts.hidsz, g_opts.hidsz))
            a:add(nonlin())
        end
        local hidstate = a(input)

        action = nn.Linear(g_opts.hidsz, na)(hidstate)
        baseline = nn.Linear(g_opts.hidsz, 1)(hidstate)
    else
        local a = nn.Sequential()
        local atab = nn.LookupTable(in_dim, na)
        g_modules.atab = atab
        a:add(atab)
        a:add(nn.Sum(2))
        action = a(input)

        local btab = nn.LookupTable(in_dim,1)
        g_modules.btab = btab
        local b = nn.Sequential()
        b:add(btab)
        b:add(nn.Sum(2))
        baseline = b(input)
    end
    local action_prob = nn.LogSoftMax()(action)

    local model = nn.gModule({input}, {action_prob, baseline})
    return model
end

function g_init_model()
    g_model = g_build_model()
    g_paramx, g_paramdx = g_model:getParameters()
    if g_opts.init_std > 0 then
        g_paramx:normal(0, g_opts.init_std)
    end
    g_bl_loss = nn.MSECriterion()
    g_sv_cost = nn.ClassNLLCriterion()
end
