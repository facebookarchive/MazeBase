package.path = package.path .. ';lua/?/init.lua'
g_mazebase = require('mazebase')

g_opts = {}
g_opts.games_config_path = 'lua/mazebase/config/game_config.lua'

g_mazebase.init_vocab()
g_mazebase.init_game()

g = g_mazebase.new_game()

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
