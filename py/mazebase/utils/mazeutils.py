from __future__ import absolute_import
from __future__ import division
from __future__ import unicode_literals
from __future__ import print_function
import inspect
import random
from itertools import product


def populate_kwargs(self, properties, kwargs):
    ''' Fills self based on keywords in properties '''
    for k, v in properties.items():
        value = kwargs[k] if k in kwargs else v
        if not hasattr(self, k):
            setattr(self, k, value)


def all_classes_of(mod):
    return inspect.getmembers(mod, lambda member: inspect.isclass(member) and
                              mod.__name__ in member.__module__)


class AbsoluteLocationUtils(object):
    @staticmethod
    def _get_abs_loc_features(game):
        fts = set()
        max_w, max_h = game.get_max_bounds()
        for x, y in product(range(max_w), range(max_h)):
            fts.add(AbsoluteLocationUtils._coords2loc(x, y))
        return sorted(list(fts))

    @staticmethod
    def _coords2loc(x, y):
        return "{0}x{1}y".format(x, y)


class MazeException(Exception):
    ''' Exception in creating maze, may try again after catching '''
    pass


def choice(lst):
    ''' So mazebase can catch these exceptions '''
    if len(lst) == 0:
        raise MazeException("Running choice on empty list")
    return random.choice(lst)
