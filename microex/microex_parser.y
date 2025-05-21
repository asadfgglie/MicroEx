%{
    #include "../microex/util.h"

    symbol *symbol_table = NULL;

    node* id_list_head = NULL;
    node* id_list_tail = NULL;

    void add_node(symbol* symbol_ptr) {
        node* new_node = (node*)malloc(sizeof(node));
        new_node->symbol_ptr = symbol_ptr;
        new_node->next = NULL;

        if (id_list_head == NULL) {
            id_list_head = new_node;
            id_list_tail = new_node;
        } else {
            id_list_tail->next = new_node;
            id_list_tail = new_node;
        }
    }
    void free_node_list() {
        node* current = id_list_head;
        node* next_node;

        while (current != NULL) {
            next_node = current->next;
            free(current);
            current = next_node;
        }

        id_list_head = NULL;
        id_list_tail = NULL;
    }
%}

%union {
    int int_val;
    char *str_val;
    double double_val;
    symbol *symbol_ptr;
    data_type type;
    array_type array_info;
}

%token PROGRAM_MICOREX
%token BEGIN_MICOREX
%token END_MICOREX
%token READ_MICOREX
%token WRITE_MICOREX
%token <symbol_ptr> ID_MICOREX
%token <int_val> INTEGER_LITERAL_MICOREX
%token <double_val> FLOAT_LITERAL_MICOREX
%token <double_val> EXP_FLOAT_LITERAL_MICOREX
%token <str_val> STRING_LITERAL_MICOREX
%token LEFT_PARENT_MICOREX
%token RIGHT_PARENT_MICOREX
%token LEFT_BRACKET_MICOREX
%token RIGHT_BRACKET_MICOREX
%token SEMICOLON_MICOREX
%token COMMA_MICOREX
%token ASSIGN_MICOREX
%token PLUS_MICOREX
%token MINUS_MICOREX
%token MULTIPLY_MICOREX
%token DIVISION_MICOREX
%token NOT_EQUAL_MICOREX
%token EQUAL_MICOREX
%token GREAT_MICOREX
%token LESS_MICOREX
%token GREAT_EQUAL_MICOREX
%token LESS_EQUAL_MICOREX
%token IF_MICOREX
%token THEN_MICOREX
%token ELSE_MICOREX
%token ENDIF_MICOREX
%token FOR_MICOREX
%token ENDFOR_MICOREX
%token WHILE_MICOREX
%token ENDWHILE_MICOREX
%token DECLARE_MICOREX
%token AS_MICOREX
%token <type> INTEGER_MICOREX
%token <type> REAL_MICOREX
%token <type> STRING_MICOREX
%token TO_MICOREX
%token DOWNTO_MICOREX

%type <type> type
%type <symbol_ptr> program_title
%type <symbol_ptr> id_list
%type <symbol_ptr> id
%type <array_info> array_dimension
%type <array_info> array_dimension_list

%%

program:
    program_title
    program_body {
        printf("halt %s\n", $1->name);
        printf("\t> program -> program_title program_body\n");
        printf("\t\t> Program done with name: `%s`\n", $1->name);
    }
    ;
program_title:
    PROGRAM_MICOREX ID_MICOREX {
        $2->type = TYPE_PROGRAM_NAME;
        $$ = $2;
        printf("start %s\n", $2->name);
        printf("\t> program_title -> program id (program_title -> program %s)\n", $2->name);
        printf("\t\t> Program start with name: `%s`\n", $2->name);
    }
    ;
program_body:
    BEGIN_MICOREX
        statement_list
    END_MICOREX {
        printf("\t> program_body -> begin statement_list end\n");
    }
    ;
statement_list:
    statement {
        printf("\t> statement_list -> statement\n");
    }
    | statement_list statement {
        printf("\t> statement_list -> statement_list statement\n");
    }
    ;
statement:
    declare_statement {
        printf("\t> statement -> declare_statement\n");
    }
    /* 
    | assignment_statement
    | read_statement
    | write_statement
    | if_statement
    | for_statement
    | while_statement 
    */
    ;
declare_statement:
    DECLARE_MICOREX id_list AS_MICOREX type SEMICOLON_MICOREX {
        node *current = id_list_head;
        node *next;
        int ids_name_len = 1;
        while (current != NULL) {
            current->symbol_ptr->type = $4;
            printf("declare %s %s\n", current->symbol_ptr->name, data_type_to_string($4));
            ids_name_len += strlen(current->symbol_ptr->name);
            current = current->next;
        }
        char *ids_name = (char *)malloc(sizeof(char) * ids_name_len);
        if (ids_name == NULL) {
            yyerror("Out of memory when malloc.");
        }
        ids_name[0] = '\0';
        current = id_list_head;
        while (current != NULL) {
            if (ids_name[0] != '\0') {
                sprintf(ids_name, "%s, %s", ids_name, current->symbol_ptr->name);
            } else {
                sprintf(ids_name, "%s", current->symbol_ptr->name);
            }
            current = current->next;
        }
        printf("\t> declare_statement -> declare id_list as type semicolon (declare_statement -> declare %s as %s;)\n", ids_name, data_type_to_string($4));
        free(ids_name);
        free_node_list();
    }
    ;
id_list:
    id {
        $$ = $1;
        add_node($1);
        printf("\t> id_list -> id (id_list -> %s)\n", $1->name);
    }
    | id_list COMMA_MICOREX id {
        $$ = $1;
        add_node($3);
        int ids_name_len = 1;
        node *current = id_list_head;
        node *next;
        while (current != NULL) {
            ids_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                ids_name_len += 2; // for ", "
            }
            current = current->next;
        }
        char *ids_name = (char *)malloc(sizeof(char) * ids_name_len);
        if (ids_name == NULL) {
            yyerror("Out of memory when malloc.");
        }
        ids_name[0] = '\0';
        current = id_list_head;
        while (current != NULL) {
            if (ids_name[0] != '\0') {
                sprintf(ids_name, "%s, %s", ids_name, current->symbol_ptr->name);
            } else {
                sprintf(ids_name, "%s", current->symbol_ptr->name);
            }
            current = current->next;
        }
        printf("\t> id_list -> id_list comma id (id_list -> %s)\n", ids_name);
        free(ids_name);
    }
    ;
id:
    ID_MICOREX {
        $$ = $1;
        printf("\t> id -> ID (id -> %s)\n", $1->name);
    }
    | ID_MICOREX array_dimension_list {
        $$ = $1;
        $$->array_info = $2;
        char *dimensions = (char *)malloc(sizeof(char) * $$->array_info.dimensions * 3);
        if (dimensions == NULL) {
            yyerror("Out of memory when malloc.");
        }
        dimensions[0] = '\0';
        for (int i = 0; i < $$->array_info.dimensions; i++) {
            sprintf(dimensions, "%s[%d]", dimensions, $$->array_info.dimension_sizes[i]);
        }
        printf("\t> id -> ID array_dimension_list (id -> %s%s)\n", $1->name, dimensions);
        free(dimensions);
    }
    ;
array_dimension:
    LEFT_BRACKET_MICOREX INTEGER_LITERAL_MICOREX RIGHT_BRACKET_MICOREX {
        $$.dimensions = 1;
        $$.dimension_sizes = (int *)malloc(sizeof(int) * $$.dimensions);
        if ($$.dimension_sizes == NULL) {
            yyerror("Out of memory when malloc.");
        }
        $$.dimension_sizes[$$.dimensions - 1] = $2;
        printf("\t> array_dimension -> LEFT_BRACKET INTEGER_LITERAL RIGHT_BRACKET (array_dimension -> [%d])\n", $2);
    }
    ;
array_dimension_list:
    array_dimension {
        $$ = $1;
        printf("\t> array_dimension_list -> array_dimension (array_dimension_list -> [%d])\n", $1.dimension_sizes[0]);
    }
    | array_dimension_list array_dimension {
        $$.dimensions = $1.dimensions + 1;
        $$.dimension_sizes = (int *)realloc($$.dimension_sizes, sizeof(int) * $$.dimensions);
        if ($$.dimension_sizes == NULL) {
            yyerror("Out of memory when realloc.");
        }
        $$.dimension_sizes[$$.dimensions - 1] = $2.dimension_sizes[0];
        char *dimensions = (char *)malloc(sizeof(char) * $$.dimensions * 3);
        if (dimensions == NULL) {
            yyerror("Out of memory when malloc.");
        }
        dimensions[0] = '\0';
        for (int i = 0; i < $$.dimensions; i++) {
            sprintf(dimensions, "%s[%d]", dimensions, $$.dimension_sizes[i]);
        }
        printf("\t> array_dimension_list -> array_dimension_list array_dimension (array_dimension_list -> %s)\n", dimensions);
        free(dimensions);
    }
    ;

type:
    INTEGER_MICOREX {
        $$ = $1;
        printf("\t> type -> INTEGER\n");
    }
    | REAL_MICOREX {
        $$ = $1;
        printf("\t> type -> REAL\n");
    }
    | STRING_MICOREX {
        $$ = $1;
        printf("\t> type -> STRING\n");
    }
    ;

%%
