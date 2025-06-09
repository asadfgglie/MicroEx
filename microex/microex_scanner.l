%{
    #include <string.h>
    #include <unistd.h>
    #include <stdbool.h>
    #include <stdarg.h>
    #include <math.h>
    #include "../lib/uthash.h"
    #include "../lib/cargs.h"
    #include "../microex/util.h"
    #include "../build/y.tab.h"
    #define DEFAULT_OUTPUT "a.out"

    unsigned long long line_count = 1, line_word_count = 0;
    
    bool is_multi_line_comment = false;
    bool is_test_mode = false;
    
    char error_msg[MAX_ERROR_MSG_LEN];

    bool verbose = false;
    FILE *output;

    void line_label();
%}

empty_word [ \t]+
new_line \n

line_comment %%(((\n)?)|([^\n%][^\n]*((\n)?)))
multi_line_comment "%%%"

program [Pp][Rr][Oo][Gg][Rr][Aa][Mm]

begin [Bb][Ee][Gg][Ii][Nn]
end [Ee][Nn][Dd]
read [Rr][Ee][Aa][Dd]
write [Ww][Rr][Ii][Tt][Ee]
id ([a-zA-Z]|_)+([0-9]*|_|[a-zA-Z])
integer_literal ([1-9](_?[0-9]+)*)|[0-9]
float_literal (({integer_literal}\.)|(\.(([0-9]+)|([0-9](_?[0-9]+)*)))|({integer_literal}\.(([0-9]*)|([0-9](_?[0-9]+)*))))
exp_float_literal {float_literal}[Ee][+-]?{integer_literal}
string_literal \"(([^\n\"\\])|(\\\")|(\\\\)|(\\n)|(\\t)|(\\b)|(\\\'))*\"
true_literal [Tt][Rr][Uu][Ee]
false_literal [Ff][Aa][Ll][Ss][Ee]
left_parent "("
right_parent ")"
left_bracket "["
right_bracket "]"
semicolon ";"
comma ","
assign ":="
plus "+"
minus "-"
multiply "*"
division "/"
not_equal "!="
equal "=="
great ">"
less "<"
great_equal ">="
less_equal "<="
and "&&"
or "||"
not "!"
if [iI][fF]
then [Tt][Hh][Ee][Nn]
else [Ee][Ll][Ss][Ee]
endif [Ee][Nn][Dd][Ii][Ff]
for [Ff][Oo][Rr]
endfor [Ee][Nn][Dd][Ff][Oo][Rr]
while [Ww][Hh][Ii][Ll][Ee]
endwhile [Ee][Nn][Dd][Ww][Hh][Ii][Ll][Ee]
declare [Dd][Ee][Cc][Ll][Aa][Rr][Ee]
as [Aa][Ss]
integer [Ii][Nn][Tt][Ee][Gg][Ee][Rr]
real [Rr][Ee][Aa][Ll]
string [Ss][Tt][Rr][Ii][Nn][Gg]
bool [Bb][Oo][Oo][Ll]
to [Tt][Oo]
downto [Dd][Oo][Ww][Nn][Tt][Oo]

fn [Ff][Nn]
return [Rr][Ee][Tt][Uu][Rr][Nn]
endfn [Ee][Nn][Dd][Ff][Nn]

%%

{empty_word} {
    line_word_count += yyleng;
}
{new_line} {
    line_count += 1;
    line_word_count = 0;

    line_label();
}
{line_comment} {
    line_word_count += yyleng;
    if (yytext[yyleng - 1] == '\n') {
        line_count += 1;
        line_word_count = 0;
    }
    add_comment(yytext);
}
{multi_line_comment} {
    is_multi_line_comment = !is_multi_line_comment;
    line_word_count += yyleng;
}

{program} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "PROGRAM", yytext);
        return PROGRAM_MICROEX;
    }
}

{begin} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "BEGIN", yytext);
        return BEGIN_MICROEX;
    }
}
{end} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "END", yytext);
        return END_MICROEX;
    }
}
{read} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "READ", yytext);
        return READ_MICROEX;
    }
}
{write} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "WRITE", yytext);
        return WRITE_MICROEX;
    }
}
{integer_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.int_val = atoll(yytext);
        logging("$ lexer got token: `%s`, scan: `%s`\n", "INTEGER_LITERAL", yytext);
        return INTEGER_LITERAL_MICROEX;
    }
}
{float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.double_val = atof(yytext);
        logging("$ lexer got token: `%s`, scan: `%s`\n", "FLOAT_LITERAL", yytext);
        return FLOAT_LITERAL_MICROEX;
    }
}
{exp_float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.double_val = atof(yytext);
        logging("$ lexer got token: `%s`, scan: `%s`\n", "EXP_FLOAT_LITERAL", yytext);
        return EXP_FLOAT_LITERAL_MICROEX;
    }
}
{string_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.str_val = strdup(yytext);
        if (yylval.str_val == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        logging("$ lexer got token: `%s`, scan: `%s`\n", "STRING_LITERAL", yytext);
        return STRING_LITERAL_MICROEX;
    }
}
{true_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.bool_val = true;
        logging("$ lexer got token: `%s`, scan: `%s`\n", "TRUE_LITERAL", yytext);
        return TRUE_LITERAL_MICROEX;
    }
}
{false_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.bool_val = false;
        logging("$ lexer got token: `%s`, scan: `%s`\n", "FALSE_LITERAL", yytext);
        return FALSE_LITERAL_MICROEX;
    }
}
{left_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "LEFT_PARENT", yytext);
        return LEFT_PARENT_MICROEX;
    }
}
{right_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "RIGHT_PARENT", yytext);
        return RIGHT_PARENT_MICROEX;
    }
}
{left_bracket} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "LEFT_BRACKET", yytext);
        return LEFT_BRACKET_MICROEX;
    }
}
{right_bracket} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "RIGHT_BRACKET", yytext);
        return RIGHT_BRACKET_MICROEX;
    }
}
{semicolon} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "SEMICOLON", yytext);
        return SEMICOLON_MICROEX;
    }
}
{comma} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "COMMA", yytext);
        return COMMA_MICROEX;
    }
}
{assign} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "ASSIGN", yytext);
        return ASSIGN_MICROEX;
    }
}
{plus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "PLUS", yytext);
        return PLUS_MICROEX;
    }
}
{minus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "MINUS", yytext);
        return MINUS_MICROEX;
    }
}
{multiply} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "MULTIPLY", yytext);
        return MULTIPLY_MICROEX;
    }
}
{division} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "DIVISION", yytext);
        return DIVISION_MICROEX;
    }
}
{not_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "NOT_EQUAL", yytext);
        return NOT_EQUAL_MICROEX;
    }
}
{great} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "GREAT", yytext);
        return GREAT_MICROEX;
    }
}
{less} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "LESS", yytext);
        return LESS_MICROEX;
    }
}
{great_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "GREAT_EQUAL", yytext);
        return GREAT_EQUAL_MICROEX;
    }
}
{less_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "LESS_EQUAL", yytext);
        return LESS_EQUAL_MICROEX;
    }
}
{equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "EQUAL", yytext);
        return EQUAL_MICROEX;
    }
}
{and} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "AND", yytext);
        return AND_MICROEX;
    }
}
{or} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "OR", yytext);
        return OR_MICROEX;
    }
}
{not} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "NOT", yytext);
        return NOT_MICROEX;
    }
}
{if} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "IF", yytext);
        return IF_MICROEX;
    }
}
{then} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "THEN", yytext);
        return THEN_MICROEX;
    }
}
{else} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "ELSE", yytext);
        return ELSE_MICROEX;
    }
}
{endif} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "ENDIF", yytext);
        return ENDIF_MICROEX;
    }
}
{for} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "FOR", yytext);
        return FOR_MICROEX;
    }
}
{to} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "TO", yytext);
        return TO_MICROEX;
    }
}
{downto} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "DOWNTO", yytext);
        return DOWNTO_MICROEX;
    }
}
{endfor} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "ENDFOR", yytext);
        return ENDFOR_MICROEX;
    }
}
{while} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "WHILE", yytext);
        return WHILE_MICROEX;
    }
}
{endwhile} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "ENDWHILE", yytext);
        return ENDWHILE_MICROEX;
    }
}
{declare} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "DECLARE", yytext);
        return DECLARE_MICROEX;
    }
}
{as} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "AS", yytext);
        return AS_MICROEX;
    }
}
{integer} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "INTEGER", yytext);
        yylval.type = TYPE_INT;
        return INTEGER_MICROEX;
    }
}
{real} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "REAL", yytext);
        yylval.type = TYPE_DOUBLE;
        return REAL_MICROEX;
    }
}
{string} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "STRING", yytext);
        yylval.type = TYPE_STRING;
        return STRING_MICROEX;
    }
}
{bool} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "BOOL", yytext);
        yylval.type = TYPE_BOOL;
        return BOOL_MICROEX;
    }
}
{fn} {
    line_word_count += yyleng;
    if (!is_multi_line_comment)  {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "FN", yytext);
        return FN_MICROEX;
    }
}
{return} {
    line_word_count += yyleng;
    if (!is_multi_line_comment)  {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "RETURN", yytext);
        return RETURN_MICROEX;
    }
}
{endfn} {
    line_word_count += yyleng;
    if (!is_multi_line_comment)  {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "ENDFN", yytext);
        return ENDFN_MICROEX;
    }
}

{id} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        logging("$ lexer got token: `%s`, scan: `%s`\n", "ID", yytext);
        yylval.symbol_ptr = get_symbol(yytext);
        return ID_MICROEX;
    }
}

. {
    line_word_count += yyleng;
    if (!is_multi_line_comment)  {
        sprintf(error_msg, "Unexcept character: `%s`", yytext);
        yyerror_name(error_msg, "Lexical");
        return -1; /* lexical error: Unexcept character */
    }
}

%%

array_type empty_array_info() {
    array_type info = {
        .dimensions = 0,
        .dimension_sizes = NULL,
        .dimension_sizes_symbol = NULL,
        .is_static_checkable = true
    };
    return info;
}

/**
 * Reallocable char structure to handle dynamic string allocation.
 * Returns true if realloc was successful, false otherwise.
 */
bool realloc_char(reallocable_char *rc, size_t new_size) {
    char *tmp = (char *)realloc(rc->str, new_size);
    if (tmp == NULL) {
        return false;
    }
    rc->str = tmp;
    rc->capacity = new_size;
    return true;
}

void copy_array_info(array_type *decs, array_type *src) {
    decs->dimensions = src->dimensions;
    decs->is_static_checkable = src->is_static_checkable;
    if (src->dimensions > 0) {
        if (src->dimension_sizes != NULL) {
            decs->dimension_sizes = (size_t *)malloc(sizeof(size_t) * decs->dimensions);
            if (decs->dimension_sizes == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            memcpy(decs->dimension_sizes, src->dimension_sizes, sizeof(size_t) * decs->dimensions);
        }
        if (src->dimension_sizes_symbol != NULL) {
            decs->dimension_sizes_symbol = (symbol **)malloc(sizeof(symbol *) * decs->dimensions);
            if (decs->dimension_sizes_symbol == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            memcpy(decs->dimension_sizes_symbol, src->dimension_sizes_symbol, sizeof(size_t) * decs->dimensions);
        }
    }
}

size_t array_range(array_type array_info) {
    size_t index_range = 1;
    if (!array_info.is_static_checkable) {
        yyerror_name("Array range cannot be calculated for non-static array.", "Parsing");
    }
    for (size_t i = 0; i < array_info.dimensions; i++) {
        index_range *= array_info.dimension_sizes[i];
    }
    return index_range;
}

/**
 * Convert array dimensions to a string representation.
 * Returns a dynamically allocated string that should be freed by the caller.
 */
char *array_dimensions_to_string(array_type array_info) {
    reallocable_char rc = { 
        .str = NULL, 
        .capacity = array_info.dimensions * SIZE_T_CHARLEN
    };
    rc.str = (char *)malloc(sizeof(char) * rc.capacity);
    if (rc.str == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    rc.str[0] = '\0';
    for (size_t i = 0; i < array_info.dimensions; i++) {
        size_t len = (array_info.is_static_checkable)? SIZE_T_CHARLEN : strlen(array_info.dimension_sizes_symbol[i]->name);
        if (strlen(rc.str) + len + 4 > rc.capacity) {
            rc.capacity = (strlen(rc.str) + len + 4); // +4 for the brackets and null terminator
            rc.capacity *= 2; // double the capacity for efficient growth
            if (!realloc_char(&rc, rc.capacity)) {
                yyerror_name("Out of memory when realloc.", "Parsing");
            }
        }
        if (array_info.is_static_checkable) {
            sprintf(rc.str, "%s[%zu]", rc.str, array_info.dimension_sizes[i]);
        }
        else {
            sprintf(rc.str, "%s[%s]", rc.str, array_info.dimension_sizes_symbol[i]->name);
        }
    }
    return rc.str;
}

char *array_range_to_string(array_type array_info) {
    size_t index_range = array_range(array_info);
    char *result = (char *)malloc(sizeof(char) * SIZE_T_CHARLEN);
    if (result == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    result[0] = '\0';
    sprintf(result, "%zu", index_range);
    return result;
}

char *data_array_type_to_string(data_type type) {
    char *result = NULL;
    switch (type) {
        case TYPE_BOOL: // bool actually is integer in microex
        case TYPE_INT: {
            result = strdup("integer_array");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        case TYPE_DOUBLE: {
            result = strdup("real_array");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        case TYPE_STRING: {
            result = strdup("string_array");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        case TYPE_PROGRAM_NAME: {
            yyerror_name("Program name does not have a data array type.", "Parsing");
            return NULL; // This will never be reached, but added to avoid compiler warnings.
        }
        case TYPE_FUNCTION: {
            yyerror_name("Function does not have a data array type.", "Parsing");
            return NULL; // This will never be reached, but added to avoid compiler warnings.
        }
        default: {
            yyerror_name("Unknown data type", "Parsing");
            return NULL; // This will never be reached, but added to avoid compiler warnings.
        }
    }
}

char *data_type_to_string(data_type type) {
    char *result = NULL;
    switch (type) {
        case TYPE_BOOL: // bool actually is integer in microex
        case TYPE_INT: {
            result = strdup("integer");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        case TYPE_DOUBLE: {
            result = strdup("real");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        case TYPE_STRING: {
            result = strdup("string");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        case TYPE_PROGRAM_NAME: {
            result = strdup("program");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        case TYPE_FUNCTION: {
            result = strdup("function");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        }
        default: {
            yyerror_name("Unknown data type", "Parsing");
            return NULL; // This will never be reached, but added to avoid compiler warnings.
        }
    }
}

symbol *add_symbol(const char *name_ptr) {
    symbol *s = (symbol *)malloc(sizeof(symbol));
    if (s == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }

    SYMBOL_INIT(s, strdup(name_ptr));
    if (s->name == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }

    HASH_ADD_STR(symbol_table, name, s);

    return s;
}

/**
 * Add a function symbol to `current_function_info->local_symbol_table`.
 * Returns a pointer to the symbol in `current_function_info->local_symbol_table`.
 */
symbol *add_function_symbol(const char *name_ptr) {
    if (current_function_info == NULL) {
        yyerror_name("Function symbol should be added when parsing function statement.", "Parsing");
    }

    symbol *s = (symbol *)malloc(sizeof(symbol));
    if (s == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }

    char *name = (char *)malloc(sizeof(char) * (strlen(FN_LOCAL_SYMBOL_PREFIX) + strlen(current_function_info->name) + strlen(name_ptr) + 2));
    if (name == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    name[0] = '\0';
    sprintf(name, "%s%s&%s", FN_LOCAL_SYMBOL_PREFIX, current_function_info->name, name_ptr);

    SYMBOL_INIT(s, name);

    HASH_ADD_STR(current_function_info->local_symbol_table, name, s);

    return s;
}

symbol *get_symbol(char *name_ptr) {
    symbol *s;
    char *name;

    if (current_function_info != NULL) {
        // parsing funciton statement
        // try to find local variable
        name = (char *)malloc(sizeof(char) * (strlen(FN_LOCAL_SYMBOL_PREFIX) + strlen(current_function_info->name) + strlen(name_ptr) + 2));
        if (name == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        name[0] = '\0';

        sprintf(name, "%s%s&%s", FN_LOCAL_SYMBOL_PREFIX, current_function_info->name, name_ptr);

        HASH_FIND_STR(current_function_info->local_symbol_table, name, s);

        if (s != NULL) {
            return s; // return local variable symbol
        }
    }
    
    name = name_ptr;

    HASH_FIND_STR(symbol_table, name, s); // s = NULL if not found
    
    if (s != NULL) {
        // return global variable
        return s;
    }

    if (current_function_info != NULL) {
        // add new local variable
        return add_function_symbol(name_ptr);
    }
    else {
        // add new global variable
        return add_symbol(name_ptr);
    }
}

/**
 * Add a temporary symbol to `temp_symbol_table` & `symbol_table`.
 * Returns a pointer to the symbol in `symbol_table`.
 */
symbol *add_temp_symbol(data_type type) {
    size_t index = HASH_COUNT(temp_symbol_table);
    char *type_str = data_type_to_string(type);
    
    char *name = NULL;

    if (current_function_info == NULL) {
        name = (char *)malloc(sizeof(char) * (strlen(TEMP_SYMBOL_PREFIX) + strlen(type_str) + SIZE_T_CHARLEN));
        if (name == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        name[0] = '\0';
        sprintf(name, "%s%s&%zu", TEMP_SYMBOL_PREFIX, type_str, index);
    }
    else {
        name = (char *)malloc(sizeof(char) * (strlen(FN_LOCAL_SYMBOL_PREFIX TEMP_SYMBOL_PREFIX) + strlen(type_str) + SIZE_T_CHARLEN));
        if (name == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        name[0] = '\0';
        sprintf(name, "%s%s&%zu", FN_LOCAL_SYMBOL_PREFIX TEMP_SYMBOL_PREFIX, type_str, index);
    }
    
    free(type_str);

    symbol *s = (symbol *)malloc(sizeof(symbol));
    if (s == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    
    SYMBOL_INIT(s, name);
    s->type = type;

    HASH_ADD_STR(temp_symbol_table, name, s);

    s = (symbol *)malloc(sizeof(symbol));
    if (s == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    
    name = strdup(name);
    if (name == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    SYMBOL_INIT(s, name);
    s->type = type;

    HASH_ADD_STR(symbol_table, name, s);
    
    return s;
}

label *add_label() {
    size_t index = HASH_COUNT(label_table);
    char *name = (char *)malloc(sizeof(char) * (strlen(LABEL_PREFIX) + SIZE_T_CHARLEN));
    if (name == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    name[0] = '\0';
    sprintf(name, "%s%zu", LABEL_PREFIX, index);

    label *l = (label *)malloc(sizeof(label));
    if (l == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    l->name = name;

    HASH_ADD_STR(label_table, name, l);

    return l;
}

/**
 * Extract symbol from `symbol_ptr-><type>_array[get_array_offset(symbol_ptr->array_info, symbol_ptr->array_pointer)->value.int_val] and return new symbol for result.
 * Otherwise will return original `symbol_ptr`
 */
symbol *extract_array_symbol(symbol *symbol_ptr) {
    symbol *result = symbol_ptr;

    if (symbol_ptr->array_pointer.dimensions > 0) { // array access
        char *dimensions;
        if (symbol_ptr->array_info.dimensions == 0) {
            yyerror_name("Array access with non-array variable.", "Type");
        }
        if (symbol_ptr->array_info.dimensions != symbol_ptr->array_pointer.dimensions) {
            yyerror_name("Array access with wrong number of dimensions.", "Index");
        }
        symbol *offset = get_array_offset(symbol_ptr->array_info, symbol_ptr->array_pointer);
        switch (symbol_ptr->type) {
            case TYPE_INT: {
                result = add_temp_symbol(TYPE_INT);
                if (symbol_ptr->array_pointer.is_static_checkable) {
                    result->value.int_val = symbol_ptr->value.int_array[offset->value.int_val];
                }
                // we won't do any semantic propogation here, since we are not sure about the real array offset
                generate("I_STORE %s[%s] %s\n", symbol_ptr->name, offset->name, result->name);
                dimensions = array_dimensions_to_string(symbol_ptr->array_pointer);
                logging("> extract array access: expression -> %s%s\n", symbol_ptr->name, dimensions);
                free(dimensions);
                break;
            }
            case TYPE_DOUBLE: {
                result = add_temp_symbol(TYPE_DOUBLE);
                if (symbol_ptr->array_pointer.is_static_checkable) {
                    result->value.double_val = symbol_ptr->value.double_array[offset->value.int_val];
                }
                // we won't do any semantic propogation here, since we are not sure about the real array offset
                generate("F_STORE %s[%s] %s\n", symbol_ptr->name, offset->name, result->name);
                dimensions = array_dimensions_to_string(symbol_ptr->array_pointer);
                logging("> extract array access: expression -> %s%s\n", symbol_ptr->name, dimensions);
                free(dimensions);
                break;
            }
            case TYPE_STRING: {
                result = add_temp_symbol(TYPE_STRING);
                if (symbol_ptr->array_pointer.is_static_checkable) {
                    result->value.str_val = (char *)malloc(sizeof(char) * (strlen(symbol_ptr->value.str_array[offset->value.int_val]) + 1));
                    if (result->value.str_val == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    result->value.str_val[0] = '\0';
                    sprintf(result->value.str_val, "%s", symbol_ptr->value.str_array[offset->value.int_val]);
                }
                // we won't do any semantic propogation here, since we are not sure about the real array offset
                yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                dimensions = array_dimensions_to_string(symbol_ptr->array_pointer);
                logging("> extract array access: expression -> %s%s\n", symbol_ptr->name, dimensions);
                free(dimensions);
                break;
            }
            case TYPE_BOOL: {
                result = add_temp_symbol(TYPE_BOOL);
                if (symbol_ptr->array_pointer.is_static_checkable) {
                    result->value.bool_val = symbol_ptr->value.bool_array[offset->value.int_val];
                }
                // we won't do any semantic propogation here, since we are not sure about the real array offset
                generate("I_STORE %s[%s] %s\n", symbol_ptr->name, offset->name, result->name);
                dimensions = array_dimensions_to_string(symbol_ptr->array_pointer);
                logging("> extract array access: expression -> %s%s\n", symbol_ptr->name, dimensions);
                free(dimensions);
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot access program name as an array.", "Type");
                break;
            }
            default: {
                yyerror_name("Unknown data type in array access.", "Parsing");
                break;
            }
        }

        result->is_static_checkable = symbol_ptr->is_static_checkable && symbol_ptr->array_pointer.is_static_checkable;
    }

    return result;
}

/**
 * Calculate the offset of an array, add temporary symbol for unstatic access.
 * Returns a pointer to the temporary symbol.
 */
symbol *get_array_offset(array_type array_info, array_type array_pointer) {
    if (array_info.dimensions == 0) {
        yyerror_name("Array access on non-array variable.", "Type");
    }
    if (array_pointer.dimensions != array_info.dimensions) {
        yyerror_name("Array access with wrong number of dimensions.", "Index");
    }

    logging("> Calculating offset for array access.\n");
    add_comment("Calculating offset");

    symbol *offset = add_temp_symbol(TYPE_INT);
    offset->is_static_checkable = array_pointer.is_static_checkable;
    offset->value.int_val = 0;
    generate("I_STORE %d %s\n", 0, offset->name);

    symbol *stride = add_temp_symbol(TYPE_INT);
    stride->is_static_checkable = array_pointer.is_static_checkable;
    stride->value.int_val = 1;
    generate("I_STORE %d %s\n", 1, stride->name);

    symbol *temp_offset_symbol = add_temp_symbol(TYPE_INT);
    temp_offset_symbol->is_static_checkable = array_pointer.is_static_checkable;

    symbol *temp_stride_symbol = add_temp_symbol(TYPE_INT);
    temp_stride_symbol->is_static_checkable = array_pointer.is_static_checkable;

    for (size_t i = array_pointer.dimensions - 1; i <= array_pointer.dimensions - 1; i--) {
        // use `i <= array_pointer.dimensions - 1` since `i` is unsigned
        // We don't check the bounds here, since it is unstatic access.

        // offset += array_pointer.dimension_sizes[i] * stride;
        // stride *= array_info.dimension_sizes[i];
        if (array_pointer.is_static_checkable) {
            if (array_pointer.dimension_sizes[i] >= array_info.dimension_sizes[i]) {
                yyerror_name("Array index out of bounds.", "Index");
            }

            offset->value.int_val += array_pointer.dimension_sizes[i] * stride->value.int_val;
            stride->value.int_val *= array_info.dimension_sizes[i];
        }

        generate("I_MUL %s %s %s\n", stride->name, array_pointer.dimension_sizes_symbol[i]->name, temp_stride_symbol->name);
        generate("I_ADD %s %s %s\n", offset->name, temp_stride_symbol->name, temp_offset_symbol->name);
        generate("I_STORE %s %s\n", temp_offset_symbol->name, offset->name);
        
        generate("I_MUL %s %zu %s\n", stride->name, array_info.dimension_sizes[i], temp_stride_symbol->name);
        generate("I_STORE %s %s\n", temp_stride_symbol->name, stride->name);
    }

    return offset;
}

/**
 * Error handling functions for Bison yacc.
 * These functions are used to report errors and warnings during parsing.
 * `yyerror_warning` function won't exit the program.
 * `yyerror_warning_test_mode` function will exit the program 
 * if `need_test_mode` is true and `is_test_mode` is false.
 */
void yyerror(const char *msg) {
    yyerror_name(msg, "Syntax");
}

void yyerror_name(const char *msg, const char *error_name) {
    yyerror_warning(msg, error_name, false);
}

void yyerror_warning(const char *msg, const char *error_name, bool is_warning) {
    yyerror_warning_test_mode(msg, error_name, is_warning, false);
}

void yyerror_warning_test_mode(const char *msg, const char *error_name, bool is_warning, bool need_test_mode) {
    if (need_test_mode && !is_test_mode) {
        printf("%s Error: %s\n\tat line (%llu:%llu)\n", error_name, msg, line_count, line_word_count);
        fprintf(stderr, "This function only works in test mode.\n");
        fprintf(stderr, "Since it may not be fully implemented yet, output target code may be incorrect.\n");
        fprintf(stderr, "If you want to enable test mode, please use the -t option.\n");
        exit(EXIT_FAILURE);
    }

    if (is_warning) {
        fprintf(stderr, "%s Warning: %s\n\tat line (%llu:%llu)\n", error_name, msg, line_count, line_word_count);
        return;
    }
    
    printf("%s Error: %s\n\tat line (%llu:%llu)\n", error_name, msg, line_count, line_word_count);
    exit(EXIT_FAILURE);
}

void generate(const char *format, ...) {
    va_list args1, args2;
    
    va_start(args1, format);
    va_copy(args2, args1); // copy another va_list for stdout
    // va_list is a one-time pointer, state will be consumed after using
    // but you still need `va_end()` to free them

    vfprintf(output, format, args1);

    if (verbose) {
        vfprintf(stdout, format, args2);
    }

    // free va_list
    va_end(args1);
    va_end(args2);
}

void logging(const char *format, ...) {
    va_list args;

    va_start(args, format);
    
    if (verbose) {
        char *tmp = (char *)malloc(sizeof(char) * (strlen(format) + 2));
        tmp[0] = '\t';
        tmp[1] = '\0';
        strcat(tmp, format);
        vfprintf(stdout, tmp, args);
    }
    else {
        vfprintf(stdout, format, args);
    }

    va_end(args);
}

void line_label() {
    generate("%s%llu:\n", LINE_PREFIX, line_count);
}

void add_comment(char *comment) {
    static size_t index = 0;
    char *tmp = (char *)malloc(sizeof(char) * (strlen(comment) + 1));
    if (tmp == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    strcpy(tmp, comment);
    
    size_t offset = 0;
    for (size_t i = 0; tmp[i - offset] != '\0'; i++) {
        tmp[i - offset] = tmp[i];
        if (tmp[i - offset] == ' ' || tmp[i - offset] == '\t' || 
            tmp[i - offset] == '-') {
            tmp[i - offset] = '_';
        }
        if (tmp[i - offset] == '%' || tmp[i - offset] == '\n' || 
            tmp[i - offset] == '.' || tmp[i - offset] == '!' ||
            tmp[i - offset] == '?') {
            tmp[i - offset] = tmp[i - offset + 1];
            offset++;
        }
    }

    offset = 0;
    bool cut = true;
    for (size_t i = 0; tmp[i - offset] != '\0'; i++) {
        tmp[i - offset] = tmp[i];
        if (tmp[i - offset] == '_' && cut) {
            tmp[i - offset] = tmp[i - offset + 1];
            offset++;
        }
        else {
            cut = false;
        }
    }

    generate("%s%s&%zu:\n", COMMENT_PREFIX, tmp, index);
    index++;
    
    free(tmp);
}

// for Bison yacc to call parser
int main(int argc, char **argv) {
    struct cag_option options[] = {
        {
            .identifier = 'h',
            .access_letters = "hH",
            .access_name = "help",
            .value_name = NULL,
            .description = "Show this help message."
        },
        {
            .identifier = 'f',
            .access_letters = "fF",
            .access_name = "file",
            .value_name = "filename",
            .description = "Input file to parse."
        },
        {
            .identifier = 't',
            .access_letters = "tT",
            .access_name = "test",
            .value_name = NULL,
            .description = "Run in test mode, parsing won't stop when future features are not fully implemented."
        },
        {
            .identifier = 'o',
            .access_letters = "o",
            .access_name = "output",
            .value_name = "outputname",
            .description = "Output file name, default is `a.out`." 
        },
        {
            .identifier = 'v',
            .access_letters = "v",
            .access_name = "verbose",
            .value_name = NULL,
            .description = "Show generate code with parsing log." 
        }
    };

    cag_option_context context;
    cag_option_init(&context, options, CAG_ARRAY_SIZE(options), argc, argv);

    while (cag_option_fetch(&context)) {
        switch (cag_option_get_identifier(&context)) {
            case 'h': {
                printf("Usage: microex [OPTION]...\n");
                printf("Compile microex source files.\n\n");
                cag_option_print(options, CAG_ARRAY_SIZE(options), stdout);
                return EXIT_SUCCESS;
            }
            case '?': {
                cag_option_print_error(&context, stdout);
                return EXIT_FAILURE;
            }
            case 'f': {
                yyin = fopen(cag_option_get_value(&context), "r");
                if (yyin == NULL) {
                    fprintf(stderr, "Error: Cannot open file `%s`.\n", cag_option_get_value(&context));
                    return EXIT_FAILURE;
                }
                break;
            }
            case 't': {
                is_test_mode = true;
                printf("Running in test mode, parsing won't stop when future features are not implemented.\n\n");
                break;
            }
            case 'o': {
                output = fopen(cag_option_get_value(&context), "w");
                if (output == NULL) {
                    fprintf(stderr, "Error: Cannot open file `%s`.\n", cag_option_get_value(&context));
                    return EXIT_FAILURE;
                }
                break;
            }
            case 'v': {
                verbose = true;
                break;
            }
        }
    }
    if (output == NULL) {
        output = fopen(DEFAULT_OUTPUT, "w");
        if (output == NULL) {
            fprintf(stderr, "Error: Cannot open file `%s`.\n", DEFAULT_OUTPUT);
            return EXIT_FAILURE;
        }
    }

    line_label();
    int result = yyparse();
    
    if (is_multi_line_comment) {
        yyerror_name("Unbalance multi-line comment\n", "Lexcial");
    }

    fclose(yyin);

    return result;
}