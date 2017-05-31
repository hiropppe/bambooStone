# -*- coding: utf-8 -*-

cdef extern from "common.h":
    int MAX(int x, int y)
    int MIN(int x, int y)

cdef extern from "ray.h":
    int PURE_BOARD_SIZE
    int PURE_BOARD_MAX
    int OB_SIZE
    int BOARD_SIZE
    int BOARD_MAX
    int MAX_STRING
    int MAX_NEIGHBOR 
    int BOARD_START
    int BOARD_END
    int STRING_LIB_MAX
    int STRING_POS_MAX
    int STRING_END
    int NEIGHBOR_END
    int LIBERTY_END
    int MAX_RECORDS
    int MAX_MOVES
    int PASS
    int RESIGN
    int KOMI

    int POS(int x, int y, int board_size)
    int X(int pos, int board_size)
    int Y(int pos, int board_size)
    int CORRECT_X(int pos, int board_size, int ob_size)
    int CORRECT_Y(int pos, int board_size, int ob_size)
    int NORTH(int pos, int board_size)
    int WEST(int pos)
    int EAST(int pos)
    int SOUTH(int pos, int board_size)

    char FLIP_COLOR(char color)

    int MOVE_DISTANCE_MAX

    ctypedef enum stone:
        S_EMPTY
        S_BLACK
        S_WHITE
        S_OB
        S_MAX

    ctypedef enum eye_condition_e:
        E_NOT_EYE
        E_COMPLETE_HALF_EYE
        E_HALF_3_EYE
        E_HALF_2_EYE
        E_HALF_1_EYE
        E_COMPLETE_ONE_EYE
        E_MAX

    ctypedef struct move_t:
        int color
        int pos

    ctypedef struct string_t:
        char color
        int libs
        short *lib
        int neighbors
        short *neighbor
        int origin
        int size
        bint flag

    ctypedef struct pattern_t:
        unsigned int *list
        unsigned long long *large_list

    ctypedef struct game_state_t:
        char current_color
        move_t *record
        int moves
        int *prisoner
        int ko_pos
        int ko_move

        unsigned long long current_hash

        char *board
        int *birth_move

        int pass_count

        pattern_t *pat

        string_t *string
        int *string_id
        int *string_next

        int *candidates

        int *capture_num

        bint rollout


cdef int pure_board_size
cdef int pure_board_max

cdef int board_size
cdef int board_max

cdef int max_string
cdef int max_neighbor

cdef int board_start
cdef int board_end

cdef int string_lib_max
cdef int string_pos_max

cdef int string_end
cdef int neighbor_end
cdef int liberty_end

cdef int max_records
cdef int max_moves

cdef double *komi
cdef double *dynamic_komi
cdef double default_komi

cdef int *board_pos_id

cdef int *board_x
cdef int *board_y

cdef int *board_dis_x
cdef int *board_dis_y

cdef int[:, ::1] move_dis

cdef int *onboard_pos

cdef int *corner
cdef int[:, ::1] corner_neighbor

cdef unsigned char eye[65536]           # PAT3_MAX
cdef unsigned char false_eye[65536]     # PAT3_MAX
cdef unsigned char territory[65536]     # PAT3_MAX
cdef unsigned char nb4_empty[65536]     # PAT3_MAX
cdef unsigned char eye_condition[65536] # PAT3_MAX


cdef void fill_n_char (char *arr, int size, char v)
cdef void fill_n_short (short *arr, int size, short v)
cdef void fill_n_int (int *arr, int size, int v)

cdef void initialize_const()
cdef void set_board_size(int size)

cdef game_state_t *allocate_game()
cdef void free_game(game_state_t *game)
cdef void copy_game(game_state_t *dst, game_state_t *src)
cdef void initialize_board(game_state_t *game, bint rollout)

cdef bint do_move(game_state_t *game, int pos)

cdef bint put_stone(game_state_t *game, int pos, char color)
cdef void connect_string(game_state_t *game, int pos, char color, int connection, int string_id[4])
cdef void merge_string(game_state_t *game, string_t *dst, string_t *src[3], int n)
cdef void add_stone(game_state_t *game, int pos, char color, int string_id)
cdef void add_stone_to_string(game_state_t *game, string_t *string, int pos, int head)
cdef void make_string(game_state_t *game, int pos, char color)
cdef int remove_string(game_state_t *game, string_t *string)


cdef int add_liberty(string_t *string, int pos, int head)
cdef void remove_liberty(string_t *string, int pos)
cdef void add_neighbor(string_t *string, int id, int head)
cdef void remove_neighbor_string(string_t *string, int id)
cdef void get_neighbor4(int neighbor4[4], int pos)
cdef void init_board_position()
cdef void init_line_number()
cdef void init_move_distance()
cdef void init_board_position_id()
cdef void init_corner()
cdef void initialize_neighbor()
cdef void initialize_eye()
cdef int get_neighbor4_empty(game_state_t *game, int pos)
cdef bint is_legal(game_state_t *game, int pos, char color)
cdef bint is_legal_not_eye(game_state_t *game, int pos, char color)
cdef bint is_suicide(game_state_t *game, int pos, char color)
