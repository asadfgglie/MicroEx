%{
    #include <stdbool.h>
    #include <math.h>
    #include "../lib/uthash.h"
    #include "../microex/util.h"
    #include "../build/y.tab.h"

    unsigned long long line_count = 1, line_word_count = 0;
    bool is_multi_line_comment = false;
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
        yylval.int_val = atoi(yytext);
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
        yyerror(error_msg);
        return -1; /* lexical error: Unexcept character */
    }
}

%%

char *data_type_to_string(data_type type) {
    switch (type) {
        case TYPE_INT:
            return strdup("integer");
        case TYPE_DOUBLE:
            return strdup("real");
        case TYPE_STRING:
            return strdup("string");
        case TYPE_PROGRAM_NAME:
            return strdup("program");
        default:
            yyerror("Unknown data type");
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
        yyerror("Out of memory when malloc.");
    }

    s->name = strdup(name);
    s->type = TYPE_UNKNOWN;
    s->array_info.dimensions = 0;
    s->array_info.dimension_sizes = NULL;

    HASH_ADD_STR(symbol_table, name, s);
}

void free_symbol_table() {
    symbol *current_symbol, *symbol_tmp;
    HASH_ITER(hh, symbol_table, current_symbol, symbol_tmp) {
        HASH_DEL(symbol_table, current_symbol);
        free(current_symbol->name);
        if (current_symbol->type == TYPE_STRING) {
            free(current_symbol->value.str_val);
        }
        free(current_symbol);
    }
}

void yyerror(const char *msg) {
    fprintf(stderr, "Error: %s\nat line (%llu:%llu)\n", msg, line_count, line_word_count);
    exit(EXIT_FAILURE);
}

// for Bison yacc to call parser
int main(int argc, char **argv) {
    if (argc == 2) {
        FILE *fp = fopen(argv[1], "r");
        if (fp == NULL) {
            printf("Error opening file: %s\n", argv[1]);
            return EXIT_FAILURE;
        }
        yyin = fp;
    }
    else {
        printf("Usage: %s <filename>\n", argv[0]);
        return EXIT_FAILURE;
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