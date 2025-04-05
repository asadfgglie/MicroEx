%{
    #include <stdbool.h>
    #define MAX_ERROR_MSG_LEN 256
    unsigned long long line_count = 1, line_word_count = 0;
    bool is_multi_line_comment = false;
    char error_msg[MAX_ERROR_MSG_LEN];
    /**
     * New feature:
     *  - add multi-line comment
     *  - add string literal, allow escape characters \n, \t, \", \\
     *  - add 嚴格縮排: begin, end, if, then, else, endif, for, to, endfor, while, endwhile
     *  - add not allow re-declare
    */
%}

empty_word [ \t]+
new_line \n

line_comment %%((\n)|([^\n%][^\n]*\n))
multi_line_comment "%%%"

begin [Bb][Ee][Gg][Ii][Nn]
end [Ee][Nn][Dd]
read [Rr][Ee][Aa][Dd]
write [Ww][Rr][Ii][Tt][Ee]
id ([a-zA-Z]|_)+([0-9]*|_|[a-zA-Z])
integer_literal ([1-9][0-9]+)|[0-9]
float_literal ({integer_literal}\.)|(\.{integer_literal})|({integer_literal}\.{integer_literal})
exp_float_literal {float_literal}[Ee][+-]?{integer_literal}
string_literal \"([^\n\"\\]*|(\\\")*|(\\\\)*|(\\n)*|(\\t)*|(\\b)*)*\"
left_parent "("
right_parent ")"
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
to [Tt][Oo]

%%

{empty_word} {
    line_word_count += yyleng;
}
{new_line}|{line_comment} {
    line_count += 1;
    line_word_count = 0;
}
{multi_line_comment} {
    is_multi_line_comment = !is_multi_line_comment;
}

{begin} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 1;
    }
}
{end} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 2;
    }
}
{read} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 3;
    }
}
{write} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 4;
    }
}
{integer_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 6;
    }
}
{float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 7;
    }
}
{exp_float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 8;
    }
}
{string_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        if (yytext[yyleng - 1] == '\"') {
            return 9;
        }
        else {
            sprintf(error_msg, "string quote not balance");
            return 1001; /* lexical error: string quote not balance */
        }
    }
}
{left_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 10;
    }
}
{right_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 11;
    }
}
{semicolon} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 12;
    }
}
{comma} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 13;
    }
}
{assign} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 14;
    }
}
{plus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 15;
    }
}
{minus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 16;
    }
}
{multiply} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 17;
    }
}
{division} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 18;
    }
}
{not_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 19;
    }
}
{great} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 20;
    }
}
{less} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 21;
    }
}
{great_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 22;
    }
}
{less_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 23;
    }
}
{equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 24;
    }
}
{if} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 25;
    }
}
{then} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 26;
    }
}
{else} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 27;
    }
}
{endif} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 28;
    }
}
{for} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 29;
    }
}
{to} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 30;
    }
}
{endfor} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 31;
    }
}
{while} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 32;
    }
}
{endwhile} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 33;
    }
}
{declare} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 34;
    }
}
{as} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 35;
    }
}
{integer} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 36;
    }
}
{real} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 37;
    }
}
{id} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return 5;
    }
}

. {
    line_word_count += yyleng;
    if (!is_multi_line_comment)  {
        sprintf(error_msg, "Unexcept character: %s", yytext);
        return 1000; /* lexical error: Unexcept character */
    }
}

%%

int main(int argc, char **argv) {
    if (argc == 2) {
        FILE *fp = fopen(argv[1], "r");
        if (fp == NULL) {
            printf("Error opening file: %s\n", argv[1]);
            return 1;
        }
        yyin = fp;
    }
    else if (argc == 1) {
        yyin = stdin;
    }
    else {
        printf("Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    int token_id = -1;
    while((token_id = yylex()) != 0) {
        if (token_id < 1000) {
            printf("Token number = %d,\tvalue is \"%s\"\n", token_id, yytext);
        }
        else {
            printf("lexcial error in line(%llu:%llu): %s\n", line_count, line_word_count, error_msg);
            return token_id;
        }
    }
    printf("Token number = 38,\tvalue is \"EOF\"\n");
    return 0;
}