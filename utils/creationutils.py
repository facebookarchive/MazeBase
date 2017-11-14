from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
from random import shuffle, random
from collections import defaultdict
import itertools
import mazebase.items as mi
from .mazeutils import MazeException


def sprinkle(game, tiles, tilemask=None):
    '''
    Sprinkles blocks into a map. Tiles is given in the format like:
        [(MazeItem, float), ...] ex.
        [(Block, .5)]
    where we sprinkle MazeItem with the percent chance given by the second arg.

    Defaults to generating on empty tiles, but you can override this with
    tilemask and specify a list of locations.

    Returns list of item ids
    '''
    if tilemask is None:
        tilemask = empty_locations(game)

    ids = []
    for (x, y) in tilemask:
        shuffle(tiles)
        for tile, pct in tiles:
            if random() < pct:
                ids.append(game._add_item(tile(location=(x, y))))
                break

    return ids


def empty_locations(game, bad_blocks=None, mask=lambda x, y: True):
    '''By default, finds empty locations in the map.
    If bad_blocks is not none, then finds locations without any bad_blocks,
    but maybe with other block types
    mask is a function that provides valid coordinates
    '''
    empties = []
    for x, y in itertools.product(range(game.width), range(game.height)):
        if not mask(x, y):
            continue
        itemlst = game._map[x][y]
        if bad_blocks is None and itemlst == []:
            empties.append((x, y))
        elif bad_blocks is not None and not any(
                isinstance(item, typ) for
                item, typ in itertools.product(itemlst, bad_blocks)):
            empties.append((x, y))
    return empties


def dijkstra(game, initial, movefunc, weighted=False):
    '''
    Accepts:
        game
        initial: (x, y) tuple of start location
        movefunc: f(loc) determines the locations you can move to from loc
        weighted: use the _approx_reward_map instead of # of moves

    Returns:
        visited: dictionary of {location: distance} pairs
        path: dictionary of {location: previous_location} pairs
    '''
    visited = defaultdict(lambda: 1e309)
    visited[initial] = 0
    path = {}

    nodes = set(itertools.product(range(game.width), range(game.height)))
    while nodes:
        current = nodes.intersection(visited.keys())
        if not current:
            break
        min_node = min(current, key=visited.get)
        nodes.remove(min_node)
        current_weight = visited[min_node]
        x, y = min_node

        for edge in movefunc(game, min_node):
            # Maximize reward by minimizing "distance = - reward"
            w = -game._approx_reward_map[edge[0]][edge[1]] if weighted else 1
            weight = current_weight + w
            if edge not in visited or weight < visited[edge]:
                visited[edge] = weight
                path[edge] = min_node

    return visited, path


def __movefunc_helper(game, loc, movefunc_helper):
    res = []
    x, y = loc
    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        nx, ny = x + dx, y + dy
        if not game._in_bounds((nx, ny)):
            continue
        if movefunc_helper(game, loc, (dx, dy)):
            res.append((nx, ny))
    return res


def agent_movefunc(game, loc):
    ''' Can move to non-block spaces '''
    def helper(game, loc, dloc):
        x, y = loc
        dx, dy = dloc
        nx, ny = x + dx, y + dy
        return game._tile_get_block((nx, ny), mi.Block) is None

    return __movefunc_helper(game, loc, helper)


def pushblock_movefunc(game, loc):
    ''' Can move if tile behind and in front are not blocked (so agent can push
    from behind) '''
    def helper(game, loc, dloc):
        x, y = loc
        dx, dy = dloc
        tx, ty = x - dx, y - dy
        nx, ny = x + dx, y + dy
        return (game._in_bounds((tx, ty)) and
                game._tile_get_block((nx, ny), mi.Block) is None and
                game._tile_get_block((tx, ty), mi.Block) is None)

    return __movefunc_helper(game, loc, helper)
