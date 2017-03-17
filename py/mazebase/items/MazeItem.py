from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
import abc
import six
from copy import deepcopy

from mazebase.utils.mazeutils import populate_kwargs


@six.add_metaclass(abc.ABCMeta)
class MazeItem(object):
    '''
    Maze items should not share state
    PRIO determines priority of visibility when viewing the object,
        and has no effect on the game. A higher priority object is always
        diplayed first
    '''

    __properties = dict(
        location=(0, 0),
        visible=True,
        passable=True,
    )

    def __init__(self, **kwargs):
        populate_kwargs(self, self.__class__.__properties, kwargs)

        self.game = None
        self.PRIO = 0

    def _get_display_symbol(self):
        '''
        -> (text, foreground, background, attributes)

        text: should be 3 characters
        foreground: see termcolor.py
        background: see termcolor.py
        attributes: see termcolor.py
        '''
        return (None, None, None, None)

    def clone(self):
        return deepcopy(self)

    def featurize(self):
        ''' Return a list of the features for this item '''
        return [type(self).__name__]

    @classmethod
    def all_features(cls):
        '''
        All possible features for this item.
        Must implement if subclass implements featurize()
        '''
        return [cls.__name__]
