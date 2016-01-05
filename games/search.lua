-- Copyright (c) 2015-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant 
-- of patent rights can be found in the PATENTS file in the same directory.

local M = {}
local function unhb(nh,nw,ch,cw,prev,dists,M)
    local sum = dists[ch][cw] + M[nh][nw]
    if sum<dists[nh][nw] then
        dists[nh][nw] = sum
        prev[nh][nw][1] = ch
        prev[nh][nw][2] = cw
    end
end

local function dsearch(M,sh,sw,dh,dw)
    -- assumes all actions take place on a cardinal grid.
    -- all steps are to one of the neighboring squares.
    -- M[i][j] is the cost of stepping to that location
    local H = M:size(1)
    local W = M:size(2)
    local dmax = M:sum()
    local visited = torch.zeros(H,W)
    local dists = torch.ones(H,W):mul(dmax)
    local nmap = torch.ones(H,W):mul(dmax)
    local ch = sh
    local cw = sw
    dists[sh][sw] = 0
    visited[sh][sw] = 1
    local prev = torch.zeros(H,W,2)
    while visited:min() == 0 do
        if ch<H and visited[ch+1][cw] == 0 then
            unhb(ch+1,cw,ch,cw,prev,dists,M)
        end
        if cw<W and visited[ch][cw+1] == 0 then
            unhb(ch,cw+1,ch,cw,prev,dists,M)
        end
        if ch>1 and visited[ch-1][cw] == 0 then
            unhb(ch-1,cw,ch,cw,prev,dists,M)
        end
        if cw>1 and visited[ch][cw-1] == 0 then
            unhb(ch,cw-1,ch,cw,prev,dists,M)
        end
        visited[ch][cw] = 1

        nmap:copy(visited):mul(dmax):add(dists)
        local ju,juu = nmap:view(H*W):min(1)
        ch = math.ceil(juu[1]/W)
        cw = juu[1] - (ch-1)*W
        if ch == dh and cw == dw then return dists[dh][dw],prev end
    end
end
M.dsearch = dsearch

local function backtrack(sh,sw,dh,dw,prev)
    local H = prev:size(1)
    local W = prev:size(2)
    local path = torch.zeros(H*W,2)
    local count = 1
    local ch = dh
    local cw = dw
    path[count][1] = ch
    path[count][2] = cw
    while ch ~= sh or cw ~= sw do
        count = count + 1
        local tch = ch
        ch = prev[ch][cw][1]
        cw = prev[tch][cw][2]
        path[count][1] = ch
        path[count][2] = cw
    end
    path = path:narrow(1,1,count)
    local tr = torch.range(1,count):mul(-1):add(count+1):long()
    path = path:index(1,tr)
    return path
end
M.backtrack = backtrack

return M
