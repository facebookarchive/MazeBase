from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals
import abc
import itertools
import six
from mazebase.utils.mazeutils import AbsoluteLocationUtils

MAX_SENTENCE_SIZE = 10


########################
# Abstract classes
########################

@six.add_metaclass(abc.ABCMeta)
class Featurizer(object):

    @abc.abstractmethod
    def featurize(self, game, id):
        pass

    @abc.abstractmethod
    def all_possible_features(self, game):
        '''Extra features added by the featurizer'''
        return ['']


@six.add_metaclass(abc.ABCMeta)
class BaseGridFeaturizer(Featurizer):
    def __init__(self, *args, **kwargs):
        self.max_info_length = kwargs.pop('max_info_length', 10)
        self.max_infos = kwargs.pop('max_infos', 10)

    def featurize(self, game, id):
        features = (self._featurize_grid(game, id),
                    self._featurize_side_info(game, id))
        return features

    def _featurize_side_info(self, game, id):
        features = game._side_info()
        if len(features) > self.max_info_length:
            raise Exception("Too much side info too long to featurize")
        features += [[] for i in range(self.max_infos - len(features))]
        for feat in features:
            if len(feat) > self.max_info_length:
                raise Exception("Info feature too long")
            feat += [""] * (self.max_info_length - len(feat))
        return features

    @abc.abstractmethod
    def _featurize_grid(self, game, id):
        pass


@six.add_metaclass(abc.ABCMeta)
class SentenceFeaturizer(Featurizer):
    ''' Abstract class for sentence based featurizers '''
    def __init__(self, *args, **kwargs):
        self.max_sentence_length = kwargs.pop('max_sentence_length', 10)
        self.max_sentences = kwargs.pop('max_sentences', 100)

    def featurize(self, game, id):
        features = self._featurize(game, id) + game._side_info()
        if len(features) > self.max_sentences:
            raise Exception("Too many objects to featurize")
        # Do padding for features
        features += [[] for i in range(self.max_sentences - len(features))]
        for feat in features:
            if len(feat) > self.max_sentence_length:
                raise Exception("Sentence feature too long")
            feat += [""] * (self.max_sentence_length - len(feat))
        return features

    @abc.abstractmethod
    def _featurize(self, game, id):
        pass


class AbsoluteLocationMixin(AbsoluteLocationUtils):
    '''Featurizer uses absolute locations'''
    def all_possible_features(self, game):
        return self._get_abs_loc_features(game)


class RelativeLocationMixin(object):
    '''Featurizer uses relative locations.
    bounds specifies maximum 'sight' range'''
    def __init__(self, **kwargs):
        self.bounds = kwargs.pop('bounds', 5)
        super(RelativeLocationMixin, self).__init__(**kwargs)

    def all_possible_features(self, game):
        fts = set(super(RelativeLocationMixin, self)
                  .all_possible_features(game))
        for x, y in itertools.product(range(-self.bounds, self.bounds),
                                      range(-self.bounds, self.bounds)):
            fts.add(self._coords2loc(x, y))
        return list(sorted(fts))

    @staticmethod
    def _coords2loc(x, y):
        return "d{0}x{1}y".format(x, y)

########################
# Featurizers
########################


class GridFeaturizer(BaseGridFeaturizer):
    '''
    A list of featurizations of objects, in a matrix of width by height.
    Call game.all_possible_features to get a dictionary of all features.

    Returns:
        [
            grid_features: featurize the game world like a grid,
            side_info: game specific info blocks, in an ordered list
        ]
    '''

    def _featurize_grid(self, game, id):
        max_w, max_h = game.get_max_bounds()
        features = [[[] for y in range(max_w)]
                     for x in range(max_h)]
        for (x, y) in itertools.product(range(game.width), range(game.height)):
            itemlst = game._map[x][y]
            for item in itemlst:
                if not item.visible:
                    continue
                features[x][y] += item.featurize()

        return features

    def all_possible_features(self, game):
        return super(GridFeaturizer, self).all_possible_features(game)


class RelativeGridFeaturizer(AbsoluteLocationMixin, BaseGridFeaturizer):
    '''
    A list of featurizations of objects, in a matrix of width by height.
    Call game.all_possible_features to get a dictionary of all features.

    kwargs:
        bounds
        notify = add OUT_OF_BOUNDS features or not

    Returns:
        [
            grid_features: featurize the game world like a grid,
            side_info: game specific info blocks, in an ordered list
        ]
    '''
    def __init__(self, **kwargs):
        self.bounds = kwargs.pop('bounds', 5)
        self.notify = kwargs.pop('notify', False)
        super(RelativeGridFeaturizer, self).__init__(**kwargs)

    def _featurize_grid(self, game, id):
        tx, ty = game._items[id].location
        max_w, max_h = game.get_max_bounds()
        features = [[[] for y in range(2 * self.bounds - 1)]
                     for x in range(2 * self.bounds - 1)]
        center = self.bounds - 1
        features[center][center].append(self._coords2loc(tx, ty))
        for (x, y) in itertools.product(range(2 * self.bounds - 1),
                                        range(2 * self.bounds - 1)):
            nx, ny = tx + x - center, ty + y - center
            if not (0 <= nx < game.width and 0 <= ny < game.height):
                if self.notify: features[x][y].append("OUT_OF_BOUNDS")
                continue
            itemlst = game._map[nx][ny]
            for item in itemlst:
                if not item.visible:
                    continue
                features[x][y] += item.featurize()

        return features

    def all_possible_features(self, game):
        fts = super(RelativeGridFeaturizer, self).all_possible_features(game)
        fts += ["OUT_OF_BOUNDS"]
        return list(sorted(fts))


class SentenceFeaturesAbsolute(AbsoluteLocationMixin, SentenceFeaturizer):
    '''
    A list of featurizations of objects in the map. The objects are given as
    "sentences", with an absolute location in the map.

    kwargs:
        max_sentence_length
        max_sentences
    '''

    def __init__(self, **kwargs):
        super(SentenceFeaturesAbsolute, self).__init__(**kwargs)

    def _featurize(self, game, id):
        max_w, max_h = game.get_max_bounds()
        features = []
        for id, item in game._items.items():
            if not item.visible:
                continue
            feat = item.featurize()
            location_feature = self._coords2loc(*item.location)
            features.append([location_feature] + feat)

        return features


class SentenceFeaturesRelative(RelativeLocationMixin, SentenceFeaturizer):
    '''
    A list of featurizations of objects in the map. The objects are given as
    "sentences", with an absolute location in the map. You can initialize
    this with a parameter that decides how far the agent can see.

    kwargs:
        max_sentence_length
        max_sentences
        bounds
    '''

    def _featurize(self, game, id):
        tx, ty = game._items[id].location
        max_w, max_h = game.get_max_bounds()
        features = []
        for id, item in game._items.items():
            if not item.visible:
                continue
            x, y = item.location
            dx, dy = tx - x, ty - y
            if not (-self.bounds < dx < self.bounds and
                    -self.bounds < dy < self.bounds):
                continue
            feat = item.featurize()
            location_feature = self._coords2loc(dx, dy)
            features.append([location_feature] + feat)

        return features

##########################
# Utility functions
##########################


def vocabify(game, observation, np=None):
    '''
    Changes the outputs of SentenceFeaturizer subclasses to a numerical
    representation. Also works on side_info.

    Pass in numpy module to np to use it instead of lists.
    '''
    vocab = dict([(b, a) for a, b in
                  enumerate(game.all_possible_features())])
    if np is None:
        for sent in observation:
            for i, word in enumerate(sent):
                sent[i] = vocab[word]
        return observation
    else:
        shape = (len(observation), len(observation[0]))
        arr = np.zeros(shape)
        for x, y in itertools.product(range(shape[0]), range(shape[1])):
            arr[x][y] = vocab[observation[x][y]]
        return arr


def grid_one_hot(game, observation, np=None):
    '''
    THIS ISN'T ACTUALLY ONE HOT, IT IS FEW HOT

    In place transformation:
    Changes the outputs of GridFeaturizers to a few hot representation,
    with feature plane size `x \\times y \\times nfeatures`.

    pass in the numpy module to np to return a numpy array,
    which is far more efficient than using lists.
    '''
    vocab = dict([(b, a) for a, b in
                  enumerate(game.all_possible_features())])
    if np is None:
        for x, col in enumerate(observation):
            for y, lst in enumerate(col):
                features = [0 for w in vocab]
                for feat in lst:
                    features[vocab[feat]] = 1
                observation[x][y] = features
        return observation
    else:
        xm, ym, zm = len(observation[0]), len(observation[1]), len(vocab)
        arr = np.zeros((xm, ym, zm))
        for x, y in itertools.product(range(xm), range(ym)):
            for feat in observation[x][y]:
                arr[x][y][vocab[feat]] = 1
        return arr


def grid_one_hot_sparse(game, observation, np=None):
    '''
    No longer in place.

    Returns a sparse list of (x, y, vocab_i), but otherwise same as above.

    Mostly used for python-lua bridge, since the communication costs
    there are relatively high
    '''
    vocab = dict([(b, a) for a, b in
                  enumerate(game.all_possible_features())])
    res = []
    for x, col in enumerate(observation):
        for y, lst in enumerate(col):
            for feat in lst:
                res.append((x, y, vocab[feat]))
    return res
