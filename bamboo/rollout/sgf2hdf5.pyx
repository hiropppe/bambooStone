#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np
cimport numpy as np
import os
import warnings
import sgf
import sys
import traceback
import tables
import time
import h5py

from tqdm import tqdm

from bamboo.util_error import SizeMismatchError, IllegalMove, TooManyMove, TooFewMove

from bamboo.util cimport SGFMoveIterator
from bamboo.go.board cimport PURE_BOARD_MAX, S_BLACK, S_WHITE, PASS, POS, CORRECT_X, CORRECT_Y
from bamboo.go.board cimport game_state_t, pure_board_size, pure_board_max, onboard_index
from bamboo.go.printer cimport print_board
from bamboo.rollout.pattern cimport initialize_hash, init_nakade_hash, init_x33_hash, init_d12_hash
from bamboo.rollout.pattern cimport x33_hash, x33_hashmap
from bamboo.rollout.preprocess cimport RolloutFeature, rollout_feature_t


cdef class GameConverter(object):

    cdef:
        RolloutFeature preprocessor
        int bsize
        int nakade_size, x33_size, d12_size
        int n_features
        list update_speeds

    def __cinit__(self, bsize=19, nakade_file=None, x33_file=None, d12_file=None):
        self.bsize = bsize

        initialize_hash()
        self.nakade_size = init_nakade_hash(nakade_file)
        self.x33_size = init_x33_hash(x33_file)
        self.d12_size = init_d12_hash(d12_file)
        self.update_speeds = list()

    def __dealloc__(self):
        pass

    def convert_game_as_onehot_index_board(self, file_name, verbose=False):
        cdef game_state_t *game
        cdef SGFMoveIterator sgf_iter
        cdef rollout_feature_t *feature
        cdef int i, j

        self.preprocessor = RolloutFeature(self.nakade_size,
                                           self.x33_size,
                                           self.d12_size)
        self.n_features = self.preprocessor.feature_size

        with open(file_name, 'r') as file_object:
            sgf_iter = SGFMoveIterator(self.bsize, file_object.read())

        game = sgf_iter.game
        try:
            # update initial state
            if sgf_iter.next_move[0] != PASS:
                next_move = sgf_iter.next_move
                self.preprocessor.update(game)
                feature = &self.preprocessor.feature_planes[<int>game.current_color]
                onehot_index_array = np.asarray(feature.tensor)
                if onboard_index[next_move[0]] >= pure_board_max:
                    raise IllegalMove()
                else:
                    yield (onehot_index_array, onboard_index[next_move[0]])

            for i, move in enumerate(sgf_iter):
                next_move = sgf_iter.next_move
                if move[0] != PASS and next_move and next_move[0] != PASS:
                    s = time.time()
                    self.preprocessor.update(game)
                    self.update_speeds.append(time.time()-s)
                    feature = &self.preprocessor.feature_planes[<int>game.current_color]
                    onehot_index_array = np.asarray(feature.tensor)
                    if onboard_index[next_move[0]] >= pure_board_max:
                        raise IllegalMove()
                    else:
                        yield (onehot_index_array, onboard_index[next_move[0]])
        except IllegalMove:
            warnings.warn('IllegalMove {:d}[{:d}] at {:d} in {:s}\n'.format(move[1], move[0], i, file_name))
            if verbose:
                err, msg, _ = sys.exc_info()
                sys.stderr.write("{} {}\n".format(err, msg))
                sys.stderr.write(traceback.format_exc())

    def sgfs_to_onehot_index_board(self,
                     sgf_files,
                     hdf5_file,
                     ignore_errors=True, verbose=False, quiet=False):
        """ Save each feature onehot index in board shape matrix.
        """
        tmp_file = os.path.join(os.path.dirname(hdf5_file), ".tmp." + os.path.basename(hdf5_file))
        h5f = h5py.File(tmp_file, 'w')

        try:
            states = h5f.require_dataset(
                'states',
                dtype=np.int32,
                shape=(1, 6, PURE_BOARD_MAX),
                maxshape=(None, 6, PURE_BOARD_MAX),  # 'None' == arbitrary size
                exact=False, 
                chunks=(64, 6, PURE_BOARD_MAX),
                compression="lzf")
            actions = h5f.require_dataset(
                'actions',
                dtype=np.int32,
                shape=(1, 1),
                maxshape=(None, 1),
                exact=False,
                chunks=(1024, 1),
                compression="lzf")

            # 'file_offsets' is an HDF5 group so that 'file_name in file_offsets' is fast
            file_offsets = h5f.require_group('file_offsets')

            if verbose:
                print("created HDF5 dataset in {}".format(tmp_file))

            next_idx = 0
            n_parse_error = 0
            n_not19 = 0
            n_too_few_move = 0
            n_too_many_move = 0
            for file_name in tqdm(sgf_files):
                if verbose:
                    print(file_name)
                n_pairs = 0
                file_start_idx = next_idx
                try:
                    for state, move in self.convert_game_as_onehot_index_board(file_name):
                        if next_idx >= len(states):
                            states.resize((next_idx + 1, 6, PURE_BOARD_MAX))
                            actions.resize((next_idx + 1, 1))
                        states[next_idx] = state
                        actions[next_idx] = move
                        n_pairs += 1
                        next_idx += 1
                except sgf.ParseException:
                    n_parse_error += 1
                    warnings.warn('ParseException. {:s}'.format(file_name))
                    if verbose:
                        err, msg, _ = sys.exc_info()
                        sys.stderr.write("{} {}\n".format(err, msg))
                        sys.stderr.write(traceback.format_exc())
                except SizeMismatchError:
                    n_not19 += 1
                except TooFewMove as e:
                    n_too_few_move += 1
                    warnings.warn('Too few move. {:d} less than 50. {:s}'.format(e.n_moves, file_name))
                except TooManyMove as e:
                    n_too_many_move += 1
                    warnings.warn('Too many move. {:d} more than 500. {:s}'.format(e.n_moves, file_name))
                except KeyboardInterrupt:
                    break
                finally:
                    if n_pairs > 0:
                        # '/' has special meaning in HDF5 key names, so they
                        # are replaced with ':' here
                        file_name_key = file_name.replace('/', ':')
                        file_offsets[file_name_key] = [file_start_idx, n_pairs]
                        if verbose:
                            print("\t%d state/action pairs extracted" % n_pairs)
                    elif verbose:
                        print("\t-no usable data-")
        except Exception as e:
            print("sgfs_to_onehot_index_array failed")
            err, msg, _ = sys.exc_info()
            sys.stderr.write("{} {}\n".format(err, msg))
            sys.stderr.write(traceback.format_exc())
            os.remove(tmp_file)
            raise e

        h5f['n_features'] = self.n_features

        if verbose:
            print("finished. renaming %s to %s" % (tmp_file, hdf5_file))

        print('Total {:d}/{:d} (Not19 {:d} ParseErr {:d} TooFewMove {:d} TooManyMove {:d})'.format(
            len(sgf_files) - n_parse_error - n_not19 - n_too_few_move - n_too_many_move,
            len(sgf_files),
            n_parse_error,
            n_not19,
            n_too_few_move,
            n_too_many_move))
        print('Update Speed: Avg. {:3f} us'.format(np.mean(self.update_speeds)*1000*1000))

        # processing complete; rename tmp_file to hdf5_file
        h5f.close()
        os.rename(tmp_file, hdf5_file)
