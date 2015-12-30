-- Copyright (c) 2016-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local function init()
    require('xlua')
    paths.dofile('util.lua')
    paths.dofile('model.lua')
    paths.dofile('train.lua')
    paths.dofile('test.lua')
    paths.dofile('games/init.lua')
    torch.setdefaulttensortype('torch.FloatTensor')
end

local function init_threads()
    print('starting ' .. g_opts.nworker .. ' workers')
    local threads = require('threads')
    threads.Threads.serialization('threads.sharedserialize')
    local workers = threads.Threads(g_opts.nworker, init)
    workers:specific(true)
    for w = 1, g_opts.nworker do
        workers:addjob(w,
            function(opts_orig, vocab_orig)
                g_opts = opts_orig
                g_vocab = vocab_orig
                g_init_model()
                g_init_game()
            end,
            function() end,
            g_opts, g_vocab
        )
    end
    workers:synchronize()
    return workers
end

init()

local cmd = torch.CmdLine()
-- model parameters
cmd:option('--hidsz', 20)
cmd:option('--nonlin', 'tanh', 'tanh | relu | none')
cmd:option('--model', 'memnn', 'mlp | conv | memnn')
cmd:option('--init_std', 0.2)
cmd:option('--max_attributes', 6)
-- MLP model
cmd:option('--nlayers', 2)
-- conv model
cmd:option('--convdim', 20)
cmd:option('--conv_sz', 19)
cmd:option('--conv_nonlin', 0) -- add nonlin after LUT
-- memnn model
cmd:option('--memsize', 20)
cmd:option('--nhop', 3)
-- game parameters
cmd:option('--nagents', 1)
cmd:option('--nactions', 11)
cmd:option('--max_steps', 20)
cmd:option('--games_config_path', 'games/config/game_config.lua')
cmd:option('--game', '')
-- training parameters
cmd:option('--optim', 'rmsprop', 'rmsprop | sgd')
cmd:option('--nbatches', 100)
cmd:option('--lrate', 1e-3)
cmd:option('--alpha', 0.03) -- coeff of baseline cost
cmd:option('--batch_size', 32)
cmd:option('--epochs', 100)
cmd:option('--nworker', 16)
cmd:option('--max_grad_norm', 0)
-- for rmsprop
cmd:option('--beta', 0.97)
cmd:option('--eps', 1e-6)
--other
cmd:option('--save', '')
cmd:option('--load', '')
g_opts = cmd:parse(arg or {})
print(g_opts)

g_init_vocab()
if g_opts.nworker > 1 then
    g_workers = init_threads()
end

g_log = {}
if g_opts.optim == 'rmsprop' then g_rmsprop_state = {} end
g_init_model()
g_load_model()
g_init_game()

train(g_opts.epochs)
g_save_model()
