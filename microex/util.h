#include "../lib/uthash.h"
#include <stdio.h>
#include <stdbool.h>

#define MAX_ERROR_MSG_LEN 256

typedef enum data_type {
    TYPE_UNKNOWN,
    
    TYPE_PROGRAM_NAME,

    TYPE_INT,
    TYPE_DOUBLE,
    TYPE_STRING,
} data_type; // data type for symbol table

typedef struct {
    int dimensions; // number of dimensions, 0 for non-array
    int *dimension_sizes; // array each dimension sizes
} array_type;

typedef struct symbol_table {
    char *name;
    data_type type;
    union {
        int int_val;
        double double_val;
        char *str_val;
    } value;
    array_type array_info;

    UT_hash_handle hh;
} symbol; // symbol/name to symbol for yacc

typedef struct node {
    struct node* next;
    symbol* symbol_ptr;
} node;

extern symbol *symbol_table; // global symbol table set, initialized in yacc code
extern unsigned long long line_count, line_word_count;
extern bool is_multi_line_comment;

symbol *get_symbol(const char *name);
void add_symbol(const char *name);
void free_symbol_table();

void yyerror(const char *msg);
int yylex();

char *data_type_to_string(data_type type);