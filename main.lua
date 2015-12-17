function init()
    require('xlua')
    g_tds = require('tds')
    paths.dofile('util.lua')
    paths.dofile('model.lua')
    paths.dofile('train.lua')
    paths.dofile('qlearn.lua')
    paths.dofile('test.lua')
    paths.dofile('supervision.lua')
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
            function(opts_orig, vocab_orig, vocab_loc_orig)
                g_opts = opts_orig
                if g_opts.randseed > 0 then
                    torch.manualSeed(g_opts.randseed + __threadid * 10000)
                end
                if g_opts.starcraft then
                    paths.dofile('starcraft/init.lua')
                else
                    paths.dofile('games/init.lua')
                end
                g_vocab = vocab_orig
                g_vocab_loc = vocab_loc_orig
                g_init_model()
                g_init_game()
            end,
            function() end,
            g_opts, g_vocab, g_vocab_loc
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
-- starcraft parameters
cmd:option('--starcraft', false)
cmd:option('--skip_frames', 7)
cmd:option('--port_init', 11111)
cmd:option('--hostname', '')
cmd:option('--nenemies', 1)
cmd:option('--restart_starcraft', 0)
cmd:option('--attack_weakest', false)
cmd:option('--map_multiscale', false)
cmd:option('--slow_play', false)
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
cmd:option('--log_bistro', false)
cmd:option('--reinforce_coeff', 1)
-- supervised learning
cmd:option('--supervision_coeff', 1)
cmd:option('--supervision_ratio', 0)
cmd:option('--question_coeff', 1)
cmd:option('--question_ratio', 0)
cmd:option('--babi', false) -- ask babi questions instead
cmd:option('--babidir' , '/gfsai-east/ai-group/datasets/babi/tasks/v1.2/en/')
-- for Q-learning
cmd:option('--qlearn', false)
cmd:option('--eps_sta', 0.1)
cmd:option('--eps_end', -1)
cmd:option('--gamma_discount', 1)
cmd:option('--buffer_size', 1000)
cmd:option('--game_runs', 20)
cmd:option('--nbuffers', 1)
-- for rmsprop
cmd:option('--beta', 0.97)
cmd:option('--eps', 1e-6)
--other
cmd:option('--save', '')
cmd:option('--load', '')
cmd:option('--img_path', '/gfsai-oregon/ai-group/users/aszlam/maze_images/')
cmd:option('--disp', '')
cmd:option('--randseed', 0)
cmd:option('--hand', false)
cmd:option('--nil_zero', 0)
g_opts = cmd:parse(arg or {})
if g_opts.qlearn then g_opts.nworker = 1 end
print(g_opts)

if g_opts.randseed > 0 then torch.manualSeed(g_opts.randseed) end
if g_opts.show then g_disp = paths.dofile('display.lua') end
if g_opts.log_bistro then g_bistro = require('bistro') end

if g_opts.starcraft then
    paths.dofile('starcraft/init.lua')
else
    paths.dofile('games/init.lua')
end

g_init_vocab()
if g_opts.nworker > 1 then
    g_workers = init_threads()
end

g_log = {}
g_init_model()
if g_opts.optim == 'rmsprop' then g_rmsprop_state = {} end
g_load_model()
g_init_game()

-- check nactions
if g_opts.starcraft then
    assert(4 + g_opts.nenemies == g_opts.nactions)
else
    local g = new_game()
--    assert(#g.agent.actions == g_opts.nactions)
end

--ProFi = require 'ProFi'
--ProFi:start()  -- place where you want to start profiling
-- Your code
train(g_opts.epochs)
--ProFi:stop()
--ProFi:writeReport( '/home/aszlam/random/profile_report2.txt' )
g_save_model()
