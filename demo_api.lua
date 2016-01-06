paths.dofile('games/init.lua')

g_opts = {}
g_opts.games_config_path = 'games/config/game_config.lua'

g_init_vocab()
g_init_game()

g = new_game()

g_disp = require'display'
nactions = #g.agent.action_names
for t = 1, 20 do
	g_disp.image(g.map:to_image())
	local s = g:to_sentence()
	print(s)
	g:act(torch.random(nactions))
	g:update()
	if g:is_active() == false then
		break
	end
	os.execute('sleep 0.2')
end
