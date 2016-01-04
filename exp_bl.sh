export EXPNAME="MazeBase_bl_mg"
exp th main.lua --max_steps 50 --nworker 16 --memsize 10 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz10_bl00.lua --epochs 100
#exp th main.lua --max_steps 50 --nworker 16 --memsize 20 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz10_bl05.lua --epochs 100
#exp th main.lua --max_steps 50 --nworker 16 --memsize 30 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz10_bl10.lua --epochs 100
#exp th main.lua --max_steps 50 --nworker 16 --memsize 40 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz10_bl15.lua --epochs 100
#exp th main.lua --max_steps 50 --nworker 16 --memsize 50 --hidsz 50 --nactions 6 --model mlp --nlayers 2 --games_config_path games/config/multigoals_sz10_bl20.lua --epochs 100
