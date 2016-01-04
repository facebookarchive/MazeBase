export EXPNAME="MazeBase_goals"
exp th main.lua --max_steps 50 --nworker 16 --memsize 10 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_g4_act2.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 10 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_g2_act1.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 10 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_g6_act2.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 10 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_g6_act1.lua --epochs 100
