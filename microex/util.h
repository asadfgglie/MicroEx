#include "../lib/uthash.h"
#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>

#define DTYPE_NAME_LEN 10 // strlen(data_type) maximun output
#define SIZE_T_CHARLEN 30 // for size_t to string conversion, 30 is enough for 64-bit size_t
#define MAX_ERROR_MSG_LEN 256
// `&` ensures that symbols do not conflict with user-defined symbols
#define TEMP_SYMBOL_PREFIX "temp&"
// "%s%zu", TEMP_SYMBOL_PREFIX, NUMBER_OF_TEMP_SYMBOL_TABLE
#define FN_LOCAL_SYMBOL_PREFIX "fn&"
// full temp prefix: "%s%s", FN_LOCAL_SYMBOL_PREFIX, TEMP_SYMBOL_PREFIX
// full function local var prefix: "%s", FN_LOCAL_SYMBOL_PREFIX
#define FN_RETURN_SYMBOL_PREFIX "ret&"
#define FN_ARG_LABEL_PREFIX "fn_arg&"
// `fn_arg&` ensures that symbol do not conflict with user-defined/auto-generated symbols
#define FN_NAME_LABEL_PREFIX "fn_name&"
#define LABEL_PREFIX "label&" // label for jump instruction
#define LINE_PREFIX "line&" //src code line label for debug
#define COMMENT_PREFIX "comment&" // comment label for debug
#define TEMP_DECLARE_LABEL "temp_var_declare&"
#define START_LABEL "start&"

#define SYMBOL_INIT(s, name_var) do {               \
    s->name = name_var;                             \
    s->type = TYPE_UNKNOWN;                         \
                                                    \
    s->array_info.dimensions = 0;                   \
    s->array_info.dimension_sizes = NULL;           \
    s->array_info.is_static_checkable = true;       \
                                                    \
    s->array_pointer.dimensions = 0;                \
    s->array_pointer.dimension_sizes = NULL;        \
    s->array_pointer.is_static_checkable = true;    \
                                                    \
    s->function_info = NULL;                        \
    s->is_static_checkable = true;                  \
} while (false)



typedef struct symbol symbol;

typedef struct function_info {
    char *name; // function name, same pointer with symbol->name
    size_t argc; // number of args
    symbol **args; // positional args
    symbol *return_arg; // return args
    
    symbol *local_symbol_table; // store local variables
} function_info;

typedef enum data_type {
    TYPE_UNKNOWN,
    
    TYPE_PROGRAM_NAME,

    TYPE_INT,
    TYPE_DOUBLE,
    TYPE_BOOL,

    TYPE_FUNCTION,

    TYPE_STRING, // actually, this will not be used in microex, but for future compatibility
} data_type; // data type for symbol table

typedef enum direction {
    DIRECTION_TO,
    DIRECTION_DOWNTO
} direction; // direction for for loop, used in yacc code

typedef struct {
    size_t dimensions; // number of dimensions, 0 for non-array
    size_t *dimension_sizes; // array each dimension sizes
    symbol **dimension_sizes_symbol; 
    // symbol for each dimension sizes, 
    // used for dynamic array access when the dimension sizes are not known at compile time

    bool is_static_checkable; 
    // whether this array can be checked at static time, e.g. array bounds, index error etc.
} array_type;

typedef struct symbol {
    char *name;
    data_type type;

    array_type array_info; // used for declare array and shape
    array_type array_pointer; // used for expression to locate array index
    // all array infomation will be ignore if symbol is function

    function_info *function_info; // Not NULL when type == TYPE_FUNCTION

    union {
        long long int_val;
        double double_val;
        bool bool_val; // actually, this will be implemented as integer 0 and 1 in microex
        // but we still use bool in semantic analysis for clarity

        char *str_val;
        // for string, we use char* to store the string value
        // in microex, string is not supported, but for future compatibility, we keep it here

        long long *int_array;
        double *double_array;
        bool *bool_array;

        char **str_array; // for string array, use char** to store array of strings
        // in microex, string array is not supported, but for future compatibility, we keep it here
    } value;

    bool is_static_checkable; 
    // whether this symbol can be checked at static time, e.g. variable, array, etc.
    // function symbol should be checkable

    UT_hash_handle hh;
} symbol; // symbol/name to symbol for yacc

typedef struct label {
    char *name;
    UT_hash_handle hh;
} label; // label for jump instructions, used in yacc code

typedef struct {
    label *true_label;
    label *false_label;
    label *end_label; // use for exsit else part and if condition is true
} if_info;

typedef struct node {
    struct node* next;
    symbol* symbol_ptr;

    array_type array_pointer;
    // use for access array when parsing `id_list` since if parsing `arr[0], arr[1]`
    // in id_list, all node->symbol_ptr->array_pointer will be same as last node
} node;

typedef struct {
    label *for_start_label;
    label *for_end_label;
    node for_node;
    direction for_direction;
    node for_end_node;
} for_info;

typedef struct {
    label *while_start_label;
    label *while_end_label;
    node while_condition; // condition node for while loop
} while_info;

typedef struct {
    node result_node; // result node for condition
    label *true_label_ptr; // label for true condition
    label *false_label_ptr; // label for false condition
    label *end_label_ptr; // label for end of condition
} condition_info;

typedef struct {
    node* head;
    node* tail;
    size_t len;
} list;

typedef struct {
    char *str;
    size_t capacity;
} reallocable_char;

typedef struct {
    data_type return_type;
    symbol *symbol_ptr;
} function_head;


extern symbol *symbol_table; 
// global symbol table set, store all global variable/symbol
extern symbol *temp_symbol_table; 
// temporary symbol table for intermediate variables, subset of `symbol_table`
extern function_info *current_function_info; 
// local symbol table set, store all local variable/symbol

extern label *label_table; 
// global label table set, initialized in yacc code

extern unsigned long long line_count, line_word_count;
extern bool is_multi_line_comment;
extern bool is_test_mode;

bool realloc_char(reallocable_char *rc, size_t new_size);

symbol *get_symbol(char *name_ptr);
symbol *add_function_symbol(const char *name_ptr);
label *add_label();
void add_comment(char *comment);
void free_symbol_table();
void free_label_table();
symbol *add_temp_symbol(data_type type);

void yyerror(const char *msg);
void yyerror_name(const char *msg, const char *error_name);
void yyerror_warning(const char *msg, const char *error_name, bool is_warning);
void yyerror_warning_test_mode(const char *msg, const char *error_name, bool is_warning, bool need_test_mode);
int yylex();

void generate(const char *format, ...);
void logging(const char *format, ...);

char *data_type_to_string(data_type type);
char *array_range_to_string(array_type array_info);
char *array_dimensions_to_string(array_type array_info);
char *data_array_type_to_string(data_type type);

symbol *get_array_offset(array_type array_info, array_type array_pointer);
symbol *extract_array_symbol(symbol *symbol_ptr);
size_t array_range(array_type array_info);
void copy_array_info(array_type *decs, array_type *src);
array_type empty_array_info();