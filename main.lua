function init()
    require('xlua')
    paths.dofile('util.lua')
    paths.dofile('model.lua')
    paths.dofile('train.lua')
    paths.dofile('test.lua')
    paths.dofile('games/init.lua')
    torch.setdefaulttensortype('torch.FloatTensor')
end

function init_threads()
    print('starting workers')
    local threads = require('threads')
    threads.Threads.serialization('threads.sharedserialize')
    workers = threads.Threads(g_opts.nworker, init)
    workers:specific(true)
    for w = 1, g_opts.nworker do
        workers:addjob(w,
            function(opts_orig, vocab_orig)
                g_opts = opts_orig
                if g_opts.starcraft then
                    paths.dofile('starcraft/init.lua')
                else
                end
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
cmd:option('--max_attributes', 6)
cmd:option('--hidsz', 20)
cmd:option('--nhop', 3)
cmd:option('--memsize', 20)
cmd:option('--nonlin', 'tanh', 'tanh | relu | none')
cmd:option('--model', 'memnn', 'memnn | conv | linear | linear_lut')
cmd:option('--linear_lut_two_layer', false)
cmd:option('--linear_lut_three_layer', false)
cmd:option('--init_std', 0.2)
-- lut model
cmd:option('--MAXS', 500)
cmd:option('--MAXM', 100)
-- conv model
cmd:option('--convdim', 20)
cmd:option('--conv_sz', 19)
cmd:option('--conv_nonlin', 0) -- add nonlin after LUT
-- game parameters
cmd:option('--nagents', 1)
cmd:option('--nactions', 11)
cmd:option('--max_steps', 20)
cmd:option('--max_attributes', 6)
cmd:option('--games_config_path', 'config/game_config.lua')
cmd:option('--game', '')
-- training parameters
cmd:option('--optim', 'rmsprop', 'rmsprop | sgd')
cmd:option('--nbatches', 100)
cmd:option('--lrate', 1e-3)
cmd:option('--alpha', 0.03)
cmd:option('--batch_size', 32)
cmd:option('--epochs', 100)
cmd:option('--nworker', 16)
cmd:option('--max_grad_norm', 0)
cmd:option('--show', false)
cmd:option('--reinforce_coeff', 1)
-- for rmsprop
cmd:option('--beta', 0.97)
cmd:option('--eps', 1e-6)
--other
cmd:option('--save', '')
cmd:option('--load', '')
cmd:option('--img_path', '/gfsai-oregon/ai-group/users/aszlam/maze_images/')
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
