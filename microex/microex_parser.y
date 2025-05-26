%{
    #include <string.h>
    #include <unistd.h>
    #include "../microex/util.h"

    symbol *symbol_table = NULL;
    symbol *temp_symbol_table = NULL;
    // subset of symbol_table for temporary variables
    // ensure that temporary variable do not conflict with user-defined variables
    // temporary variables must exist in the symbol table

    node* id_list_head = NULL;
    node* id_list_tail = NULL;

    char *dimensions = NULL; // temporary variable to store array dimensions string
    // to avoid memory leak, we will free this variable after use

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
    long long int_val;
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
%type <symbol_ptr> expression

%left GREAT_MICOREX LESS_MICOREX GREAT_EQUAL_MICOREX LESS_EQUAL_MICOREX EQUAL_MICOREX NOT_EQUAL_MICOREX
%left PLUS_MICOREX MINUS_MICOREX
%left MULTIPLY_MICOREX DIVISION_MICOREX
%nonassoc UMINUS_MICOREX

%%

program:
    program_title
    program_body {
        printf("HALT %s\n", $1->name);
        printf("\t> program -> program_title program_body\n");
        printf("\t\t> Program done with name: `%s`\n", $1->name);

        symbol *current_symbol, *next_symbol;
        HASH_ITER(hh, temp_symbol_table, current_symbol, next_symbol) {
            printf("DECLARE %s %s\n", current_symbol->name, data_type_to_string(current_symbol->type));
        }
    }
    ;
program_title:
    PROGRAM_MICOREX ID_MICOREX {
        $2->type = TYPE_PROGRAM_NAME;
        $$ = $2;
        printf("START %s\n", $2->name);
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
    | assignment_statement {
        printf("\t> statement -> assignment_statement\n");
    }
    | read_statement {
        printf("\t> statement -> read_statement\n");
    }
    | write_statement {
        printf("\t> statement -> write_statement\n");
    }
    | if_statement {
        printf("\t> statement -> if_statement\n");
    }
    | for_statement {
        printf("\t> statement -> for_statement\n");
    }
    | while_statement {
        printf("\t> statement -> while_statement\n");
    }
    ;

// declare statement
declare_statement:
    DECLARE_MICOREX id_list AS_MICOREX type SEMICOLON_MICOREX {
        node *current = id_list_head;
        size_t ids_name_len = 1;
        size_t ids_name_count = 0;
        while (current != NULL) {
            if (current->symbol_ptr->type != TYPE_UNKNOWN) {
                yyerror_name("Variable already declared.", "Redeclaration");
            }
            current->symbol_ptr->type = $4;
            if (current->symbol_ptr->array_pointer.dimensions > 0) {
                for (size_t i = 0; i < current->symbol_ptr->array_pointer.dimensions; i++) {
                    if (current->symbol_ptr->array_pointer.dimension_sizes[i] <= 0) {
                        yyerror_name("Array dimension must be greater than 0 when declaring.", "Index");
                    }
                }
                char *array_dimensions = array_range_to_string(current->symbol_ptr->array_pointer);
                char *type_str = data_array_type_to_string($4);
                printf("DECLARE %s %s %s\n", current->symbol_ptr->name, type_str, array_dimensions);
                free(type_str);
                free(array_dimensions);
                current->symbol_ptr->array_info = current->symbol_ptr->array_pointer;
                array_type empty_pointer = {
                    .dimensions = 0,
                    .dimension_sizes = NULL
                };
                current->symbol_ptr->array_pointer = empty_pointer;

                switch ($4) {
                    case TYPE_INT:
                        current->symbol_ptr->value.int_array = (long long *)calloc(array_range(current->symbol_ptr->array_info), sizeof(long long));
                        if (current->symbol_ptr->value.int_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_range(current->symbol_ptr->array_info); i++) {
                            printf("I_STORE 0 %s[%zu]\n", current->symbol_ptr->name, i);
                        }
                        break;
                    case TYPE_DOUBLE:
                        current->symbol_ptr->value.double_array = (double *)calloc(array_range(current->symbol_ptr->array_info), sizeof(double));
                        if (current->symbol_ptr->value.double_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_range(current->symbol_ptr->array_info); i++) {
                            printf("F_STORE 0.0 %s[%zu]\n", current->symbol_ptr->name, i);
                        }
                        break;
                    case TYPE_STRING:
                        current->symbol_ptr->value.str_array = (char **)calloc(array_range(current->symbol_ptr->array_info), sizeof(char *));
                        if (current->symbol_ptr->value.str_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_range(current->symbol_ptr->array_info); i++) {
                            current->symbol_ptr->value.str_array[i] = (char *)malloc(sizeof(char) * 1); // Allocate memory for empty string
                            if (current->symbol_ptr->value.str_array[i] == NULL) {
                                yyerror_name("Out of memory when malloc.", "Parsing");
                            }
                            current->symbol_ptr->value.str_array[i][0] = '\0'; // Initialize to empty string
                        }
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    default:
                        yyerror_name("Unknown data type in declare statement.", "Parsing");
                }
            }
            else {
                char *type_str = data_type_to_string($4);
                if (type_str == NULL) {
                    yyerror_name("Unknown data type.", "Parsing");
                }
                printf("DECLARE %s %s\n", current->symbol_ptr->name, type_str);
                free(type_str);

                switch ($4) {
                    case TYPE_INT:
                        current->symbol_ptr->value.int_val = 0;
                        printf("I_STORE 0 %s\n", current->symbol_ptr->name);
                        break;
                    case TYPE_DOUBLE:
                        current->symbol_ptr->value.double_val = 0.0;
                        printf("F_STORE 0.0 %s\n", current->symbol_ptr->name);
                        break;
                    case TYPE_STRING:
                        current->symbol_ptr->value.str_val = (char *)malloc(sizeof(char) * 1); // Allocate memory for empty string
                        if (current->symbol_ptr->value.str_val == NULL) {
                            yyerror_name("Out of memory when malloc.", "Parsing");
                        }
                        current->symbol_ptr->value.str_val[0] = '\0'; // Initialize to empty string
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    default:
                        yyerror_name("Unknown data type in declare statement.", "Parsing");
                }
            }
            ids_name_len += strlen(current->symbol_ptr->name);
            ids_name_count++;
            current = current->next;
        }
        char *ids_name = (char *)malloc(sizeof(char) * (ids_name_len + (ids_name_count - 1) * 2 + 1)); // +1 for null terminator
        if (ids_name == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
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
        char *type_str = data_type_to_string($4);
        printf("\t> declare_statement -> declare id_list as type semicolon (declare_statement -> declare %s as %s;)\n", ids_name, type_str);
        free(type_str);
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
        size_t ids_name_len = 1;
        node *current = id_list_head;
        while (current != NULL) {
            ids_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                ids_name_len += 2; // for ", "
            }
            current = current->next;
        }
        char *ids_name = (char *)malloc(sizeof(char) * ids_name_len);
        if (ids_name == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
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
        $$->array_pointer = $2;
        dimensions = array_dimensions_to_string($2);
        printf("\t> id -> ID array_dimension_list (id -> %s%s)\n", $1->name, dimensions);
        free(dimensions);
    }
    ;
array_dimension:
    LEFT_BRACKET_MICOREX INTEGER_LITERAL_MICOREX RIGHT_BRACKET_MICOREX {
        $$.dimensions = 1;
        $$.dimension_sizes = (size_t *)malloc(sizeof(size_t) * $$.dimensions);
        if ($$.dimension_sizes == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        if ($2 < 0) {
            yyerror_name("Array dimension must be greater equal than 0.", "Index");
        }
        $$.dimension_sizes[$$.dimensions - 1] = $2;
        printf("\t> array_dimension -> LEFT_BRACKET INTEGER_LITERAL RIGHT_BRACKET (array_dimension -> [%lld])\n", $2);
    }
    | LEFT_BRACKET_MICOREX expression RIGHT_BRACKET_MICOREX {
        if ($2->type != TYPE_INT) {
            yyerror_name("Array dimension must be integer greater than 0.", "Index");
        }
        $$.dimensions = 1;
        $$.dimension_sizes = (size_t *)malloc(sizeof(size_t) * $$.dimensions);
        if ($$.dimension_sizes == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        if ($2->value.int_val < 0) {
            yyerror_name("Array dimension must be greater equal than 0.", "Index");
        }
        $$.dimension_sizes[$$.dimensions - 1] = $2->value.int_val;
        printf("\t> array_dimension -> LEFT_BRACKET INTEGER_LITERAL RIGHT_BRACKET (array_dimension -> [%lld])\n", $2->value.int_val);
    }
    ;
array_dimension_list:
    array_dimension {
        $$ = $1;
        printf("\t> array_dimension_list -> array_dimension (array_dimension_list -> [%zu])\n", $1.dimension_sizes[0]);
    }
    | array_dimension_list array_dimension {
        $$.dimensions = $1.dimensions + 1;
        $$.dimension_sizes = (size_t *)realloc($$.dimension_sizes, sizeof(size_t) * $$.dimensions);
        if ($$.dimension_sizes == NULL) {
            yyerror_name("Out of memory when realloc.", "Parsing");
        }
        $$.dimension_sizes[$$.dimensions - 1] = $2.dimension_sizes[0];
        dimensions = (char *)malloc(sizeof(char) * $$.dimensions * 3);
        if (dimensions == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        dimensions[0] = '\0';
        for (size_t i = 0; i < $$.dimensions; i++) {
            sprintf(dimensions, "%s[%zu]", dimensions, $$.dimension_sizes[i]);
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
    // This bad body is too difficult to implement,
    // so we currently do not support string and won't generate code for it.
    | STRING_MICOREX {
        // TODO: implement STRING type if have time
        $$ = $1;
        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
        printf("\t> type -> STRING\n");
    }
    ;

assignment_statement:
    id ASSIGN_MICOREX expression SEMICOLON_MICOREX {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Variable not declared.", "Undeclared");
        }
        if ($1->array_pointer.dimensions > 0) {
            // Handle array assignment
            size_t index = get_array_offset($1->array_info, $1->array_pointer);
            switch ($1->type) {
                case TYPE_INT:
                    if ($3->type != TYPE_INT && $3->type != TYPE_DOUBLE) {
                        yyerror_name("Cannot assign non-numeric value to integer array.", "Type");
                    }
                    switch ($3->type) {
                        case TYPE_INT:
                            $1->value.int_array[index] = $3->value.int_val;
                            printf("I_STORE %s %s[%zu]\n", $3->name, $1->name, index);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                            free(dimensions);
                            break;
                        case TYPE_DOUBLE:
                            symbol *temp_symbol = add_temp_symbol(TYPE_INT);
                            temp_symbol->value.int_val = (long long) $3->value.double_val;
                            printf("F_CAST_I %s %s\n", $3->name, temp_symbol->name);
                            printf("\t\t> auto casting double to int (%s -> %g)\n", temp_symbol->name, $3->value.double_val);

                            $1->value.int_array[index] = temp_symbol->value.int_val;
                            printf("I_STORE %s %s[%zu]\n", temp_symbol->name, $1->name, index);
                            
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                            free(dimensions);
                            break;
                    }
                    break;
                case TYPE_DOUBLE:
                    if ($3->type != TYPE_DOUBLE && $3->type != TYPE_INT) {
                        yyerror_name("Cannot assign non-numeric value to double array.", "Type");
                    }
                    switch ($3->type) {
                        case TYPE_DOUBLE:
                            $1->value.double_array[index] = $3->value.double_val;
                            printf("F_STORE %s %s[%zu]\n", $3->name, $1->name, index);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                            free(dimensions);
                            break;
                        case TYPE_INT:
                            symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                            temp_symbol->value.double_val = (double) $3->value.int_val;
                            printf("I_CAST_F %s %s\n", $3->name, temp_symbol->name);
                            printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                            $1->value.double_array[index] = temp_symbol->value.double_val;
                            printf("F_STORE %s %s[%zu]\n", temp_symbol->name, $1->name, index);
                            
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                            free(dimensions);
                            break;
                    }
                    break;
                case TYPE_STRING:
                    if ($3->type != TYPE_STRING) {
                        yyerror_name("Cannot assign non-string value to string array.", "Type");
                    }
                    $1->value.str_array[index] = (char *)realloc($1->value.str_array[index], strlen($3->value.str_val) + 1);
                    if ($1->value.str_array[index] == NULL) {
                        yyerror_name("Out of memory when realloc.", "Parsing");
                    }
                    strcpy($1->value.str_array[index], $3->value.str_val);
                    yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                    
                    dimensions = array_dimensions_to_string($1->array_pointer);
                    printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := \"%s\";)\n", $1->name, dimensions, $3->value.str_val);
                    free(dimensions);
                    break;
                default:
                    yyerror_name("Unknown data type in assignment statement.", "Parsing");
            }
        }
        else {
            // Handle normal variable assignment
            switch ($1->type) {
                case TYPE_INT:
                    if ($3->type != TYPE_INT && $3->type != TYPE_DOUBLE) {
                        yyerror_name("Cannot assign non-numeric value to integer variable.", "Type");
                    }
                    switch ($3->type) {
                        case TYPE_INT:
                            $1->value.int_val = $3->value.int_val;
                            printf("I_STORE %s %s\n", $3->name, $1->name);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3->value.int_val);
                            break;
                        case TYPE_DOUBLE:
                            symbol *temp_symbol = add_temp_symbol(TYPE_INT);
                            temp_symbol->value.int_val = (long long) $3->value.double_val;
                            printf("F_CAST_I %s %s\n", $3->name, temp_symbol->name);
                            printf("\t\t> auto casting double to int (%s -> %g)\n", temp_symbol->name, $3->value.double_val);

                            $1->value.int_val = temp_symbol->value.int_val;
                            printf("I_STORE %s %s\n", temp_symbol->name, $1->name);
                            
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3->value.double_val);
                            break;
                    }
                    break;
                case TYPE_DOUBLE:
                    if ($3->type != TYPE_DOUBLE && $3->type != TYPE_INT) {
                        yyerror_name("Cannot assign non-numeric value to double variable.", "Type");
                    }
                    switch ($3->type) {
                        case TYPE_DOUBLE:
                            $1->value.double_val = $3->value.double_val;
                            printf("F_STORE %s %s\n", $3->name, $1->name);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3->value.double_val);
                            break;
                        case TYPE_INT:
                            symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                            temp_symbol->value.double_val = (double) $3->value.int_val;
                            printf("I_CAST_F %s %s\n", $3->name, temp_symbol->name);
                            printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                            $1->value.double_val = temp_symbol->value.double_val;
                            printf("F_STORE %s %s\n", temp_symbol->name, $1->name);
                            
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3->value.int_val);
                    }
                    break;
                case TYPE_STRING:
                    if ($3->type != TYPE_STRING) {
                        yyerror_name("Cannot assign non-string value to string variable.", "Type");
                    }
                    $1->value.str_val = (char *)realloc($1->value.str_val, strlen($3->value.str_val) + 1);
                    if ($1->value.str_val == NULL) {
                        yyerror_name("Out of memory when realloc.", "Parsing");
                    }
                    strcpy($1->value.str_val, $3->value.str_val);
                    yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                    
                    printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := \"%s\";)\n", $1->name, $3->value.str_val);
                    break;
                default:
                    yyerror_name("Unknown data type in assignment statement.", "Parsing");
            }
        }
    }
    ;
expression:
    expression PLUS_MICOREX expression {
        switch ($1->type) {
            case TYPE_INT:
                switch ($3->type) {
                    case TYPE_INT:
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val + $3->value.int_val;
                        printf("I_ADD %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression PLUS expression (%lld -> %lld + %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_CAST_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);
                        
                        $$->value.double_val = temp_symbol->value.double_val + $3->value.double_val;
                        printf("F_ADD %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        
                        printf("\t> expression -> expression PLUS expression (%g -> %lld + %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot add int with non-numeric type.");
                }
                break;
            case TYPE_DOUBLE:
                switch ($3->type) {
                    case TYPE_INT:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_CAST_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val + temp_symbol->value.double_val;
                        printf("F_ADD %s %s %s\n", $1->name, temp_symbol->name, $$->name);

                        printf("\t> expression -> expression PLUS expression (%g -> %g + %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val + $3->value.double_val;
                        printf("F_ADD %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression PLUS expression (%g -> %g + %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot add double with non-numeric type.");
                }
                break;
            case TYPE_STRING:
                if ($3->type == TYPE_STRING) {
                    $$ = add_temp_symbol(TYPE_STRING);
                    $$->value.str_val = (char *)malloc(strlen($1->value.str_val) + strlen($3->value.str_val) + 1);
                    if ($$->value.str_val == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    $$->value.str_val[0] = '\0'; // Initialize to empty string
                    sprintf($$->value.str_val, "%s%s", $1->value.str_val, $3->value.str_val);
                    yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                    printf("\t> expression -> expression PLUS expression (%s -> %s + %s)\n", $$->value.str_val, $1->value.str_val, $3->value.str_val);
                } else {
                    yyerror("Cannot add string with non-string type.");
                }
                break;
            default:
                yyerror_name("Unknown data type in expression.", "Parsing");
        }
    }
    | expression MINUS_MICOREX expression {
        switch ($1->type) {
            case TYPE_INT:
                switch ($3->type) {
                    case TYPE_INT:
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val - $3->value.int_val;
                        printf("I_SUB %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%lld -> %lld - %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_CAST_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);

                        $$->value.double_val = temp_symbol->value.double_val - $3->value.double_val;
                        printf("F_SUB %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %lld - %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot subtract int with non-numeric type.");
                }
                break;
            case TYPE_DOUBLE:
                switch ($3->type) {
                    case TYPE_INT:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_CAST_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val - temp_symbol->value.double_val;
                        printf("F_SUB %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %g - %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val - $3->value.double_val;
                        printf("F_SUB %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %g - %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot subtract double with non-numeric type.");
                }
                break;
            case TYPE_STRING:
                yyerror("Cannot subtract string type.");
            default:
                yyerror_name("Unknown data type in expression.", "Parsing");
        }
    }
    | expression MULTIPLY_MICOREX expression {
        switch ($1->type) {
            case TYPE_INT:
                switch ($3->type) {
                    case TYPE_INT:
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val * $3->value.int_val;
                        printf("I_MUL %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%lld -> %lld * %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_CAST_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);

                        $$->value.double_val = temp_symbol->value.double_val * $3->value.double_val;
                        printf("F_MUL %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %lld * %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot multiply int with non-numeric type.");
                }
                break;
            case TYPE_DOUBLE:
                switch ($3->type) {
                    case TYPE_INT:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_CAST_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val * temp_symbol->value.double_val;
                        printf("F_MUL %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %g * %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val * $3->value.double_val;
                        printf("F_MUL %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %g * %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot multiply double with non-numeric type.");
                }
                break;
            case TYPE_STRING:
                yyerror("Cannot multiply string type.");
            default:
                yyerror_name("Unknown data type in expression.", "Parsing");
        }
    }
    | expression DIVISION_MICOREX expression {
        switch ($1->type) {
            case TYPE_INT:
                switch ($3->type) {
                    case TYPE_INT:
                        if ($3->value.int_val == 0) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val / $3->value.int_val;
                        printf("I_DIV %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%lld -> %lld / %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        if ($3->value.double_val == 0.0) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_CAST_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);

                        $$->value.double_val = temp_symbol->value.double_val / $3->value.double_val;
                        printf("\t> expression -> expression DIVISION expression (%g -> %lld / %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot divide int with non-numeric type.");
                }
                break;
            case TYPE_DOUBLE:
                switch ($3->type) {
                    case TYPE_INT:
                        if ($3->value.int_val == 0) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_CAST_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val / temp_symbol->value.double_val;
                        printf("\t> expression -> expression DIVISION expression (%g -> %g / %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    case TYPE_DOUBLE:
                        if ($3->value.double_val == 0.0) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val / $3->value.double_val;
                        printf("F_DIV %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%g -> %g / %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    default:
                        yyerror("Cannot divide double with non-numeric type.");
                }
                break;
            case TYPE_STRING:
                yyerror("Cannot divide string type.");
            default:
                yyerror_name("Unknown data type in expression.", "Parsing");
        }
    }
    | MINUS_MICOREX expression %prec UMINUS_MICOREX {
        switch ($2->type) {
            case TYPE_INT:
                $$ = add_temp_symbol(TYPE_INT);
                $$->value.int_val = -$2->value.int_val;
                printf("I_UMINUS %s %s\n", $2->name, $$->name);
                printf("\t> expression -> MINUS expression (expression -> %lld)\n", $$->value.int_val);
                break;
            case TYPE_DOUBLE:
                $$ = add_temp_symbol(TYPE_DOUBLE);
                $$->value.double_val = -$2->value.double_val;
                printf("F_UMINUS %s %s\n", $2->name, $$->name);
                printf("\t> expression -> MINUS expression (expression -> %g)\n", $$->value.double_val);
                break;
            case TYPE_STRING:
                yyerror("Cannot apply unary minus on string type.");
            default:
                yyerror_name("Unknown data type in expression.", "Parsing");
        }
    }
    | LEFT_PARENT_MICOREX expression RIGHT_PARENT_MICOREX {
        $$ = $2;
        switch ($2->type) {
            case TYPE_INT:
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%lld))\n", $2->value.int_val);
                break;
            case TYPE_DOUBLE:
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%g))\n", $2->value.double_val);
                break;
            case TYPE_STRING:
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%s))\n", $2->value.str_val);
                break;
            default:
                yyerror_name("Unknown data type in expression.", "Parsing");
        }
    }
    | id {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Error: Variable not declared.", "Undeclared");
        }

        if ($1->array_pointer.dimensions > 0) { // array access
            size_t index = get_array_offset($1->array_info, $1->array_pointer);
            switch ($1->type) {
                case TYPE_INT:
                    $$ = add_temp_symbol(TYPE_INT);
                    $$->value.int_val = $1->value.int_array[index];
                    printf("I_STORE %s[%zu] %s\n", $1->name, index, $$->name);
                    dimensions = array_dimensions_to_string($1->array_pointer);
                    printf("\t> expression -> id (expression -> %s%s)\n", $1->name, dimensions);
                    free(dimensions);
                    break;
                case TYPE_DOUBLE:
                    $$ = add_temp_symbol(TYPE_DOUBLE);
                    $$->value.double_val = $1->value.double_array[index];
                    printf("F_STORE %s[%zu] %s\n", $1->name, index, $$->name);
                    dimensions = array_dimensions_to_string($1->array_pointer);
                    printf("\t> expression -> id (expression -> %s%s)\n", $$->name, dimensions);
                    free(dimensions);
                    break;
                case TYPE_STRING:
                    $$ = add_temp_symbol(TYPE_STRING);
                    $$->value.str_val = strdup($1->value.str_array[index]);
                    yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                    dimensions = array_dimensions_to_string($1->array_pointer);
                    printf("\t> expression -> id (expression -> %s%s)\n", $$->name, dimensions);
                    free(dimensions);
                    break;
                default:
                    yyerror_name("Unknown data type in array access.", "Parsing");
            }
        }
        else {
            $$ = $1;
            printf("\t> expression -> id (expression -> %s)\n", $1->name);
        }
    }
    | INTEGER_LITERAL_MICOREX {
        $$ = add_temp_symbol(TYPE_INT);
        $$->value.int_val = $1;
        printf("\t> expression -> INTEGER_LITERAL (expression -> %lld)\n", $1);
    }
    | FLOAT_LITERAL_MICOREX {
        $$ = add_temp_symbol(TYPE_DOUBLE);
        $$->value.double_val = $1;
        printf("\t> expression -> FLOAT_LITERAL (expression -> %g)\n", $1);
    }
    | EXP_FLOAT_LITERAL_MICOREX {
        $$ = add_temp_symbol(TYPE_DOUBLE);
        $$->value.double_val = $1;
        printf("\t> expression -> EXP_FLOAT_LITERAL (expression -> %g)\n", $1);
    }
    // This bad body is too difficult to implement,
    // so we currently do not support string and won't generate code for it.
    | STRING_LITERAL_MICOREX {
        // TODO: implement STRING_LITERAL if have time
        $$ = add_temp_symbol(TYPE_STRING);
        $$->value.str_val = $1; // $1 is a valid string by yytext
        yyerror_warning_test_mode("STRING_LITERAL is not supported yet and won't generate code for it.", "Feature", true, true);
        printf("\t> expression -> STRING_LITERAL (expression -> %s)\n", $1);
    }
    ;

// TODO: implement read statement
read_statement:
    READ_MICOREX LEFT_PARENT_MICOREX id_list RIGHT_PARENT_MICOREX SEMICOLON_MICOREX {

    }
    ;

// TODO: implement write statement
write_statement:
    WRITE_MICOREX LEFT_PARENT_MICOREX expression_list RIGHT_PARENT_MICOREX SEMICOLON_MICOREX {
        
    }
    ;
expression_list:
    expression {
        
    }
    | expression_list COMMA_MICOREX expression {
        
    }
    ;

// TODO: implement if statement
if_statement:
    if_prefix 
    ENDIF_MICOREX {
        
    }
    | if_prefix 
    else_part 
    ENDIF_MICOREX {
        
    }
    ;
if_prefix:
    IF_MICOREX LEFT_PARENT_MICOREX condition RIGHT_PARENT_MICOREX THEN_MICOREX
        statement_list {
        
    }
    ;
condition:
    expression GREAT_MICOREX expression {
        
    }
    | expression LESS_MICOREX expression {
        
    }
    | expression GREAT_EQUAL_MICOREX expression {
        
    }
    | expression LESS_EQUAL_MICOREX expression {
        
    }
    | expression EQUAL_MICOREX expression {
        
    }
    | expression NOT_EQUAL_MICOREX expression {
        
    }
    ;
else_part:
    ELSE_MICOREX statement_list {
        printf("\t> else_part -> else statement_list (else_part -> else statement_list)\n");
    }
    ;

// TODO: implement for statement
for_statement:
    FOR_MICOREX LEFT_PARENT_MICOREX id ASSIGN_MICOREX expression direction expression RIGHT_PARENT_MICOREX 
        statement_list 
    ENDFOR_MICOREX {
        
    }
    ;
direction:
    TO_MICOREX {
        
    }
    | DOWNTO_MICOREX {
        
    }
    ;

// TODO: implement while statement
while_statement:
    WHILE_MICOREX LEFT_PARENT_MICOREX condition RIGHT_PARENT_MICOREX statement_list ENDWHILE_MICOREX {
        
    }
    ;
%%
