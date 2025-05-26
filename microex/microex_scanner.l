%{
    #include <string.h>
    #include <unistd.h>
    #include <stdbool.h>
    #include <math.h>
    #include "../lib/uthash.h"
    #include "../lib/cargs.h"
    #include "../microex/util.h"
    #include "../build/y.tab.h"

    unsigned long long line_count = 1, line_word_count = 0;
    bool is_multi_line_comment = false;
    bool is_test_mode = false;
    char error_msg[MAX_ERROR_MSG_LEN];
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
to [Tt][Oo]
downto [Dd][Oo][Ww][Nn][Tt][Oo]

%%

{empty_word} {
    line_word_count += yyleng;
}
{new_line} {
    line_count += 1;
    line_word_count = 0;
}
{line_comment} {
    if (yytext[yyleng - 1] == '\n') {
        line_count += 1;
        line_word_count = 0;
    }
}
{multi_line_comment} {
    is_multi_line_comment = !is_multi_line_comment;
}

{program} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "PROGRAM", yytext);
        return PROGRAM_MICOREX;
    }
}

{begin} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "BEGIN", yytext);
        return BEGIN_MICOREX;
    }
}
{end} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "END", yytext);
        return END_MICOREX;
    }
}
{read} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "READ", yytext);
        return READ_MICOREX;
    }
}
{write} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "WRITE", yytext);
        return WRITE_MICOREX;
    }
}
{integer_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.int_val = atoll(yytext);
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "INTEGER_LITERAL", yytext);
        return INTEGER_LITERAL_MICOREX;
    }
}
{float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.double_val = atof(yytext);
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "FLOAT_LITERAL", yytext);
        return FLOAT_LITERAL_MICOREX;
    }
}
{exp_float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.double_val = atof(yytext);
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "EXP_FLOAT_LITERAL", yytext);
        return EXP_FLOAT_LITERAL_MICOREX;
    }
}
{string_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        yylval.str_val = strdup(yytext);
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "STRING_LITERAL", yytext);
        return STRING_LITERAL_MICOREX;
    }
}
{left_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "LEFT_PARENT", yytext);
        return LEFT_PARENT_MICOREX;
    }
}
{right_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "RIGHT_PARENT", yytext);
        return RIGHT_PARENT_MICOREX;
    }
}
{left_bracket} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "LEFT_BRACKET", yytext);
        return LEFT_BRACKET_MICOREX;
    }
}
{right_bracket} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "RIGHT_BRACKET", yytext);
        return RIGHT_BRACKET_MICOREX;
    }
}
{semicolon} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "SEMICOLON", yytext);
        return SEMICOLON_MICOREX;
    }
}
{comma} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "COMMA", yytext);
        return COMMA_MICOREX;
    }
}
{assign} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "ASSIGN", yytext);
        return ASSIGN_MICOREX;
    }
}
{plus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "PLUS", yytext);
        return PLUS_MICOREX;
    }
}
{minus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "MINUS", yytext);
        return MINUS_MICOREX;
    }
}
{multiply} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "MULTIPLY", yytext);
        return MULTIPLY_MICOREX;
    }
}
{division} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "DIVISION", yytext);
        return DIVISION_MICOREX;
    }
}
{not_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "NOT_EQUAL", yytext);
        return NOT_EQUAL_MICOREX;
    }
}
{great} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "GREAT", yytext);
        return GREAT_MICOREX;
    }
}
{less} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "LESS", yytext);
        return LESS_MICOREX;
    }
}
{great_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "GREAT_EQUAL", yytext);
        return GREAT_EQUAL_MICOREX;
    }
}
{less_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "LESS_EQUAL", yytext);
        return LESS_EQUAL_MICOREX;
    }
}
{equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "EQUAL", yytext);
        return EQUAL_MICOREX;
    }
}
{if} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "IF", yytext);
        return IF_MICOREX;
    }
}
{then} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "THEN", yytext);
        return THEN_MICOREX;
    }
}
{else} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "ELSE", yytext);
        return ELSE_MICOREX;
    }
}
{endif} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "ENDIF", yytext);
        return ENDIF_MICOREX;
    }
}
{for} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "FOR", yytext);
        return FOR_MICOREX;
    }
}
{to} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "TO", yytext);
        return TO_MICOREX;
    }
}
{downto} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "DOWNTO", yytext);
        return DOWNTO_MICOREX;
    }
}
{endfor} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "ENDFOR", yytext);
        return ENDFOR_MICOREX;
    }
}
{while} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "WHILE", yytext);
        return WHILE_MICOREX;
    }
}
{endwhile} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "ENDWHILE", yytext);
        return ENDWHILE_MICOREX;
    }
}
{declare} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "DECLARE", yytext);
        return DECLARE_MICOREX;
    }
}
{as} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "AS", yytext);
        return AS_MICOREX;
    }
}
{integer} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "INTEGER", yytext);
        yylval.type = TYPE_INT;
        return INTEGER_MICOREX;
    }
}
{real} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "REAL", yytext);
        yylval.type = TYPE_DOUBLE;
        return REAL_MICOREX;
    }
}
{string} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "STRING", yytext);
        yylval.type = TYPE_STRING;
        return STRING_MICOREX;
    }
}

{id} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        printf("\t$ lexer got token: `%s`, scan: `%s`\n", "ID", yytext);
        yylval.symbol_ptr = get_symbol(yytext);
        return ID_MICOREX;
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

size_t array_range(array_type array_info) {
    size_t index_range = 1;
    for (size_t i = 0; i < array_info.dimensions; i++) {
        index_range *= array_info.dimension_sizes[i];
    }
    return index_range;
}

char *array_dimensions_to_string(array_type array_info) {
    char *dimensions = (char *)malloc(sizeof(char) * array_info.dimensions * 3);
    if (dimensions == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    dimensions[0] = '\0';
    for (size_t i = 0; i < array_info.dimensions; i++) {
        sprintf(dimensions, "%s[%zu]", dimensions, array_info.dimension_sizes[i]);
    }
    return dimensions;
}

char *array_range_to_string(array_type array_info) {
    size_t index_range = array_range(array_info);
    size_t digital_len = 1;
    size_t tmp = index_range;
    while (tmp > 0) {
        tmp /= 10;
        digital_len++;
    }
    char *result = (char *)malloc(sizeof(char) * digital_len + 1);
    if (result == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    sprintf(result, "%zu", index_range);
    return result;
}

char *data_array_type_to_string(data_type type) {
    char *result = NULL;
    switch (type) {
        case TYPE_INT:
            result = strdup("integer_array");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        case TYPE_DOUBLE:
            result = strdup("real_array");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        case TYPE_STRING:
            result = strdup("string_array");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        default:
            yyerror_name("Unknown data type", "Parsing");
    }
}

char *data_type_to_string(data_type type) {
    char *result = NULL;
    switch (type) {
        case TYPE_INT:
            result = strdup("integer");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        case TYPE_DOUBLE:
            result = strdup("real");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        case TYPE_STRING:
            result = strdup("string");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        case TYPE_PROGRAM_NAME:
            result = strdup("program");
            if (result == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            return result;
        default:
            yyerror_name("Unknown data type", "Parsing");
    }
}

symbol *get_symbol(const char *name) {
    symbol *s;
    HASH_FIND_STR(symbol_table, name, s); // s = NULL if not found
    if (s != NULL) {
        return s;
    }

    add_symbol(name);
    HASH_FIND_STR(symbol_table, name, s);
    return s;
}

void add_symbol(const char *name) {
    symbol *s = (symbol *)malloc(sizeof(symbol));
    if (s == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }

    s->name = strdup(name);
    s->type = TYPE_UNKNOWN;
    s->array_info.dimensions = 0;
    s->array_info.dimension_sizes = NULL;
    s->array_pointer.dimensions = 0;
    s->array_pointer.dimension_sizes = NULL;

    HASH_ADD_STR(symbol_table, name, s);
}

symbol *add_temp_symbol(data_type type) {
    // TODO: fix temp symbol does not correctly add to temp symbol table
    symbol *s = (symbol *)malloc(sizeof(symbol));
    if (s == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }

    size_t temp_index = HASH_COUNT(temp_symbol_table);
    size_t tmp_index_len = 0;
    while (temp_index > 0) {
        temp_index /= 10;
        tmp_index_len++;
    }
    char *name = (char *)malloc(sizeof(char) * (tmp_index_len + 1));
    if (name == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    char *type_str = data_type_to_string(type);
    sprintf(name, "temp$%s$%zu", type_str, temp_index);
    free(type_str);

    s->name = name;
    s->type = type;
    s->array_info.dimensions = 0;
    s->array_info.dimension_sizes = NULL;
    s->array_pointer.dimensions = 0;
    s->array_pointer.dimension_sizes = NULL;

    HASH_ADD_STR(temp_symbol_table, name, s);

    symbol *tmp_s = (symbol *)malloc(sizeof(symbol));
    if (tmp_s == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    tmp_s->name = strdup(name);
    if (tmp_s->name == NULL) {
        yyerror_name("Out of memory when malloc.", "Parsing");
    }
    tmp_s->type = type;
    tmp_s->array_info.dimensions = 0;
    tmp_s->array_info.dimension_sizes = NULL;
    tmp_s->array_pointer.dimensions = 0;
    tmp_s->array_pointer.dimension_sizes = NULL;

    HASH_ADD_STR(symbol_table, name, tmp_s);

    return s;
}

void free_symbol_table() {
    symbol *current_symbol, *symbol_tmp;
    HASH_ITER(hh, symbol_table, current_symbol, symbol_tmp) {
        HASH_DEL(symbol_table, current_symbol);
        free(current_symbol->name);
        if (current_symbol->array_info.dimensions > 0) {
            free(current_symbol->array_info.dimension_sizes);
            switch (current_symbol->type) {
                case TYPE_INT:
                    free(current_symbol->value.int_array);
                    break;
                case TYPE_DOUBLE:
                    free(current_symbol->value.double_array);
                    break;
                case TYPE_STRING:
                    for (size_t i = 0; i < current_symbol->array_info.dimension_sizes[0]; i++) {
                        free(current_symbol->value.str_array[i]);
                    }
                    free(current_symbol->value.str_array);
                    break;
                default:
                    break;
            }
        }
        if (current_symbol->type == TYPE_STRING) {
            free(current_symbol->value.str_val);
        }
        free(current_symbol);
    }

    HASH_ITER(hh, temp_symbol_table, current_symbol, symbol_tmp) {
        HASH_DEL(temp_symbol_table, current_symbol);
        free(current_symbol->name);
        switch (current_symbol->type) {
            case TYPE_INT:
                free(current_symbol->value.int_array);
                break;
            case TYPE_DOUBLE:
                free(current_symbol->value.double_array);
                break;
            case TYPE_STRING:
                for (size_t i = 0; i < current_symbol->array_info.dimension_sizes[0]; i++) {
                    free(current_symbol->value.str_array[i]);
                }
                free(current_symbol->value.str_array);
                break;
            default:
                break;
        }
        if (current_symbol->type == TYPE_STRING) {
            free(current_symbol->value.str_val);
        }
        free(current_symbol);
    }
}

size_t get_array_offset(array_type array_info, array_type array_pointer) {
    if (array_info.dimensions == 0) {
        yyerror_name("Array access on non-array variable.", "Type");
    }
    if (array_pointer.dimensions != array_info.dimensions) {
        yyerror_name("Array access with wrong number of dimensions.", "Index");
    }

    size_t offset = 0;
    size_t stride = 1;
    size_t i;
    for (i = array_pointer.dimensions - 1; i <= array_pointer.dimensions - 1; i--) {
        // use `i <= array_pointer.dimensions - 1` since `i` is unsigned
        if (array_pointer.dimension_sizes[i] >= array_info.dimension_sizes[i]) {
            yyerror_name("Array index out of bounds.", "Index");
        }

        offset += array_pointer.dimension_sizes[i] * stride;
        stride *= array_info.dimension_sizes[i];
    }

    return offset;
}

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
        fprintf(stderr, "%s Error: %s\n\tat line (%llu:%llu)\n", error_name, msg, line_count, line_word_count);
        printf("This function only works in test mode.\n");
        printf("Since it may not be fully implemented yet, output target code may be incorrect.\n");
        printf("If you want to enable test mode, please use the -t option.\n");
        exit(EXIT_FAILURE);
    }

    if (is_warning) {
        fprintf(stderr, "%s Warning: %s\n\tat line (%llu:%llu)\n", error_name, msg, line_count, line_word_count);
        return;
    }
    fprintf(stderr, "%s Error: %s\n\tat line (%llu:%llu)\n", error_name, msg, line_count, line_word_count);
    exit(EXIT_FAILURE);
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
        }
    };

    cag_option_context context;
    cag_option_init(&context, options, CAG_ARRAY_SIZE(options), argc, argv);

    while (cag_option_fetch(&context)) {
        switch (cag_option_get_identifier(&context)) {
            case 'h':
                printf("Usage: microex [OPTION]...\n");
                printf("Compile microex source files.\n\n");
                cag_option_print(options, CAG_ARRAY_SIZE(options), stdout);
                return EXIT_SUCCESS;
            case '?':
                cag_option_print_error(&context, stdout);
                return EXIT_FAILURE;
            case 'f':
                yyin = fopen(cag_option_get_value(&context), "r");
                if (yyin == NULL) {
                    fprintf(stderr, "Error: Cannot open file `%s`.\n", cag_option_get_value(&context));
                    return EXIT_FAILURE;
                }
                break;
            case 't':
                is_test_mode = true;
                printf("Running in test mode, parsing won't stop when future features are not implemented.\n\n");
                break;
        }
    }

    int result = yyparse();
    
    if (is_multi_line_comment) {
        printf("lexcial error in line(%llu:%llu): Unbalance multi-line comment\n", line_count, line_word_count);
        return 1001; /* lexical error: Unexcept character */
    }

    free_symbol_table();

    fclose(yyin);

    return result;
}