#include "../lib/uthash.h"
#include <stdio.h>
#include <stdbool.h>

#define SIZE_T_CHARLEN 30 // for size_t to string conversion, 30 is enough for 64-bit size_t
#define MAX_ERROR_MSG_LEN 256
#define TEMP_SYMBOL_PREFIX "temp&" // `&` ensures that symbols do not conflict with user-defined symbols
#define LABEL_PREFIX "label&" // `&` ensures that labels do not conflict with user-defined labels

typedef struct symbol symbol;

typedef enum data_type {
    TYPE_UNKNOWN,
    
    TYPE_PROGRAM_NAME,

    TYPE_INT,
    TYPE_DOUBLE,
    TYPE_BOOL,

    TYPE_STRING, // autrally, this will not be used in microex, but for future compatibility
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
    // whether this symbol can be checked at static time, e.g. variable, function, etc.

    UT_hash_handle hh;
} symbol; // symbol/name to symbol for yacc

typedef struct label {
    char *name;
    UT_hash_handle hh;
} label; // label for jump instructions, used in yacc code

typedef struct {
    label *for_start_label;
    label *for_end_label;
    symbol *for_variable;
    direction for_direction;
    symbol *for_end_expression;
} for_info;

typedef struct {
    label *while_start_label;
    label *while_end_label;
    symbol *while_condition; // condition symbol for while loop
} while_info;

typedef struct {
    symbol *result_ptr; // result symbol for condition
    label *true_label_ptr; // label for true condition
    label *false_label_ptr; // label for false condition
    label *end_label_ptr; // label for end of condition
} condition_info;

typedef struct node {
    struct node* next;
    symbol* symbol_ptr;
} node;

typedef struct {
    node* head;
    node* tail;
} list;

typedef struct {
    char *str;
    size_t capacity;
} reallocable_char;

extern symbol *symbol_table; // global symbol table set, initialized in yacc code
extern symbol *temp_symbol_table; // temporary symbol table for intermediate variables
extern label *label_table; // global label table set, initialized in yacc code
extern unsigned long long line_count, line_word_count;
extern bool is_multi_line_comment;
extern bool is_test_mode;

bool realloc_char(reallocable_char *rc, size_t new_size);

symbol *get_symbol(const char *name);
void add_symbol(const char *name);
label *add_label();
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

symbol *get_array_offset_unstatic(array_type array_info, array_type array_pointer);
size_t get_array_offset(array_type array_info, array_type array_pointer);
size_t array_range(array_type array_info);