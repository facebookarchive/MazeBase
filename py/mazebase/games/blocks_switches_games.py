from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
from random import randint

from mazebase.games import (
    WithWaterAndBlocksMixin,
    RewardOnEndMixin,
    BaseVocabulary,
)
from mazebase.utils import creationutils
from mazebase.utils.mazeutils import populate_kwargs, MazeException, choice
from mazebase.items import agents
import mazebase.items as mi


# So we don't have to type as much
class PBSType(RewardOnEndMixin, WithWaterAndBlocksMixin, BaseVocabulary):
    pass


# Agents we only use once don't have to be put in items/Agent.py :)
class PushBlockAgent(agents.SingleTileMovable, agents.Pushing):
    pass


class SwitchesAgent(agents.SingleTileMovable, agents.Toggling):
    pass


def _est(game, s, e):
    '''shorthand to estimate reward for an agent to move from s to e'''
    visited, path = creationutils.dijkstra(
        game, s, creationutils.agent_movefunc, True)
    return -visited[e]  # Returns distance, which is negation of reward


def pbwps(p, start, end):
    path = [end]
    while path[-1] != start:
        path.append(p[path[-1]])
    waypoints = []
    path.reverse()
    for i, j in zip(path[:-1], path[1:]):
        x, y = i
        nx, ny = j
        waypoints.append((2 * x - nx, 2 * y - ny))
    return waypoints


class PushBlock(PBSType):
    ''' Agent must push a block onto a switch '''

    def _reset(self):
        super(PushBlock, self)._reset()

        self.sw_loc = choice(creationutils.empty_locations(self))
        self.sw = mi.Switch(location=self.sw_loc)
        self._add_item(self.sw)

        x, y = choice(creationutils.empty_locations(self))
        self.pushable = mi.Pushable(location=(x, y))
        self._add_item(self.pushable)

        visited, p = creationutils.dijkstra(self, (x, y),
                                            creationutils.pushblock_movefunc)
        if self.sw_loc not in visited:
            raise MazeException("No path to sw")
        self.waypoints = pbwps(p, self.pushable.location, self.sw.location)

        x, y = choice(creationutils.empty_locations(self,
                                                    bad_blocks=[mi.Block]))
        self.agent = PushBlockAgent(location=(x, y))
        self._add_agent(self.agent, "PushBlockAgent")
        visited, _ = creationutils.dijkstra(self, (x, y),
                                            creationutils.agent_movefunc)
        if self.waypoints[0] not in visited:
            raise MazeException("No path to pushblock")

    def _side_information(self):
        return super(PushBlock, self)._side_information() + \
            [[self.FEATURE.PUSH] +
             self.pushable.featurize() +
             self.sw.featurize()
             ]

    def _finished(self):
        return self.pushable.location == self.sw_loc

    def _calculate_approximate_reward(self):
        '''Approximation used: Agent can move through push-block '''
        cur = self.agent.location
        r = 0
        for loc in self.waypoints:
            r += _est(self, cur, loc)
            cur = loc
        return super(PushBlock, self)._calculate_approximate_reward() + r


class PushBlockCardinal(PBSType):
    ''' Agent must push a block onto one of the 4 cardinal walls '''

    def _reset(self):
        super(PushBlockCardinal, self)._reset()

        x, y = choice(creationutils.empty_locations(self))
        self.pushable = mi.Pushable(location=(x, y))
        self._add_item(self.pushable)
        self.direction = choice([self.FEATURE.UP,
                                 self.FEATURE.DOWN,
                                 self.FEATURE.LEFT,
                                 self.FEATURE.RIGHT,
                                 ])
        if self.direction == self.FEATURE.UP:
            self.goals = set((i, self.height) for i in range(self.width))
        elif self.direction == self.FEATURE.DOWN:
            self.goals = set((i, 0) for i in range(self.width))
        elif self.direction == self.FEATURE.LEFT:
            self.goals = set((0, i) for i in range(self.height))
        elif self.direction == self.FEATURE.RIGHT:
            self.goals = set((self.width, i) for i in range(self.height))

        visited, p = creationutils.dijkstra(self, (x, y),
                                            creationutils.pushblock_movefunc)
        if not any(x in visited for x in self.goals):
            raise MazeException("No path to goal")
        closest = min(self.goals, key=lambda loc: visited[loc])
        self.waypoints = pbwps(p, self.pushable.location, closest)

        x, y = choice(creationutils.empty_locations(self,
                                                    bad_blocks=[mi.Block]))
        self.agent = PushBlockAgent(location=(x, y))
        self._add_agent(self.agent, "PushBlockCardinalAgent")

    def _side_information(self):
        return super(PushBlockCardinal, self)._side_information() + \
            [[self.FEATURE.PUSH, self.direction] + self.pushable.featurize()]

    def _finished(self):
        return any(x == self.pushable.location for x in self.goals)

    def _calculate_approximate_reward(self):
        '''
        Approximation used:
            Agent can move through push-block
            The point on the wall to move block to is the one closest to block
        '''
        cur = self.agent.location
        r = 0
        for loc in self.waypoints:
            r += _est(self, cur, loc)
            cur = loc
        return super(PushBlockCardinal,
                     self)._calculate_approximate_reward() + r


class Switches(PBSType):
    ''' Agent must toogle all switches to the same color '''

    __properties = dict(
        n_switches=2,
        switch_states=2,
    )

    def __init__(self, **kwargs):
        populate_kwargs(self, self.__class__.__properties, kwargs)
        super(Switches, self).__init__(**kwargs)

    def _reset(self):
        super(Switches, self)._reset()

        loc = choice(creationutils.empty_locations(self, bad_blocks=[mi.Block]))
        self.agent = SwitchesAgent(location=loc)
        self._add_agent(self.agent, "SwitchesAgent")

        visited, _ = creationutils.dijkstra(self, loc,
                                            creationutils.agent_movefunc)

        self._switches = []
        for _ in range(self.n_switches):
            loc = choice(creationutils.empty_locations(self))
            self._switches.append(mi.Switch(
                location=loc,
                nstates=self.switch_states,
                start_state=choice(range(self.switch_states)),
            ))
            self._add_item(self._switches[-1])
            if loc not in visited:
                raise MazeException("No path to goal")

    def _finished(self):
        return len(set(x.state for x in self._switches)) == 1

    def _side_information(self):
        return super(Switches, self)._side_information() + \
            [[self.FEATURE.SWITCH,
              self.FEATURE.STATE,
              self.FEATURE.SAME,
              ]]

    def _calculate_approximate_reward(self):
        '''Greedy solution that visits each switch in turn'''
        best = 1e100
        sw_colors = [sw.state for sw in self._switches]
        print(sw_colors)
        for i, sw in enumerate(self._switches):
            tmp = [(sw.state - c) % self.switch_states for c in sw_colors]
            # Heuristic for perferring not needing to flip switches
            best = min(best, sum(x if x > 0 else -2 for x in tmp))

        to_visit = [sw.location for sw in self._switches]
        loc = self.agent.location
        r = 0
        for i, sw in enumerate(self._switches):
            visited, path = creationutils.dijkstra(
                self, loc, creationutils.agent_movefunc, True)
            ind, loc = min(enumerate(to_visit), key=lambda x: visited[x[1]])
            r -= visited[loc]  # Reward is negative of path
            to_visit.remove(loc)
        return super(Switches,
                     self)._calculate_approximate_reward() + \
                r - best * self.turn_penalty


def add_vertical_wall(game):
    size = (game.width, game.height)
    dim = choice([0, 1])
    line = randint(1, size[1 - dim] - 2)
    opening = randint(0, size[dim] - 1)
    for i in range(size[dim]):
        if i != opening:
            loc = [line, line]
            loc[dim] = i
            game._add_item(mi.Block(location=loc))

    loc = [line, line]
    loc[dim] = opening

    return loc, dim


class LightKey(PBSType):
    ''' Agent must open a door with a switch and go to the goal '''
    __properties = dict(
        switch_states=2,
    )

    def __init__(self, **kwargs):
        populate_kwargs(self, self.__class__.__properties, kwargs)
        super(LightKey, self).__init__(**kwargs)

    def _reset(self):
        hole, dim = add_vertical_wall(self)

        # Add the door
        self.door = mi.Door(location=hole,
                            state=choice(range(1, self.switch_states)))
        self._add_item(self.door)

        # Add additional blocks and waters
        super(LightKey, self)._reset()

        # Add the goal, agent, and switch
        loc = choice(creationutils.empty_locations(
            self, bad_blocks=[mi.Block, mi.Door]))
        self.goal = mi.Goal(location=loc)
        self._add_item(self.goal)
        side = choice([-1, 1])

        def mask_func(x, y):
            return side * ((x, y)[1 - dim] - hole[1 - dim]) > 0

        loc = choice(creationutils.empty_locations(
            self, bad_blocks=[mi.Block, mi.Door, mi.Goal], mask=mask_func))
        self.sw = mi.Switch(location=loc, nstates=self.switch_states)
        self._add_item(self.sw)

        loc = choice(creationutils.empty_locations(
            self, bad_blocks=[mi.Block, mi.Door], mask=mask_func))
        self.agent = SwitchesAgent(location=loc)
        self._add_agent(self.agent, "LightKeyAgent")

        visited, _ = creationutils.dijkstra(self, loc,
                                            creationutils.agent_movefunc)
        if self.goal.location not in visited or self.sw.location not in visited:
            raise MazeException("No path to goal")

    def _step(self):
        # Hook the door up to the switch
        if self.sw.state == self.door.state:
            self.door.open()
        else:
            self.door.close()

    def _finished(self):
        return self.agent.location == self.goal.location

    def _side_information(self):
        return super(LightKey, self)._side_information() + \
            [[self.FEATURE.GOTO] + self.goal.featurize()]

    def _calculate_approximate_reward(self):
        x, y = self.door.location
        saved = self._approx_reward_map[x][y]
        self._approx_reward_map[x][y] = -1e100
        r = _est(self, self.agent.location, self.goal.location)
        if r < -1e90:
            self._approx_reward_map[x][y] = saved
            r = _est(self, self.agent.location, self.sw.location) + \
                _est(self, self.sw.location, self.goal.location)
        return super(LightKey, self)._calculate_approximate_reward() + r


class BlockedDoor(PBSType):
    ''' Agent must push a block out of the way and reach a goal '''

    def _reset(self):
        hole, dim = add_vertical_wall(self)

        # Add the pushblock
        self.pushable = mi.Pushable(location=hole)
        self._add_item(self.pushable)

        # Add additional blocks and waters
        super(BlockedDoor, self)._reset()

        # Add the goal, and agent
        loc = choice(creationutils.empty_locations(
            self, bad_blocks=[mi.Block, mi.Door]))
        self.goal = mi.Goal(location=loc)
        self._add_item(self.goal)

        loc = choice(creationutils.empty_locations(
            self, bad_blocks=[mi.Block, mi.Door]))
        self.agent = PushBlockAgent(location=loc)
        self._add_agent(self.agent, "BlockedDoorAgent")

        self._remove_item(self.pushable.id)
        visited, _ = creationutils.dijkstra(self, loc,
                                            creationutils.agent_movefunc)
        if self.goal.location not in visited:
            raise MazeException("No path to goal")
        self._add_item(self.pushable)

    def _finished(self):
        return self.agent.location == self.goal.location

    def _side_information(self):
        return super(BlockedDoor, self)._side_information() + \
            [[self.FEATURE.GOTO] + self.goal.featurize()]

    def _calculate_approximate_reward(self):
        r = _est(self, self.agent.location, self.goal.location)
        if r < -1e90:
            self._remove_item(self.pushable.id)
            r = _est(self, self.agent.location, self.goal.location)
            r -= 4 * self.turn_penalty  # Heuristic for pushing block
            self._add_item(self.pushable)
        return super(BlockedDoor, self)._calculate_approximate_reward() + r
