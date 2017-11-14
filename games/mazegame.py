from __future__ import absolute_import
from __future__ import division
from __future__ import unicode_literals
from __future__ import print_function
import abc
import logging
import random
import six
import uuid
from collections import OrderedDict
from itertools import chain, product

from mazebase.games import featurizers
from mazebase.termcolor import cprint
from mazebase.utils import creationutils
import mazebase.utils.mazeutils as mazeutils
import mazebase.items as mi
import mazebase.items.agents as agents


class MazeGame(object):
    '''
    Give it a list of games, and MazeGame will pick a random one for
    you to play. Check BaseMazeGame for list of usable functions. This
    secretly "inherits" from BaseMazeGame.
    '''

    def __init__(self, games,
                 featurizer=featurizers.SentenceFeaturesRelative(bounds=5)):
        self.featurizer = featurizer
        self.games = games

        # Get a union of the map sizes
        max_w, max_h = zip(*[game.get_max_bounds() for game in games])
        self.__max_bounds = (max(max_w), max(max_h))

        # Overwrite the featurizer with our current one
        for game in self.games:
            game._set_featurizer(self.featurizer)
        self.reset()

    def __getattr__(self, name):
        return getattr(self.game, name)

    def all_possible_features(self):
        feats = set()
        for game in self.games:
            feats.update(game.all_possible_features())
        return feats

    def all_possible_actions(self):
        actions = set()
        for game in self.games:
            actions.update(game.all_possible_actions())
        return list(sorted(actions))

    def get_max_bounds(self):
        return self.__max_bounds

    def reset(self):
        self.game = random.choice(self.games)
        self.game.reset()

    @classmethod
    def all_features(cls):
        return []


@six.add_metaclass(abc.ABCMeta)
class BaseMazeGame(object):
    '''
    Functions of interest to use - check doctrings for details:
        observe()   Returns the current observation
        is_over()   Whether the game is in a terminal state.
        act(action) Performs action, which must be in actions()
        reward()    Reward experienced by last action
        reward_so_far()     Reward during current episode
        approx_best_reward()    Approximation of optimal reward

        reset()     Gives a random game initialization
        display()   Simply prints a visualization of the game
        actions()   Currently allowed actions for current agent
        current_agent()     Returns current agent that is acting

    Some functions to do with game properties
        get_max_bounds()    Max game map size across randomizations
        all_possible_features()     Self descriptive
        all_possible_actions()  for all possible agents
        all_features()  All features for current game
        actions()   All possible actions for current agent
        current_agent()     Which agent will act

    List of functions to override for your own games:
        Required:
            _reset()
            _finished()
            _get_reward(agent_id)
            _side_information()  Game specific info features
        To support approximating reward:
            _accumulate_approximate_rewards()  Fills game._approx_reward_map
            _calculate_approximate_reward()  Called once per reset()
        Other functionality:
            _step()  hook called after every act().

    We use the root logger to log error messages, set the logger level
    to DEBUG to expose possible errors
    '''

    __properties = dict(
        featurizer=featurizers.SentenceFeaturesRelative(bounds=5),
        map_size=(5, 10, 5, 10),  # (min_x, max_x, min_y, max_y)
        turn_penalty=0.1,
    )

    def __init__(self, **kwargs):
        '''
        kwargs:
            featurizer: featurizer to use when doing observe()
            map_size: (x_min, x_max, y_min, y_max), draw uniformly and randomly
        '''
        mazeutils.populate_kwargs(self, self.__class__.__properties, kwargs)
        super(BaseMazeGame, self).__init__()
        self.game_name = uuid.uuid4().hex
        self.__all_possible_features = None
        self.__reward = 0
        self.reset()

    ####################
    # Utility functions
    ####################

    def display(self):
        ''' Displays the game map for visualization '''
        cprint(' ' * (self.width + 2) * 3, None, 'on_white')
        for y in reversed(range(self.height)):
            cprint('   ', None, 'on_white', end="")
            for x in range(self.width):
                itemlst = sorted(filter(lambda x: x.visible, self._map[x][y]),
                                 key=lambda x: x.PRIO)
                disp = [u'   ', None, None, None]
                for item in itemlst:
                    config = item._get_display_symbol()
                    for i, v in list(enumerate(config))[1:]:
                        if v is not None:
                            disp[i] = v
                    s = config[0]
                    if s is None:
                        continue
                    d = list(disp[0])
                    for i, char in enumerate(s):
                        if char != ' ':
                            d[i] = char
                    disp[0] = "".join(d)
                text, color, bg, attrs = disp
                cprint(text, color, bg, attrs, end="")
            cprint('   ', None, 'on_white')
        cprint(' ' * (self.width + 2) * 3, None, 'on_white')
        pass

    def observe(self):
        '''
        Returns:
            id: id of current agent to make an action
            observation: featurized version of map
        '''
        id = self.current_agent()
        return {
            'id': id,
            'reward': self.__reward,
            'observation': self._featurize(id),
        }

    def is_over(self):
        return self._finished()

    def reward(self):
        ''' Reward experienced by the last action taken. 0 if no action has
        been taken.'''
        return self.__reward

    def reward_so_far(self):
        return self.__reward_so_far

    def approx_best_reward(self):
        return self.__approx_best

    def reset(self):
        '''
        Wrapper to try 100 times, since sometimes the random generation
        screws up. Calls _reset to reset the map to a random initial state.
        Override _reset when creating a new game. Reset logic is in here
        so every subclass has access to reset variables correctly.
        '''
        for i in range(100):
            try:
                self.uid = 0
                self._acting = None

                # All items in the map, inluding agents
                self._items = {}
                # Agents and their current speed.
                # An agent moves when it reaches 0 speed
                self._agents = OrderedDict()
                # All actions available. (agent_id, action_id): function
                self._actions = {}

                min_x, max_x, min_y, max_y = self.map_size
                self.width = random.randint(min_x, max_x)
                self.height = random.randint(min_y, max_y)
                self._map = [[[] for x in range(self.height)]
                             for y in range(self.width)]

                # For estimating best possible reward
                self._approx_reward_map = [[-self.turn_penalty
                                           for x in range(self.height)]
                                          for y in range(self.width)]
                self.__reward_history = dict()
                self.__reward_so_far = 0

                self._reset()
                cornerlocs = [(0, 0),
                              (0, self.height-1),
                              (self.width-1, 0),
                              (self.width-1, self.height-1),
                ]
                for loc in cornerlocs:
                    self._add_item(mi.Corner(location=loc))
                self._step()
                self._accumulate_approximate_rewards()
                self.__approx_best = self._calculate_approximate_reward()

                if self._finished():
                    actor = self.current_agent()
                    self.__reward = self._get_reward(actor)
                    self.__reward_history[actor] = self.__reward_history.get(
                        actor, 0) + self.__reward
                    self.__reward_so_far = self.__reward_history[actor]
                return
            except mazeutils.MazeException:
                logging.exception("Failed to create map because: ")
        raise RuntimeError("Failed to create map after 100 tries! Your map"
                           "size is probably too small")

    def _set_featurizer(self, featurizer):
        '''Helper function for wrappers'''
        self.featurizer = featurizer

    def get_max_bounds(self):
        '''Get maximum width and height across all random initializations'''
        _, max_w, _, max_h = self.map_size
        return max_w, max_h

    @abc.abstractmethod
    def _reset(self):
        '''
        Resets a map to an initial state. Subclass and override this function
        to create new games.
        '''
        pass

    @abc.abstractmethod
    def _finished(self):
        pass

    @abc.abstractmethod
    def _get_reward(self, id):
        reward = -self.turn_penalty
        return reward

    def _accumulate_approximate_rewards(self):
        '''
        Accumulates approximate reward of landing on a square. Used only for
        estimating best possible reward
        '''
        pass

    def _calculate_approximate_reward(self):
        '''
        Accumulates approximate reward of landing on a square. Used only for
        estimating best possible reward
        '''
        return 0

    def _in_bounds(self, location):
        # Checks whether a location is in the maze
        x, y = location
        return 0 <= x < self.width and 0 <= y < self.height

    def _tile_get_block(self, loc, typ):
        for block in self._get_items(loc):
            if isinstance(block, typ):
                return block
        return None

    def _featurize(self, id):
        return self.featurizer.featurize(self, id)

    def _side_info(self):
        '''Override _side_information instead'''
        info = self._side_information()
        for lst in info:
            lst.insert(0, 'INFO')
        return info

    def _side_information(self):
        '''Side information about the game. Shouldn't change too much and
        and encode information about the goals of the game. This list is
        _ordered_, with the information from the superclasses appearing first.

        This is the equivalent of info from mazebase1.0
        '''
        return [['GAME', type(self).__name__]]

    ####################
    # Item functions
    ####################

    def all_possible_features(self):
        '''
        All possible features in the game. Call this to generate a vocabulary
        '''
        if self.__all_possible_features is not None:
            return self.__all_possible_features
        # Circular dependencies
        import mazebase.games as games
        features = set()
        modules = [mi, mi.agents, games]
        for mod in modules:
            for name, cls in mazeutils.all_classes_of(mod):
                features.update(cls.all_features())
        features.update(self.featurizer.all_possible_features(self))
        self.__all_possible_features = list(sorted(features))
        return self.__all_possible_features

    @classmethod
    def all_features(cls):
        '''
        All new features for this game. Usually just the Map Name, and
        you don't need to touch this. If your map implements new features for
        side_info, then define a classmethod with the new features only.
        '''
        return ['GAME', 'INFO', cls.__name__, '']

    def _get_items(self, location):
        # Get item list at a location in the maze, empty if out of buonds
        x, y = location
        if not self._in_bounds(location):
            return []
        return self._map[x][y]

    def _add_item(self, item, id=None):
        assert id is None or isinstance(id, six.string_types) or '|' in id,\
            "Item id must be a string without | characters"
        self.uid += 1
        id = self.game_name + '|' + (str(self.uid) + '|' if id is None else id)
        assert id not in self._items, "Item {0} already in map...".format(id)
        self._items[id] = item

        item.game = self
        item.id = id

        x, y = item.location
        self._map[x][y].append(item)
        return id

    def _move_item(self, id, location):
        nx, ny = location
        if not self._in_bounds(location):
            return
        item = self._items[id]
        x, y = item.location
        self._map[x][y].remove(item)
        self._map[nx][ny].append(item)
        item.location = (nx, ny)

    def _remove_item(self, id):
        item = self._items[id]
        x, y = item.location
        self._map[x][y].remove(item)
        self._items.pop(id)

    ####################
    # Agent functions
    ####################

    @staticmethod
    def all_possible_actions():
        '''
        Returns all possible actions an agent can take
        '''
        actions = set()
        for name, cls in mazeutils.all_classes_of(agents):
            actions.update(cls().actions.keys())
        return list(sorted(actions))

    def actions(self):
        ''' All possible actions for current agent '''
        return sorted([action for agent, action in self._actions.keys()
                if agent == self.current_agent()])

    def current_agent(self):
        '''
        Resets which Agent is doing an action next. We use a countdown model,
        where each agent starts with a speed, and the game ticks down until
        the speed is 0. Then, the agent moves and its speed is reset.
        '''
        if self._acting is None:
            m = min(self._agents.values())
            for k, v in self._agents.items():
                self._agents[k] = v - m
                if v == m:
                    self._acting = k
        if isinstance(self._items[self._acting], agents.NPC):
            self.act(self._items[self._acting].get_npc_action())
            return self.current_agent()
        return self._acting

    def act(self, action):
        ''' Performs an action for current agent '''
        if self._finished():
            return
        actor = self.current_agent()

        # Do nothing if action isn't supported
        def noop():
            logging.debug("Action isn't supported! Passing instead")
        self._actions.get((actor, action), noop)()
        self._step()
        self._agents[actor] = self._items[actor].speed
        self._acting = None

        self.__reward = self._get_reward(actor)
        self.__reward_history[actor] = self.__reward_history.get(actor, 0) + \
            self.__reward
        self.__reward_so_far = self.__reward_history[actor]

    def _add_agent(self, agent, id):
        '''
        Agents are controllable by the player. Non-playing agents should be
        considered items. Agents must have an id to be stable between resets.
        '''
        assert id is not None, "Agent must have an id"
        id = self._add_item(agent, id)
        self._agents[id] = agent.speed
        self._actions.update(dict(((id, k), v) for
                                  k, v in agent.actions.items()))
        return id

    def _step(self):
        '''Hook that is called every time an agent acts'''
        pass


class WithWaterAndBlocksMixin(BaseMazeGame):
    ''' Subcassing this game will generate random blocks and water '''
    __properties = dict(
        waterpct=0.1,
        blockpct=0.1,
        water_penalty=0.2,
    )

    def __init__(self, **kwargs):
        mazeutils.populate_kwargs(self, self.__class__.__properties, kwargs)
        super(WithWaterAndBlocksMixin, self).__init__(**kwargs)

    def _reset(self):
        super(WithWaterAndBlocksMixin, self)._reset()
        creationutils.sprinkle(self, [(mi.Block, self.blockpct),
                                      (mi.Water, self.waterpct)])

    def _get_reward(self, id):
        reward = super(WithWaterAndBlocksMixin, self)._get_reward(id)
        if self._tile_get_block(self._items[id].location, mi.Water) is not None:
            reward += -self.water_penalty
        return reward

    def _accumulate_approximate_rewards(self):
        super(WithWaterAndBlocksMixin, self)._accumulate_approximate_rewards()
        for x, y in product(range(self.width), range(self.height)):
            if self._tile_get_block((x, y), mi.Water) is not None:
                self._approx_reward_map[x][y] += -self.water_penalty


class RewardOnEndMixin(BaseMazeGame):
    '''Subclassing this game will give a final reward that overrides other
    rewards when the episode is finished.

    This should come before any other mixin
    '''
    __properties = dict(
        goal_reward=1,
    )

    def __init__(self, **kwargs):
        mazeutils.populate_kwargs(self, self.__class__.__properties, kwargs)
        super(RewardOnEndMixin, self).__init__(**kwargs)

    def _get_reward(self, id):
        reward = super(RewardOnEndMixin, self)._get_reward(id)
        if self._finished():
            reward = self.goal_reward

        return reward

    def _calculate_approximate_reward(self):
        return super(RewardOnEndMixin, self)._calculate_approximate_reward() + \
            self.goal_reward + self.turn_penalty
        # last turn penalty not counted


class BaseVocabulary(BaseMazeGame):
    '''All the cross-game vocabulary that's needed for most games. Try to add
    as little to this as possible. Presumably games not based off of the
    mazebase gridworld structure won't need this set of vocabulary'''

    def __init__(self, **kwargs):
        self.FEATURE = self.BaseVocabStore()
        super(BaseVocabulary, self).__init__(**kwargs)

    class BaseVocabStore(object):
        '''All non-underscore variables and lists
        will be recorded as a feature'''

        def __init__(self):
            self.GOTO = "GOTO"
            self.IF = "IF"
            self.PUSH = "PUSH"
            self.AVOID = "AVOID"
            self.LEFT = "LEFT"
            self.RIGHT = "RIGHT"
            self.UP = "UP"
            self.DOWN = "DOWN"
            self.SAME = "SAME"
            self.STATE = "STATE"
            self.ALL = "ALL"
            self.SWITCH = "SWITCH"
            self.SAME = "SAME"
            self.ORDERED_OBJ = ['OBJ{0}'.format(i) for i in range(10)]

    @classmethod
    def all_features(cls):
        '''Feature mixins have to call the parent'''
        vocab = cls.BaseVocabStore()
        lst = []
        # flatten lists
        for var_name in dir(vocab):
            if var_name[0] != '_':
                v = getattr(vocab, var_name)
                lst.extend(v) if type(v) == list else lst.append(v)
        return lst + super(BaseVocabulary, cls).all_features()


class AbsoluteLocationVocabulary(mazeutils.AbsoluteLocationUtils, BaseMazeGame):
    '''Featurizer uses absolute locations'''
    def all_possible_features(self):
        return list(sorted(chain(
            super(AbsoluteLocationVocabulary, self).all_possible_features(),
            self._get_abs_loc_features(self)
        )))
