#include "../lib/uthash.h"
#include <stdio.h>
#include <stdbool.h>

#define MAX_ERROR_MSG_LEN 256

typedef enum data_type {
    TYPE_UNKNOWN,
    
    TYPE_PROGRAM_NAME,

    TYPE_INT,
    TYPE_DOUBLE,

    TYPE_STRING, // autrally, this will not be used in microex, but for future compatibility
} data_type; // data type for symbol table

typedef struct {
    size_t dimensions; // number of dimensions, 0 for non-array
    size_t *dimension_sizes; // array each dimension sizes
} array_type;

typedef struct symbol_table {
    char *name;
    data_type type;
    array_type array_info; // used for declare array and shape
    array_type array_pointer; // used for expression to locate array index
    
    union {
        long long int_val;
        double double_val;
        char *str_val;

        long long *int_array;
        double *double_array;
        char **str_array; // for string array, use char** to store array of strings
    } value;

    UT_hash_handle hh;
} symbol; // symbol/name to symbol for yacc

typedef struct node {
    struct node* next;
    symbol* symbol_ptr;
} node;

extern symbol *symbol_table; // global symbol table set, initialized in yacc code
extern symbol *temp_symbol_table; // temporary symbol table for intermediate variables
extern unsigned long long line_count, line_word_count;
extern bool is_multi_line_comment;
extern bool is_test_mode;

symbol *get_symbol(const char *name);
void add_symbol(const char *name);
void free_symbol_table();
symbol *add_temp_symbol(data_type type);

void yyerror(const char *msg);
void yyerror_name(const char *msg, const char *error_name);
void yyerror_warning(const char *msg, const char *error_name, bool is_warning);
void yyerror_warning_test_mode(const char *msg, const char *error_name, bool is_warning, bool need_test_mode);
int yylex();

char *data_type_to_string(data_type type);
char *array_range_to_string(array_type array_info);
char *array_dimensions_to_string(array_type array_info);
char *data_array_type_to_string(data_type type);

size_t get_array_offset(array_type array_info, array_type array_pointer);
size_t array_range(array_type array_info);