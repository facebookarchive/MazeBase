from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
from mazebase.items import MazeItem


class HasStatesMixin(object):
    _MAX_STATES = 10
    STATE_FEATURE = ["state{0}".format(i) for i in range(_MAX_STATES)]

    @classmethod
    def all_features(cls):
        return super(HasStatesMixin, cls).all_features() + cls.STATE_FEATURE


class Block(MazeItem):
    def __init__(self, **kwargs):
        super(Block, self).__init__(passable=False, **kwargs)

    def _get_display_symbol(self):
        return (None, None, 'on_white', None)


class Water(MazeItem):
    def __init__(self, **kwargs):
        super(Water, self).__init__(**kwargs)
        self.PRIO = -100

    def _get_display_symbol(self):
        return (None, None, 'on_blue', None)


class Corner(MazeItem):
    def __init__(self, **kwargs):
        super(Corner, self).__init__(**kwargs)

    def _get_display_symbol(self):
        return (u'   ', None, None, None)


class Goal(MazeItem):
    __MAX_GOAL_IDS = 10

    def __init__(self, id=0, **kwargs):
        super(Goal, self).__init__(**kwargs)
        self.goal_id = id
        assert self.goal_id < self.__MAX_GOAL_IDS,\
            "cannot create goal with id >{0}".format(
                self.__MAX_GOAL_IDS)

    def _get_display_symbol(self):
        return (u'*{0}*'.format(self.goal_id), 'red', None, None)

    def featurize(self):
        return super(Goal, self).featurize() +\
            ["goal_id" + str(self.goal_id)]

    @classmethod
    def all_features(cls):
        return super(Goal, cls).all_features() +\
            ["goal_id" + str(k) for k in range(cls.__MAX_GOAL_IDS)]


class Breadcrumb(MazeItem):
    def __init__(self, **kwargs):
        super(Breadcrumb, self).__init__(**kwargs)
        self.PRIO = -50

    def _get_display_symbol(self):
        return (u' . ', None, None, None)


class Pushable(Block):
    def __init__(self, **kwargs):
        super(Pushable, self).__init__(**kwargs)

    def _get_display_symbol(self):
        return (None, None, 'on_green', None)


class Switch(HasStatesMixin, MazeItem):
    def __init__(self, start_state=0, nstates=2, **kwargs):
        super(Switch, self).__init__(**kwargs)
        self.state = start_state
        self.nstates = nstates
        assert self.nstates < HasStatesMixin._MAX_STATES,\
            "cannot create switches with >{0} states".format(
                self.__MAX_SWITCH_STATES)

    def _get_display_symbol(self):
        return (str(self.state).rjust(3), 'cyan', None, None)

    def toggle(self):
        self.state = (self.state + 1) % self.nstates

    def featurize(self):
        return super(Switch, self).featurize() +\
            [self.STATE_FEATURE[self.state]]


class Door(HasStatesMixin, MazeItem):
    def __init__(self, open=False, state=0, **kwargs):
        super(Door, self).__init__(**kwargs)
        self.isopen = open
        self.state = state

    def _get_display_symbol(self):
        return (None if self.isopen else u'\u2588{0}\u2588'.format(self.state),
                None, None, None)

    def open(self):
        self.isopen = True

    def close(self):
        self.isopen = False

    def toggle(self):
        self.isopen = not self.isopen

    def featurize(self):
        return super(Door, self).featurize() + \
            ["open" if self.isopen else "closed", self.STATE_FEATURE[self.state]]

    @classmethod
    def all_features(cls):
        return super(Door, cls).all_features() +\
            ["open", "closed"]
