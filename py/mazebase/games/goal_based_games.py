from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
from random import shuffle, randint
from six.moves import range
from itertools import product

from . import (
    BaseMazeGame,
    WithWaterAndBlocksMixin,
    RewardOnEndMixin,
    BaseVocabulary,
    AbsoluteLocationVocabulary,
)
from mazebase.utils import creationutils
from mazebase.utils.mazeutils import populate_kwargs, MazeException, choice
from mazebase.items import agents
import mazebase.items as mi


class MovingAgent(agents.SingleTileMovable):
    '''Agents we only use once don't have to be put in items/Agent.py :)'''
    pass


# So we don't have to type as much
class GoalType(RewardOnEndMixin, WithWaterAndBlocksMixin, BaseVocabulary):
    pass


def _est(game, s, e):
    '''shorthand to estimate reward for an agent to move from s to e'''
    visited, path = creationutils.dijkstra(
        game, s, creationutils.agent_movefunc, True)
    return -visited[e]  # Returns distance, which is negation of reward


class SingleGoalApproximateRewardMixin(BaseMazeGame):
    def _calculate_approximate_reward(self):
        r = _est(self, self.agent.location, self.goal.location)
        return super(SingleGoalApproximateRewardMixin,
                     self)._calculate_approximate_reward() + r


class SingleGoal(GoalType):
    ''' Agent moves to a single goal '''

    def _reset(self):
        super(SingleGoal, self)._reset()

        loc = choice(creationutils.empty_locations(self))
        self.goal = mi.Goal(location=loc)
        self._add_item(self.goal)

        loc = choice(creationutils.empty_locations(self, bad_blocks=[mi.Block]))
        self.agent = MovingAgent(location=loc)
        self._add_agent(self.agent, "SingleGoalAgent")

        visited, _ = creationutils.dijkstra(self, loc,
                                            creationutils.agent_movefunc)
        if self.goal.location not in visited:
            raise MazeException("No path to goal")

    def _side_information(self):
        return super(SingleGoal, self)._side_information() + \
            [[self.FEATURE.GOTO] + self.goal.featurize()]

    def _finished(self):
        return self.agent.location == self.goal.location


class MultiGoals(GoalType):
    ''' Agent must visit each goal in order, without penalty for visiting out
    of order '''

    __properties = dict(
        n_goals=3,
    )

    def __init__(self, **kwargs):
        populate_kwargs(self, self.__class__.__properties, kwargs)
        super(MultiGoals, self).__init__(**kwargs)

    def _reset(self):
        super(MultiGoals, self)._reset()

        self.goals = []
        for i in range(self.n_goals):
            x, y = choice(creationutils.empty_locations(self))
            self.goals.append(mi.Goal(location=(x, y), id=i))
            self._add_item(self.goals[i])
        shuffle(self.goals)
        self.v = 0

        x, y = choice(creationutils.empty_locations(self,
                                                    bad_blocks=[mi.Block]))
        self.agent = MovingAgent(location=(x, y))
        self._add_agent(self.agent, "MultiGoalsAgent")

        visited, _ = creationutils.dijkstra(self, (x, y),
                                            creationutils.agent_movefunc)
        if not all(goal.location in visited for goal in self.goals):
            raise MazeException("No path to goal")

    def _side_information(self):
        return super(MultiGoals, self)._side_information() + \
            [[self.FEATURE.ORDERED_OBJ[i], self.FEATURE.GOTO] + x.featurize()
             for i, x in enumerate(self.goals)]

    def _step(self):
        if self.agent.location == self.goals[self.v].location:
            self.v = self.v + 1

    def _finished(self):
        return self.v == self.n_goals

    def _calculate_approximate_reward(self):
        locs = [self.agent.location] + [g.location for g in self.goals]
        r = sum(_est(self, l1, l2) for l1, l2 in zip(locs[:-1], locs[1:]))
        return super(MultiGoals, self)._calculate_approximate_reward() + r


class TogglingAgent(agents.SingleTileMovable, agents.Toggling):
    pass


class ConditionedGoals(GoalType):
    ''' Agent must visit goals conditioned on the color of a switch. Penalty
    for visiting a wrong goal '''

    __properties = dict(
        n_goals=3,
        n_colors=3,
        goal_penalty=0.2
    )

    def __init__(self, **kwargs):
        populate_kwargs(self, self.__class__.__properties, kwargs)
        super(ConditionedGoals, self).__init__(**kwargs)

    def _reset(self):
        super(ConditionedGoals, self)._reset()

        x, y = choice(creationutils.empty_locations(self))
        self.sw = mi.Switch(
            location=(x, y),
            nstates=self.n_colors,
            start_state=choice(range(self.n_colors)),
        )
        self._add_item(self.sw)

        self.goals = []
        for i in range(self.n_goals):
            x, y = choice(creationutils.empty_locations(self))
            self.goals.append(mi.Goal(location=(x, y), id=i))
            self._add_item(self.goals[i])
        self.conditions = [randint(0, self.n_goals - 1) for _ in self.goals]

        x, y = choice(creationutils.empty_locations(self,
                                                    bad_blocks=[mi.Block]))
        self.agent = TogglingAgent(location=(x, y))
        self._add_agent(self.agent, "ConditionedGoalsAgent")

        visited, _ = creationutils.dijkstra(self, (x, y),
                                            creationutils.agent_movefunc)

        if (self.sw.location not in visited or
            not any(self.goals[i].location in visited
                    for i in set(self.conditions))):
            raise MazeException("No path to goal")

    def _get_reward(self, id):
        reward = super(ConditionedGoals, self)._get_reward(id)
        forbiddens = set(g.location for g in self.goals)
        if self.sw.state < len(self.conditions):
            forbiddens.remove(
                self.goals[self.conditions[self.sw.state]].location)
        if self.agent.location in forbiddens:
            reward -= self.goal_penalty

        return reward

    def _finished(self):
        if self.sw.state >= len(self.conditions):
            return False
        return self.agent.location == \
            self.goals[self.conditions[self.sw.state]].location

    def _side_information(self):
        # Featurize the goals, and add it to the features of some dummy
        # switches in the right state
        return super(ConditionedGoals, self)._side_information() + \
            [
                [self.FEATURE.IF] +
                mi.Switch(nstates=self.n_goals, start_state=i).featurize() +
                [self.FEATURE.GOTO] +
                self.goals[st].featurize()
            for i, st in enumerate(self.conditions)]

    def _calculate_approximate_reward(self):
        if self.sw.state >= len(self.conditions):
            best = -1e100
        else:
            best = _est(self, self.agent.location,
                        self.goals[self.conditions[self.sw.state]].location)
        sw_dist = _est(self, self.agent.location, self.sw.location)
        for i in range(min(self.n_goals, self.n_colors)):
            goal_loc = self.goals[self.conditions[i]].location
            best = max(
                best,
                _est(self, self.sw.location, goal_loc) -
                ((i - self.sw.state) % self.n_colors) * self.turn_penalty +
                sw_dist)
        return super(ConditionedGoals, self)._calculate_approximate_reward() +\
                best + self.goal_penalty

    def _accumulate_approximate_rewards(self):
        super(ConditionedGoals, self)._accumulate_approximate_rewards()
        for x, y in product(range(self.width), range(self.height)):
            if self._tile_get_block((x, y), mi.Goal) is not None:
                self._approx_reward_map[x][y] += -self.goal_penalty


class Exclusion(GoalType):
    ''' Agent must visit all goals except those stated in side_information '''

    __properties = dict(
        goal_penalty=0.5,  # penalty for stepping on excluded goal
        n_goals=3,
        visit_min=1,
        visit_max=-1,  # -1 = n_goals
    )

    def __init__(self, **kwargs):
        populate_kwargs(self, self.__class__.__properties, kwargs)
        super(Exclusion, self).__init__(**kwargs)

    def _reset(self):
        super(Exclusion, self)._reset()
        if self.visit_min < 1:
            raise MazeException("visit_min is not >= 1")
        if self.visit_max == -1:
            self.visit_max = self.n_goals
        self.visit = list(range(self.n_goals))
        shuffle(self.visit)
        to_visit = randint(self.visit_min, self.visit_max)
        self.exclude = self.visit[to_visit:]
        self.visit = self.visit[:to_visit]
        self.visit = dict((x, False) for x in self.visit)

        self.goals = []
        for i in range(self.n_goals):
            x, y = choice(creationutils.empty_locations(self))
            self.goals.append(mi.Goal(location=(x, y), id=i))
            self._add_item(self.goals[i])

        x, y = choice(creationutils.empty_locations(self,
                                                    bad_blocks=[mi.Block]))
        self.agent = TogglingAgent(location=(x, y))
        self._add_agent(self.agent, "ExclusionAgent")

        visited, _ = creationutils.dijkstra(self, (x, y),
                                            creationutils.agent_movefunc)

        if not all(goal.location in visited for goal in self.goals):
            raise MazeException("No path to goal")

    def _step(self):
        for i in self.visit.keys():
            if self.agent.location == self.goals[i].location:
                self.visit[i] = True

    def _finished(self):
        return all(self.visit.values())

    def _side_information(self):
        return super(Exclusion, self)._side_information() + \
            [[self.FEATURE.GOTO, self.FEATURE.ALL]] + \
            [[self.FEATURE.AVOID] +
             self.goals[i].featurize()
             for i in self.exclude]

    def _get_reward(self, id):
        reward = super(Exclusion, self)._get_reward(id)
        for i in self.exclude:
            if self.agent.location == self.goals[i].location:
                reward -= self.goal_penalty

        return reward

    def _calculate_approximate_reward(self):
        prev = self.agent.location
        visited = dict((x, False) for x in self.visit)
        so_far = 0
        for _ in self.visit:
            best_n = None
            best = -1e100
            for g in [g for g, b in visited.items() if not b]:
                t = _est(self, prev, self.goals[g].location)
                if t > best:
                    best = t
                    best_n = g
            prev = self.goals[best_n].location
            so_far += best
            visited[best_n] = True
        return super(Exclusion, self)._calculate_approximate_reward() + so_far

    def _accumulate_approximate_rewards(self):
        super(Exclusion, self)._accumulate_approximate_rewards()
        excludes = [self.goals[i].location for i in self.exclude]
        for x, y in product(range(self.width), range(self.height)):
            if (x, y) in excludes:
                self._approx_reward_map[x][y] += -self.goal_penalty


class GotoType(AbsoluteLocationVocabulary,
               GoalType,
               ):
    pass


class Goto(SingleGoalApproximateRewardMixin, GotoType):
    ''' Agent must go to an absolute location '''

    def _reset(self):
        super(Goto, self)._reset()

        loc = choice(creationutils.empty_locations(self))
        self.goal = mi.Goal(location=loc, visible=False)
        self._add_item(self.goal)

        loc = choice(creationutils.empty_locations(self,
                                                   bad_blocks=[mi.Block]))
        self.agent = MovingAgent(location=loc)
        self._add_agent(self.agent, "GotoAgent")

        visited, _ = creationutils.dijkstra(self, loc,
                                            creationutils.agent_movefunc)
        if self.goal.location not in visited:
            raise MazeException("No path to goal")

    def _side_information(self):
        return super(Goto, self)._side_information() + \
            [[self.FEATURE.GOTO, self._coords2loc(*self.goal.location)]]

    def _finished(self):
        return self.agent.location == self.goal.location


class GotoHidden(SingleGoalApproximateRewardMixin, GotoType):
    '''Agent must go to one of several goals, depending on side_information
    '''

    __properties = dict(
        n_goals=3,
    )

    def __init__(self, **kwargs):
        populate_kwargs(self, self.__class__.__properties, kwargs)
        super(GotoHidden, self).__init__(**kwargs)

    def _reset(self):
        super(GotoHidden, self)._reset()

        self.goals = []
        for i in range(self.n_goals):
            x, y = choice(creationutils.empty_locations(self))
            self.goals.append(mi.Goal(location=(x, y), id=i, visible=False))
            self._add_item(self.goals[i])

        self.goal = choice(self.goals)

        x, y = choice(creationutils.empty_locations(self,
                                                    bad_blocks=[mi.Block]))
        self.agent = MovingAgent(location=(x, y))
        self._add_agent(self.agent, "GotoHiddenAgent")

        visited, _ = creationutils.dijkstra(self, (x, y),
                                            creationutils.agent_movefunc)
        if self.goal.location not in visited:
            raise MazeException("No path to goal")

    def _side_information(self):
        return super(GotoHidden, self)._side_information() + \
            [[self._coords2loc(*goal.location)] + goal.featurize()
             for goal in self.goals] + \
            [[self.FEATURE.GOTO] + self.goal.featurize()]

    def _finished(self):
        return self.agent.location == self.goal.location
