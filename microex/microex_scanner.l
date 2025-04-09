%{
    #include <stdbool.h>
    #include "../lib/uthash.h"
    #define MAX_ERROR_MSG_LEN 256
    #define MAX_TOKEN_NAME_LEN 64
    unsigned long long line_count = 1, line_word_count = 0;
    bool is_multi_line_comment = false;
    char error_msg[MAX_ERROR_MSG_LEN];

    typedef struct id_map{
        int token_id;
        char token_name[MAX_TOKEN_NAME_LEN];
        UT_hash_handle hh;
    } IdMap;

    typedef struct token_map {
        int token_id;
        char token_name[MAX_TOKEN_NAME_LEN];
        UT_hash_handle hh;
    } TokenMap;
    
    TokenMap *token_map = NULL; // automatically initialized by uthash
    IdMap *id_map = NULL; // automatically initialized by uthash

    /**
     * 1. check if token_name is already in the map
     * 2. if not, add it to the map with a new id 
     *    (incremental id order based on the number of tokens in the map)
     * 3. return the id of the token
     */
    int token_id_register(char *token_name) {
        TokenMap *s;
        HASH_FIND_STR(token_map, token_name, s);
        if (s == NULL) {
            s = malloc(sizeof(TokenMap));
            strcpy(s->token_name, token_name);
            s->token_id = HASH_COUNT(token_map) + 1;
            HASH_ADD_STR(token_map, token_name, s);
        }

        IdMap *id_s;
        HASH_FIND_INT(id_map, &s->token_id, id_s);
        if (id_s == NULL) {
            id_s = malloc(sizeof(IdMap));
            strcpy(id_s->token_name, token_name);
            id_s->token_id = s->token_id;
            HASH_ADD_INT(id_map, token_id, id_s);
        }

        return s->token_id;
    }

    void init_token_map() {
        /* pre-register all tokens */
        // default token id: 1 - 38
        // EOF token id: 38
        token_id_register("begin");
        token_id_register("end");
        token_id_register("read");
        token_id_register("write");
        token_id_register("id");
        token_id_register("integer_literal");
        token_id_register("float_literal");
        token_id_register("exp_float_literal");
        token_id_register("string_literal");
        token_id_register("left_parent");
        token_id_register("right_parent");
        token_id_register("semicolon");
        token_id_register("comma");
        token_id_register("assign");
        token_id_register("plus");
        token_id_register("minus");
        token_id_register("multiply");
        token_id_register("division");
        token_id_register("not_equal");
        token_id_register("great");
        token_id_register("less");
        token_id_register("great_equal");
        token_id_register("less_equal");
        token_id_register("equal");
        token_id_register("if");
        token_id_register("then");
        token_id_register("else");
        token_id_register("endif");
        token_id_register("for");
        token_id_register("to");
        token_id_register("endfor");
        token_id_register("while");
        token_id_register("endwhile");
        token_id_register("declare");
        token_id_register("as");
        token_id_register("integer");
        token_id_register("real");
        token_id_register("EOF");

        // new feature token id: 39~
        token_id_register("hex_integer_literal");
        token_id_register("ord_integer_literal");
        token_id_register("bit_integer_literal");

        token_id_register("char_literal");
        token_id_register("char");
        token_id_register("r_string_literal");
        token_id_register("string");
        
        token_id_register("import");

        token_id_register("boolean");
        token_id_register("true");
        token_id_register("false");

        token_id_register("binary_and");
        token_id_register("binary_or");
        token_id_register("binary_xor");
        token_id_register("binary_boolean_not");
        token_id_register("binary_and_equal");
        token_id_register("binary_or_equal");
        token_id_register("binary_xor_equal");

        token_id_register("boolean_and");
        token_id_register("boolean_or");

        token_id_register("mod");
        token_id_register("power");
        token_id_register("left_shift");
        token_id_register("right_shift");

        token_id_register("plus_equal");
        token_id_register("minus_equal");
        token_id_register("multiply_equal");
        token_id_register("division_equal");
        token_id_register("mod_equal");
        token_id_register("left_shift_equal");
        token_id_register("right_shift_equal");
        token_id_register("power_equal");

        token_id_register("class");
        token_id_register("endclass");
        token_id_register("extends");
        token_id_register("implements");
        token_id_register("public");
        token_id_register("private");
        token_id_register("protect");
        token_id_register("static");
        token_id_register("final");
        token_id_register("this");
        token_id_register("super");
        token_id_register("abstract");
        token_id_register("interface");
        token_id_register("endinterface");

        token_id_register("dot");

        token_id_register("fn");
        token_id_register("return");
        token_id_register("void");
        token_id_register("endfn");

        token_id_register("null");

        token_id_register("switch");
        token_id_register("case");
        token_id_register("default");
        token_id_register("endswitch");

        token_id_register("break");
        token_id_register("continue");

        token_id_register("oper");
        token_id_register("endoper");
    }

    void free_token_map() {
        IdMap *current_id, *id_tmp;
        HASH_ITER(hh, id_map, current_id, id_tmp) {
            HASH_DEL(id_map, current_id);
            free(current_id);
        }
        TokenMap *current_token, *tmp;
        HASH_ITER(hh, token_map, current_token, tmp) {
            HASH_DEL(token_map, current_token);
            free(current_token);
        }
    }

    /**
     * New feature:
     *  - add multi-line comment
     *  - add string literal, allow escape characters \n, \t, \", \\
     *  - add 16-bit integer literal 
     *       (ex: 0xabcd)
     *  - add 8-bit integer literal
     *       (ex: 0o1275)
     *  - add 2-bit integer literal
     *       (ex: 0b101010)
     *  - add underscore in integer literal
     *       (ex: 1_000_000)
     *  - add character literal
     *       (ex: 'a', '1', '\n')
     *  - add original string literal
     *       (ex: r"abc\n" == "abc\\n")
     *  - add import token for pacakage management
     *       (ex: import "package_name";)
     *  - add boolean literal
     *       (true, false, boolean)
     *  - add more operators: &, |, ^, !, &&, ||, <<, >>, +=, -=, *=, /=, %=, &=, 
     *                        |=, ^=, <<=, >>=, **, **=, %
     *  - add OOP keywords: class, extends, implements, public, private, protect, 
     *                      static, final, this, super, abstract, interface, . (access class member)
     *                      (reference Java OOP)
     *  - add function keywords: fn, return, void, endfn
     *       (ex: fn real add(real a, real b) return a + b endfn)
     *  - add null keyword
     *  - add switch-case keywords: switch, case, default, endswitch
     *       (ex: switch(a)
     *              case (1) 
     *                  write("a is 1"); 
     *                  break;
     *              case (2)
     *                  write("a is 2");
     *                  break;
     *              default 
     *                  write("a is not 1");
     *            endswitch)
     *  - add break, continue keywords
     *  - add operator overloading keywords: oper, endoper
     *       (ex: oper + (int a, int b) return a + b; endoper)
    */
%}

empty_word [ \t]+
new_line \n

line_comment %%(((\n)?)|([^\n%][^\n]*((\n)?)))
multi_line_comment "%%%"

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

hex_integer_literal 0[xX]([0-9a-fA-F]+)
ord_integer_literal 0[oO]([0-7]+)
bit_integer_literal 0[bB]([01]+)
char_literal \'(([^\n\'\\])|(\\\")|(\\\\)|(\\n)|(\\t)|(\\b)|(\\\'))\'
char [Cc][Hh][Aa][Rr]
r_string_literal r{string_literal}
string [Ss][Tt][Rr][Ii][Nn][Gg]

import [Ii][Mm][Pp][Oo][Rr][Tt]

true [Tt][Rr][Uu][Ee]
false [Ff][Aa][Ll][Ss][Ee]
boolean [Bb][Oo][Oo][Ll][Ee][Aa][Nn]

binary_and "&"
binary_or "|"
binary_xor "^"
binary_boolean_not "!"
binary_and_equal "&="
binary_or_equal "|="
binary_xor_equal "^="

boolean_and "&&"
boolean_or "||"

mod "%"
power "**"

left_shift "<<"
right_shift ">>"
plus_equal "+="
minus_equal "-="
multiply_equal "*="
division_equal "/="
mod_equal "%="
left_shift_equal "<<="
right_shift_equal ">>="
power_equal "**="

class [Cc][Ll][Aa][Ss][Ss]
endclass [Ee][Nn][Dd][Cc][Ll][Aa][Ss][Ss]
extends [Ee][Xx][Tt][Ee][Nn][Dd][Ss]
implements [Ii][Mm][Pp][Ll][Ee][Mm][Ee][Nn][Tt][Ss]
public [Pp][Uu][Bb][Ll][Ii][Cc]
private [Pp][Rr][Ii][Vv][Aa][Tt][Ee]
protect [Pp][Rr][Oo][Tt][Ee][Cc][Tt]
static [Ss][Tt][Aa][Tt][Ii][Cc]
final [Ff][Ii][Nn][Aa][Ll]
this [Tt][Hh][Ii][Ss]
super [Ss][Uu][Pp][Ee][Rr]
abstract [Aa][Bb][Ss][Tt][Rr][Aa][Cc][Tt]
interface [Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee]
endinterface [Ee][Nn][Dd][Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee]
dot \.

fn [Ff][Nn]
return [Rr][Ee][Tt][Uu][Rr][Nn]
void [Vv][Oo][Ii][Dd]
endfn [Ee][Nn][Dd][Ff][Nn]

null [Nn][Uu][Ll][Ll]

switch [Ss][Ww][Ii][Tt][Cc][Hh]
case [Cc][Aa][Ss][Ee]
default [Dd][Ee][Ff][Aa][Uu][Ll][Tt]
endswitch [Ee][Nn][Dd][Ss][Ww][Ii][Tt][Cc][Hh]

break [Bb][Rr][Ee][Aa][Kk]
continue [Cc][Oo][Nn][Tt][Ii][Nn][Uu][Ee]

oper [Oo][Pp][Ee][Rr]
endoper [Ee][Nn][Dd][Oo][Pp][Ee][Rr]

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

{begin} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("begin");
    }
}
{end} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("end");
    }
}
{read} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("read");
    }
}
{write} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("write");
    }
}
{integer_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("integer_literal");
    }
}
{float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("float_literal");
    }
}
{exp_float_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("exp_float_literal");
    }
}
{string_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("string_literal");
    }
}
{left_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("left_parent");
    }
}
{right_parent} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("right_parent");
    }
}
{semicolon} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("semicolon");
    }
}
{comma} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("comma");
    }
}
{assign} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("assign");
    }
}
{plus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("plus");
    }
}
{minus} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("minus");
    }
}
{multiply} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("multiply");
    }
}
{division} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("division");
    }
}
{not_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("not_equal");
    }
}
{great} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("great");
    }
}
{less} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("less");
    }
}
{great_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("great_equal");
    }
}
{less_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("less_equal");
    }
}
{equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("equal");
    }
}
{if} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("if");
    }
}
{then} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("then");
    }
}
{else} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("else");
    }
}
{endif} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endif");
    }
}
{for} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("for");
    }
}
{to} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("to");
    }
}
{endfor} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endfor");
    }
}
{while} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("while");
    }
}
{endwhile} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endwhile");
    }
}
{declare} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("declare");
    }
}
{as} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("as");
    }
}
{integer} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("integer");
    }
}
{real} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("real");
    }
}

{hex_integer_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("hex_integer_literal");
    }
}
{ord_integer_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("ord_integer_literal");
    }
}
{bit_integer_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("bit_integer_literal");
    }
}
{char_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("char_literal");
    }
}
{char} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("char");
    }
}
{r_string_literal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("r_string_literal");
    }
}
{string} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("string");
    }
}
{import} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("import");
    }
}
{true} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("true");
    }
}
{false} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("false");
    }
}
{boolean} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("boolean");
    }
}
{binary_and} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("binary_and");
    }
}
{binary_or} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("binary_or");
    }
}
{binary_xor} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("binary_xor");
    }
}
{binary_boolean_not} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("binary_boolean_not");
    }
}
{binary_and_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("binary_and_equal");
    }
}
{binary_or_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("binary_or_equal");
    }
}
{binary_xor_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("binary_xor_equal");
    }
}
{boolean_and} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("boolean_and");
    }
}
{boolean_or} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("boolean_or");
    }
}
{mod} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("mod");
    }
}
{power} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("power");
    }
}
{left_shift} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("left_shift");
    }
}
{right_shift} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("right_shift");
    }
}
{plus_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("plus_equal");
    }
}
{minus_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("minus_equal");
    }
}
{multiply_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("multiply_equal");
    }
}
{division_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("division_equal");
    }
}
{mod_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("mod_equal");
    }
}
{left_shift_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("left_shift_equal");
    }
}
{right_shift_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("right_shift_equal");
    }
}
{power_equal} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("power_equal");
    }
}
{class} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("class");
    }
}
{endclass} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endclass");
    }
}
{extends} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("extends");
    }
}
{implements} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("implements");
    }
}
{public} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("public");
    }
}
{private} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("private");
    }
}
{protect} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("protect");
    }
}
{static} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("static");
    }
}
{final} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("final");
    }
}
{this} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("this");
    }
}
{super} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("super");
    }
}
{abstract} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("abstract");
    }
}
{interface} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("interface");
    }
}
{endinterface} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endinterface");
    }
}
{dot} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("dot");
    }
}
{fn} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("fn");
    }
}
{return} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("return");
    }
}
{void} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("void");
    }
}
{endfn} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endfn");
    }
}
{null} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("null");
    }
}
{switch} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("switch");
    }
}
{case} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("case");
    }
}
{default} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("default");
    }
}
{endswitch} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endswitch");
    }
}
{break} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("break");
    }
}
{continue} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("continue");
    }
}
{oper} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("oper");
    }
}
{endoper} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("endoper");
    }
}

{id} {
    line_word_count += yyleng;
    if (!is_multi_line_comment) {
        return token_id_register("id");
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

    init_token_map();

    int token_id = -1;
    while((token_id = yylex()) != 0) {
        IdMap* id_s;
        HASH_FIND_INT(id_map, &token_id, id_s);
        if (id_s == NULL) {
            printf("lexcial error in line(%llu:%llu): %s\n", line_count, line_word_count, error_msg);
            return token_id;
        }
        else {
            printf("Token number = %3d,\ttoken is `%-19s`,\tvalue is `%s`\n", id_s->token_id, id_s->token_name, yytext);
        }
    }
    if (is_multi_line_comment) {
        printf("lexcial error in line(%llu:%llu): Unbalance multi-line comment\n", line_count, line_word_count);
        return 1001; /* lexical error: Unexcept character */
    }
    TokenMap* s;
    HASH_FIND_STR(token_map, "EOF", s);
    printf("Token number = %3d,\ttoken is `%-19s`,\tvalue is `%s`\n", s->token_id, s->token_name, s->token_name);

    free_token_map();
    
    fclose(yyin);
    
    return 0;
}