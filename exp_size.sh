export EXPNAME="MazeBase_size_mg"
exp th main.lua --max_steps 50 --nworker 16 --memsize 20 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz5_bl20.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 25 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz6_bl20.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 30 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz7_bl20.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 35 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz8_bl20.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 43 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz9_bl20.lua --epochs 100
exp th main.lua --max_steps 50 --nworker 16 --memsize 50 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz10_bl20.lua --epochs 100
