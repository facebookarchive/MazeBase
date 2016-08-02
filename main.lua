-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

package.path = package.path .. ';lua/?/init.lua'
g_mazebase = require('mazebase')

local function init()
    require('xlua')
    paths.dofile('util.lua')
    paths.dofile('model.lua')
    paths.dofile('train.lua')
    paths.dofile('test.lua')
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
                package.path = package.path .. ';lua/?/init.lua'
                g_mazebase = require('mazebase')
                g_opts = opts_orig
                g_vocab = vocab_orig
                g_init_model()
                g_mazebase.init_game()
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
cmd:option('--hidsz', 20, 'the size of the internal state vector')
cmd:option('--nonlin', 'tanh', 'non-linearity type: tanh | relu | none')
cmd:option('--model', 'memnn', 'model type: mlp | conv | memnn')
cmd:option('--init_std', 0.2, 'STD of initial weights')
cmd:option('--max_attributes', 6, 'maximum number of attributes of each item')
cmd:option('--nlayers', 2, 'the number of layers in MLP')
cmd:option('--convdim', 20, 'the number of feature maps in convolutional layers')
cmd:option('--conv_sz', 19, 'spatial scope of the input to convnet and MLP')
cmd:option('--memsize', 100, 'size of the memory in MemNN')
cmd:option('--nhop', 3, 'the number of hops in MemNN')
-- game parameters
cmd:option('--nagents', 1, 'the number of agents')
cmd:option('--nactions', 10, 'the number of agent actions')
cmd:option('--max_steps', 20, 'force to end the game after this many steps')
cmd:option('--games_config_path', 'lua/mazebase/config/game_config.lua', 'configuration file for games')
cmd:option('--game', '', 'can specify a single game')
-- training parameters
cmd:option('--optim', 'rmsprop', 'optimization method: rmsprop | sgd')
cmd:option('--lrate', 1e-3, 'learning rate')
cmd:option('--max_grad_norm', 0, 'gradient clip value')
cmd:option('--alpha', 0.03, 'coefficient of baseline term in the cost function')
cmd:option('--epochs', 100, 'the number of training epochs')
cmd:option('--nbatches', 100, 'the number of mini-batches in one epoch')
cmd:option('--batch_size', 32, 'size of mini-batch (the number of parallel games) in each thread')
cmd:option('--nworker', 16, 'the number of threads used for training')
-- for rmsprop
cmd:option('--beta', 0.97, 'parameter of RMSProp')
cmd:option('--eps', 1e-6, 'parameter of RMSProp')
--other
cmd:option('--save', '', 'file name to save the model')
cmd:option('--load', '', 'file name to load the model')
g_opts = cmd:parse(arg or {})
print(g_opts)

g_mazebase.init_vocab()
if g_opts.nworker > 1 then
    g_workers = init_threads()
end

g_log = {}
if g_opts.optim == 'rmsprop' then g_rmsprop_state = {} end
g_init_model()
g_load_model()
g_mazebase.init_game()

train(g_opts.epochs)
g_save_model()

g_disp = require('display')
test()
