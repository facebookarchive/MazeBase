from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
from random import choice
import sys

from mazebase.utils import mazeutils
import mazebase.items as mi


class Agent(mi.MazeItem):
    '''
    Agents are special items that can perform actions. We use a mix-ins model
    to specify Agent traits. To combine traits, simply subclass both
    Agent classes:

    # This agent can move and drop bread crumbs
    class SingleGoalAgent(mi.SingleTileMovable, mi.BreadcrumbDropping):
        pass

    To make a new agent trait, create the class, subclass from Agent, create
    the actions, and call self._add_action('id', self.__action)

    IMPORTANT: Any attributes defined outside of this module will not be
    featurized. Agents are featurized as a list of what they can 'do'
    '''
    __properties = dict(
        # Speed allows some agents to move faster than others
        speed=1
    )

    def __init__(self, **kwargs):
        mazeutils.populate_kwargs(self, self.__class__.__properties, kwargs)
        super(Agent, self).__init__(**kwargs)

        self.actions = {'pass': self._pass}
        self.PRIO = 100
        self._all_agents = [x[1] for x in
                            mazeutils.all_classes_of(sys.modules[__name__])]

    def _pass(self):
        pass

    def _add_action(self, id, func):
        assert id not in self.actions, "Duplicate action id"
        self.actions[id] = func

    def featurize(self):
        features = list(set(self.__get_all_superclasses(self.__class__)))
        return features

    def __get_all_superclasses(self, cls):
        all_superclasses = []
        for superclass in cls.__bases__:
            if superclass in self._all_agents:
                all_superclasses.append(superclass.__name__)
            all_superclasses.extend(self.__get_all_superclasses(superclass))
        return all_superclasses

    def _get_display_symbol(self):
        return (u' A ', None, None, None)


class NPC(Agent):
    ''' NPC Agents cannot be controlled by the player and moves randomly '''
    def get_npc_action(self):
        return (self.id, choice(self.actions))


class SingleTileMovable(Agent):
    ''' Can move up, down, left, and right 1 tile per turn '''
    def __init__(self, **kwargs):
        super(SingleTileMovable, self).__init__(**kwargs)

        self._add_action("up", self.__up)
        self._add_action("down", self.__down)
        self._add_action("left", self.__left)
        self._add_action("right", self.__right)

    def __dmove(self, dx, dy):
        x, y = self.location
        nloc = x + dx, y + dy
        # Cannot walk into blocks, agents, or closed doors
        if (self.game._tile_get_block(nloc, mi.Block) is None and
                self.game._tile_get_block(nloc, Agent) is None and
                (not self.game._tile_get_block(nloc, mi.Door) or
                 self.game._tile_get_block(nloc, mi.Door).isopen)):
            self.game._move_item(self.id, location=nloc)

    def __up(self):
        self.__dmove(0, 1)

    def __down(self):
        self.__dmove(0, -1)

    def __left(self):
        self.__dmove(-1, 0)

    def __right(self):
        self.__dmove(1, 0)


class BreadcrumbDropping(Agent):
    ''' Can drop breadcrumbs as an action '''
    def __init__(self, **kwargs):
        super(BreadcrumbDropping, self).__init__(**kwargs)
        self._add_action("breadcrumb", self.__drop_crumb)

    def __drop_crumb(self):
        if self.game._tile_get_block(self.location, mi.Breadcrumb) is None:
            self.game._add_item(mi.Breadcrumb(location=self.location))


class Pushing(Agent):
    '''
    Can push in the 4 cardinal directions. Pushing moves Pushable objects
    in one of four directions if there's no collision.
    '''
    def __init__(self, **kwargs):
        super(Pushing, self).__init__(**kwargs)
        self._add_action("push_up", self.__push_up)
        self._add_action("push_down", self.__push_down)
        self._add_action("push_left", self.__push_left)
        self._add_action("push_right", self.__push_right)

    def __dpush(self, dx, dy):
        x, y = self.location
        tx, ty = x + dx, y + dy
        nx, ny = tx + dx, ty + dy

        # Cannot push into other blocks or agents
        block = self.game._tile_get_block((tx, ty), mi.Pushable)
        if (block is not None and
                self.game._tile_get_block((nx, ny), Agent) is None and
                self.game._tile_get_block((nx, ny), mi.Block) is None):
            self.game._move_item(block.id, location=(nx, ny))

    def __push_up(self):
        self.__dpush(0, 1)

    def __push_down(self):
        self.__dpush(0, -1)

    def __push_left(self):
        self.__dpush(-1, 0)

    def __push_right(self):
        self.__dpush(1, 0)


class Toggling(Agent):
    ''' Can toggle on current space '''
    def __init__(self, **kwargs):
        super(Toggling, self).__init__(**kwargs)
        self._add_action("toggle_switch", self.__toggle)

    def __toggle(self):
        x, y = self.location
        switch = self.game._tile_get_block((x, y), mi.Switch)
        if switch is not None:
            switch.toggle()
