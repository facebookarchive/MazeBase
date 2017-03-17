from __future__ import absolute_import
from __future__ import division
from __future__ import unicode_literals
from __future__ import print_function
import abc
import copy
import random
import six
import types


def CurriculumWrappedGame(cls, curriculums=None, **kwargs):
    '''Introduces a curriculum by wrapping games

    Wraps a game and a set of keywords -> Curriculum mappings. By
    implementing
    custom curriculums, we can arbitrarily make games harder or easier.
    '''
    curriculums = curriculums or {}
    for kw, val in curriculums.items():
        kwargs[kw] = val.get()
    game = cls(**kwargs)

    def make_easier(self):
        random.choice(list(curriculums.values())).make_easier()

    def make_harder(self):
        random.choice(list(curriculums.values())).make_harder()

    def make_easiest(self):
        for cur in curriculums:
            cur.make_easiest()

    def make_hardest(self):
        for cur in curriculums:
            cur.make_hardest()

    max_bounds = game.get_max_bounds
    orig_reset = game.reset

    def get_max_bounds(self):
        if 'map_size' in curriculums:
            _, max_w, _, max_h = curriculums['map_size'].max
            return max_w, max_h
        return max_bounds()

    def reset(self):
        for kw, val in curriculums.items():
            setattr(self, kw, val.get())
        orig_reset()

    for func in [make_easier, make_harder, make_easiest, make_hardest,
                 get_max_bounds, reset]:
        setattr(game, func.__name__, types.MethodType(func, game))

    return game


@six.add_metaclass(abc.ABCMeta)
class CurriculumBase(object):
    '''
    self.current should store the current value of the curriculum to adjust
    '''

    def get(self):
        '''Get current value of curriculum'''
        return self.current

    @abc.abstractmethod
    def make_easier(self):
        pass

    @abc.abstractmethod
    def make_harder(self):
        pass

    @abc.abstractmethod
    def make_hardest(self):
        pass

    @abc.abstractmethod
    def make_easiest(self):
        pass


class NumericCurriculum(CurriculumBase):
    '''A curriculum on an integer variable

    Args:
        init: Where to start the curriculum
        min: minimum value to take
        max: maximum value to take
        step: harder and easier will adjust by step size
            this can be a callable function, if you want to generate steps
            randomly for example
    '''
    def __init__(self, init, min, max, step=1):
        assert min <= init <= max, "NumericCurriculum must be initialized"\
            "between min and max"
        self.min = min
        self.max = max
        self.step = step
        self.current = init
        if not callable(self.step):
            self.step = lambda: step

    def make_easier(self):
        self.current = max(self.current - self.step(), self.min)

    def make_harder(self):
        self.current = min(self.current + self.step(), self.max)

    def make_easiest(self):
        self.current = self.min

    def make_hardest(self):
        self.current = self.max


class MapSizeCurriculum(CurriculumBase):
    '''A curriculum on an integer variable

    Note:
        All arguments are of the form (min_x, max_x, min_y, max_y)
        Adjustment will try to move one of the values by 1, respecting that
        min will always be less than max. Sometimes, the adjustment will not
        move.

    Args:
        init: Where to start the curriculum
        min: minimum value to take
        max: maximum value to take
        step: harder and easier will adjust by step size
    '''
    def __init__(self, init, min, max):
        self.min = list(min)
        self.max = list(max)
        self.current = list(init)
        for init_v, max_v, min_v in zip(init, max, min):
            assert min_v <= init_v <= max_v, \
                "Initial sizes must be between min and max in MapSizeCurriculum"

    def __update(self, delta):
        ind = random.choice(range(4))
        self.current[ind] = self.current[ind] + delta

        # Enforce that current never moves above the min and max
        self.current[ind] = min(self.current[ind], self.max[ind])
        self.current[ind] = max(self.current[ind], self.min[ind])

        # Enforce that min never moves above max and vice versa
        if ind == 0:
            self.current[0] = min(self.current[0], self.current[1])
        if ind == 1:
            self.current[1] = max(self.current[0], self.current[1])
        if ind == 2:
            self.current[2] = min(self.current[2], self.current[3])
        if ind == 3:
            self.current[3] = max(self.current[2], self.current[3])

    def make_easier(self):
        self.__update(-1)

    def make_harder(self):
        self.__update(1)

    def make_easiest(self):
        self.current = copy.copy(self.min)

    def make_hardest(self):
        self.current = copy.copy(self.max)
