import numpy as np
cimport numpy as np

from AlphaGo import go
from AlphaGo import util

from bamboo.go.board cimport PASS, game_state_t
from bamboo.util cimport SGFMoveIterator
from bamboo.util_error import IllegalMove, TooFewMove, TooManyMove, SizeMismatchError
from bamboo.go.printer cimport print_board

from tqdm import tqdm

def check_all_sgf_play_equals(d):
    import os
    import glob
    for f in tqdm(glob.glob(os.path.join(d, '*'))):
        if not is_sgf_play_equals(f):
            break

def is_sgf_play_equals(sgf_file):
    cdef game_state_t *cygame
    cdef SGFMoveIterator cyiter
    cdef int i    

    np.set_printoptions(linewidth=200)
    sgf_string = open(sgf_file).read()

    pyiter = util.sgf_iter_states(sgf_string)
    try:
        cyiter = SGFMoveIterator(19, sgf_string, ignore_not_legal=False)
    except (TooFewMove, TooManyMove, SizeMismatchError):
        return True

    cygame = cyiter.game
    while True:
        pylegal = True
        cylegal = True
        try:
            try:
                (pygame, pymove, pyplayer) = pyiter.next()
            except go.IllegalMove:
                pylegal = False

            try:
                cymove = cyiter.next()
                if cymove[0] == PASS or cymove is None:
                    cymove_tuple = None
                else:
                    cymove_tuple = divmod(cymove[0], 23)
                    cymove_tuple = (cymove_tuple[1]-2, cymove_tuple[0]-2)
            except IllegalMove:
                cylegal = False


            cyplayer = cygame.current_color

            if pylegal and cylegal:
                #print('PyMove: ({:s}, {:s}) CyMove: ({:s}, {:s})'.format(str(pyplayer), str(pymove), str(cymove[1]), str(cymove_tuple)))
                if pymove != cymove_tuple:
                    print('{:s} Move not match py {:s} != cy {:s}'.format(sgf_file, str(pymove), str(cymove_tuple)))
                    break
                if (pyplayer == 1 and cymove[1] == 2) or (pyplayer == -1 and cymove[1] == 1):
                    print('{:s} Player not match. py {:s} != cy {:s}'.format(sgf_file, str(pyplayer), str(cymove[1])))
                    break

            if pylegal != cylegal:
                if pylegal:
                    illegal_move = cymove_tuple
                    illegal_player = cyplayer
                else:
                    illegal_move = pymove
                    illegal_player = pyplayer

                print('{:s} IllegalMove in one. py {:s} != cy {:s} move: {:s} player: {:s}' \
                    .format(sgf_file, str(pylegal), str(cylegal), str(illegal_move), str(illegal_player)))
                pyboard = np.transpose(pygame.board)
                #if not pylegal:
                #    pyboard[illegal_move[1], illegal_move[0]] = 9
                cyboard = np.zeros((529), dtype=np.int32)
                for i in range(529):
                    cyboard[i] = cygame.board[i]

                cyboard = cyboard.reshape((23, 23))
                cyboard = cyboard[2:21, 2:21]
                cyboard[cyboard == 2] = -1
                #if not cylegal:
                #    cyboard[illegal_move[1], illegal_move[0]] = 9
                print('Pyboard:')
                print(str(pyboard))
                print('\nCyboard:')
                print(str(cyboard))
                print('\nEquality:')
                print(pyboard == cyboard)
                print_board(cygame)

                return False

        except StopIteration:
            break

    pyboard = np.transpose(pygame.board)

    cyboard = np.zeros((529), dtype=np.int32)
    for i in range(529):
        cyboard[i] = cygame.board[i]

    cyboard = cyboard.reshape((23, 23))
    cyboard = cyboard[2:21, 2:21]
    cyboard[cyboard == 2] = -1

    if np.all(pyboard == cyboard):
        #print('{:s} Match'.format(sgf_file))
        return True
    else:
        print('{:s} Mismatch'.format(sgf_file))
        print('Pyboard:')
        print(pyboard)
        print('\nCyboard:')
        print(cyboard)
        print('\nEquality:')
        print(pyboard == cyboard)
        return False