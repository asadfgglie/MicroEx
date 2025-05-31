%{
    #include <string.h>
    #include <unistd.h>
    #include "../microex/util.h"
    #include "../build/y.tab.h"

    symbol *symbol_table = NULL;
    symbol *temp_symbol_table = NULL;
    // subset of symbol_table for temporary variables
    // ensure that temporary variable do not conflict with user-defined variables
    // temporary variables must exist in the symbol table

    label *label_table = NULL;
    // label table for jump instructions
    // ensure that labels do not conflict with user-defined variables

    list id_list = {
        .head = NULL,
        .tail = NULL
    };

    list expression_list = {
        .head = NULL,
        .tail = NULL
    };

    char *dimensions = NULL;
    // temporary variable to store array dimensions string
    // to avoid memory leak, we will free this variable after use

    void add_node(symbol *symbol_ptr, list *list_ptr) {
        node* new_node = (node*)malloc(sizeof(node));
        new_node->symbol_ptr = symbol_ptr;
        new_node->next = NULL;

        if (list_ptr->head == NULL) {
            list_ptr->head = new_node;
            list_ptr->tail = new_node;
        } else {
            list_ptr->tail->next = new_node;
            list_ptr->tail = new_node;
        }
    }

    void free_list(list *list_ptr) {
        node* current = list_ptr->head;
        node* next_node;

        while (current != NULL) {
            next_node = current->next;
            free(current);
            current = next_node;
        }

        list_ptr->head = NULL;
        list_ptr->tail = NULL;
    }

    void add_id_node(symbol* symbol_ptr) {
        add_node(symbol_ptr, &id_list);
    }
    void free_id_list() {
        free_list(&id_list);
    }

    void add_expression_node(symbol* symbol_ptr) {
        add_node(symbol_ptr, &expression_list);
    }
    void free_expression_list() {
        free_list(&expression_list);
    }

    /**
     * Convert an integer symbol to a boolean symbol.
     * If the integer is non-zero, the boolean will be true (1), otherwise false (0).
     * This function generates the necessary assembly code for the conversion.
     * This function assumes that index isn't out of bounds.
     * @param index The index should get by `get_array_offset` function.
     */
    void itob_array(symbol *src, symbol *dest, size_t index) {
        if (src->type != TYPE_INT) {
            yyerror_name("Source symbol must be of type int.", "Parsing");
        }
        if (dest->type != TYPE_BOOL) {
            yyerror_name("Destination symbol must be of type bool.", "Parsing");
        }
        if (dest->array_pointer.dimensions == 0) {
            yyerror_name("Destination symbol must be an array.", "Parsing");
        }
        if (src == NULL || dest == NULL) {
            yyerror_name("Source or destination symbol is NULL.", "Parsing");
        }
        if (src == dest) {
            yyerror_name("Source and destination symbols cannot be the same.", "Parsing");
        }

        label *true_label = add_label();
        label *false_label = add_label();
        label *end_label = add_label();
        printf("I_CMP 0 %s\n", src->name);
        printf("JNE %s\n", true_label->name);
        printf("J %s\n", false_label->name);
        printf("%s:\n", true_label->name);
        printf("I_STORE 1 %s[%zu]\n", dest->name, index);
        printf("J %s\n", end_label->name);
        printf("%s:\n", false_label->name);
        printf("I_STORE 0 %s[%zu]\n", dest->name, index);
        printf("%s:\n", end_label->name);

        dest->value.bool_array[index] = src->value.int_val != 0; // convert int to bool
    }

    /**
     * Convert an integer symbol to a boolean symbol.
     * If the integer is non-zero, the boolean will be true (1), otherwise false (0).
     * This function generates the necessary assembly code for the conversion.
     * This function assumes that index_symbol is not static checkable.
     * @param index_symbol The index symbol should get by `get_array_offset_unstatic` function.
    */
    void itob_array_unstatic(symbol *src, symbol *dest, symbol *index_symbol) {
        if (src->type != TYPE_INT) {
            yyerror_name("Source symbol must be of type int.", "Parsing");
        }
        if (dest->type != TYPE_BOOL) {
            yyerror_name("Destination symbol must be of type bool.", "Parsing");
        }
        if (index_symbol->type != TYPE_INT) {
            yyerror_name("Index symbol must be of type int.", "Parsing");
        }
        if (dest->array_pointer.dimensions == 0) {
            yyerror_name("Destination symbol must be an array.", "Parsing");
        }
        if (src == NULL || dest == NULL) {
            yyerror_name("Source or destination symbol is NULL.", "Parsing");
        }
        if (src == dest) {
            yyerror_name("Source and destination symbols cannot be the same.", "Parsing");
        }

        label *true_label = add_label();
        label *false_label = add_label();
        label *end_label = add_label();
        printf("I_CMP 0 %s\n", src->name);
        printf("JNE %s\n", true_label->name);
        printf("J %s\n", false_label->name);
        printf("%s:\n", true_label->name);
        printf("I_STORE 1 %s[%s]\n", dest->name, index_symbol->name);
        printf("J %s\n", end_label->name);
        printf("%s:\n", false_label->name);
        printf("I_STORE 0 %s[%s]\n", dest->name, index_symbol->name);
        printf("%s:\n", end_label->name);

        // since index_symbol is not static checkable, we don't do semantic propagation here
    }

    /** 
     * Convert a double symbol to a boolean symbol.
     * If the double is non-zero, the boolean will be true (1), otherwise false (0).
     * This function generates the necessary assembly code for the conversion.
     * This function assumes that index isn't out of bounds.
     * @param index The index should get by `get_array_offset` function.
    */
    void ftob_array(symbol *src, symbol *dest, size_t index) {
        if (src->type != TYPE_DOUBLE) {
            yyerror_name("Source symbol must be of type double.", "Parsing");
        }
        if (dest->type != TYPE_BOOL) {
            yyerror_name("Destination symbol must be of type bool.", "Parsing");
        }
        if (dest->array_pointer.dimensions == 0) {
            yyerror_name("Destination symbol must be an array.", "Parsing");
        }
        if (src == NULL || dest == NULL) {
            yyerror_name("Source or destination symbol is NULL.", "Parsing");
        }
        if (src == dest) {
            yyerror_name("Source and destination symbols cannot be the same.", "Parsing");
        }

        label *true_label = add_label();
        label *false_label = add_label();
        label *end_label = add_label();
        printf("F_CMP 0.0 %s\n", src->name);
        printf("JNE %s\n", true_label->name);
        printf("J %s\n", false_label->name);
        printf("%s:\n", true_label->name);
        printf("I_STORE 1 %s[%zu]\n", dest->name, index);
        printf("J %s\n", end_label->name);
        printf("%s:\n", false_label->name);
        printf("I_STORE 0 %s[%zu]\n", dest->name, index);
        printf("%s:\n", end_label->name);

        dest->value.bool_array[index] = src->value.double_val != 0.0; // convert double to bool
    }

    /** 
     * Convert a double symbol to a boolean symbol.
     * If the double is non-zero, the boolean will be true (1), otherwise false (0).
     * This function generates the necessary assembly code for the conversion.
     * This function assumes that index_symbol is not static checkable.
     * @param index_symbol The index symbol should get by `get_array_offset_unstatic` function.
    */
    void ftob_array_unstatic(symbol *src, symbol *dest, symbol *index_symbol) {
        if (src->type != TYPE_DOUBLE) {
            yyerror_name("Source symbol must be of type double.", "Parsing");
        }
        if (dest->type != TYPE_BOOL) {
            yyerror_name("Destination symbol must be of type bool.", "Parsing");
        }
        if (index_symbol->type != TYPE_INT) {
            yyerror_name("Index symbol must be of type int.", "Parsing");
        }
        if (dest->array_pointer.dimensions == 0) {
            yyerror_name("Destination symbol must be an array.", "Parsing");
        }
        if (src == NULL || dest == NULL) {
            yyerror_name("Source or destination symbol is NULL.", "Parsing");
        }
        if (src == dest) {
            yyerror_name("Source and destination symbols cannot be the same.", "Parsing");
        }

        label *true_label = add_label();
        label *false_label = add_label();
        label *end_label = add_label();
        printf("F_CMP 0.0 %s\n", src->name);
        printf("JNE %s\n", true_label->name);
        printf("J %s\n", false_label->name);
        printf("%s:\n", true_label->name);
        printf("I_STORE 1 %s[%s]\n", dest->name, index_symbol->name);
        printf("J %s\n", end_label->name);
        printf("%s:\n", false_label->name);
        printf("I_STORE 0 %s[%s]\n", dest->name, index_symbol->name);
        printf("%s:\n", end_label->name);

        // since index_symbol is not static checkable, we don't do semantic propagation here
    }

    void int_to_bool(symbol *src, symbol *dest) {
        if (src->type != TYPE_INT) {
            yyerror_name("Source symbol must be of type int.", "Parsing");
        }
        if (dest->type != TYPE_BOOL) {
            yyerror_name("Destination symbol must be of type bool.", "Parsing");
        }
        if (src == NULL || dest == NULL) {
            yyerror_name("Source or destination symbol is NULL.", "Parsing");
        }
        if (src == dest) {
            yyerror_name("Source and destination symbols cannot be the same.", "Parsing");
        }

        label *true_label = add_label();
        label *false_label = add_label();
        label *end_label = add_label();
        printf("I_CMP 0 %s\n", src->name);
        printf("JNE %s\n", true_label->name);
        printf("J %s\n", false_label->name);
        printf("%s:\n", true_label->name);
        printf("I_STORE 1 %s\n", dest->name);
        printf("J %s\n", end_label->name);
        printf("%s:\n", false_label->name);
        printf("I_STORE 0 %s\n", dest->name);
        printf("%s:\n", end_label->name);

        dest->value.bool_val = src->value.int_val != 0; // convert int to bool
    }

    void double_to_bool(symbol *src, symbol *dest) {
        if (src->type != TYPE_DOUBLE) {
            yyerror_name("Source symbol must be of type double.", "Parsing");
        }
        if (dest->type != TYPE_BOOL) {
            yyerror_name("Destination symbol must be of type bool.", "Parsing");
        }
        if (src == NULL || dest == NULL) {
            yyerror_name("Source or destination symbol is NULL.", "Parsing");
        }
        if (src == dest) {
            yyerror_name("Source and destination symbols cannot be the same.", "Parsing");
        }

        label *true_label = add_label();
        label *false_label = add_label();
        label *end_label = add_label();
        printf("F_CMP 0.0 %s\n", src->name);
        printf("JNE %s\n", true_label->name);
        printf("J %s\n", false_label->name);
        printf("%s:\n", true_label->name);
        printf("I_STORE 1 %s\n", dest->name);
        printf("J %s\n", end_label->name);
        printf("%s:\n", false_label->name);
        printf("I_STORE 0 %s\n", dest->name);
        printf("%s:\n", end_label->name);

        dest->value.bool_val = src->value.double_val != 0.0; // convert double to bool
    }

    /**
     * Process the condition for `expr1 condition expr2`.
     * This function generates the necessary assembly code for the condition.
     * @param condition The condition to process, define by condition token id e.g. EQUAL_MICROEX, NOT_EQUAL_MICROEX, etc.
     * @param expr1 The first expression to evaluate.
     * @param expr2 The second expression to evaluate.
     * @return A symbol representing the result of the condition. Propagates static checkability from expr1 and expr2.
     */
    condition_info condition_proccess(symbol *expr1, size_t condition, symbol *expr2) {
        if (expr1 == NULL || expr2 == NULL) {
            yyerror_name("expr1 or expr2 symbol is NULL.", "Parsing");
        }
        if (expr1 == expr2) {
            yyerror_name("expr1 and expr2 symbols cannot be the same.", "Parsing");
        }
        bool is_code_generation = true; // flag to indicate if code generation is needed

        symbol *result = add_temp_symbol(TYPE_BOOL);
        result->is_static_checkable = expr1->is_static_checkable && expr2->is_static_checkable; // propagate static checkability

        label *true_label, *false_label, *end_label;
        if (condition != AND_MICROEX && condition != OR_MICROEX && condition != NOT_MICROEX) {
            // for AND, OR, NOT conditions, we don't need labels
            true_label = add_label();
            false_label = add_label();
            end_label = add_label();
        }

        switch (condition) {
            case NOT_EQUAL_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.int_val != expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.int_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val != expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.int_val != expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare int with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare int with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.int_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val != temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->value.double_val != expr2->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.bool_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val != temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare double with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare double with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.bool_val != expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.double_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val != expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val != expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare bool with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare bool with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->value.str_val, expr2->value.str_val) != 0);
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            is_code_generation = false; // no code generation for string comparison
                        }
                        else {
                            yyerror_name("Cannot compare string with other types.", "Type");
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot compare program name with other types.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case EQUAL_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.int_val == expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.int_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val == expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.int_val == expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare int with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare int with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.int_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val == temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->value.double_val == expr2->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.bool_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val == temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare double with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare double with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.bool_val == expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.double_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val == expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val == expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare bool with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare bool with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->value.str_val, expr2->value.str_val) == 0);
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            is_code_generation = false; // no code generation for string comparison
                        }
                        else {
                            yyerror_name("Cannot compare string with other types.", "Type");
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot compare program name with other types.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case GREAT_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.int_val > expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.int_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val > expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.int_val > expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare int with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare int with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.int_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val > temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->value.double_val > expr2->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.bool_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val > temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare double with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare double with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.bool_val > expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.bool_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val > expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val > expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare bool with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare bool with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_name("Cannot compare string with other types.", "Type");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot compare program name with other types.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case LESS_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.int_val < expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.int_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val < expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.int_val < expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare int with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare int with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.int_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val < temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->value.double_val < expr2->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.bool_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val < temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare double with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare double with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot compare program name with other types.", "Type");
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.bool_val < expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.bool_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val < expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val < expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare bool with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare bool with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->value.str_val, expr2->value.str_val) < 0);
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            is_code_generation = false; // no code generation for string comparison
                        }
                        else {
                            yyerror_name("Cannot compare string with other types.", "Type");
                        }
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case GREAT_EQUAL_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.int_val >= expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.int_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val >= expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.int_val >= expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare int with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare int with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.int_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val >= temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->value.double_val >= expr2->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.bool_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val >= temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare double with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare double with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.bool_val >= expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.bool_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val >= expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val >= expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare bool with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare bool with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->value.str_val, expr2->value.str_val) >= 0);
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            is_code_generation = false; // no code generation for string comparison
                        }
                        else {
                            yyerror_name("Cannot compare string with other types.", "Type");
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot compare program name with other types.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case LESS_EQUAL_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.int_val <= expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.int_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val <= expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.int_val <= expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare int with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare int with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.int_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val <= temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->value.double_val <= expr2->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->value.bool_val;
                                printf("I_TO_F %s %s\n", expr2->name, temp_symbol->name);

                                result->value.bool_val = (expr1->value.double_val <= temp_symbol->value.double_val);
                                printf("F_CMP %s %s\n", expr1->name, temp_symbol->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare double with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare double with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->value.bool_val <= expr2->value.int_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->value.bool_val;
                                printf("I_TO_F %s %s\n", expr1->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val <= expr2->value.double_val);
                                printf("F_CMP %s %s\n", temp_symbol->name, expr2->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val <= expr2->value.bool_val);
                                printf("I_CMP %s %s\n", expr1->name, expr2->name);
                                printf("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot compare bool with string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot compare bool with program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->value.str_val, expr2->value.str_val) <= 0);
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            is_code_generation = false; // no code generation for string comparison
                        }
                        else {
                            yyerror_name("Cannot compare string with other types.", "Type");
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot compare program name with other types.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case AND_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1, temp_symbol1);
                                int_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                printf("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1, temp_symbol1);
                                double_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                printf("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val && expr2->value.bool_val);
                                printf("AND %s %s %s\n", temp_symbol->name, expr2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot apply AND operation on string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot apply AND operation on program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1, temp_symbol1);
                                int_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                printf("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1, temp_symbol1);
                                double_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                printf("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val && expr2->value.bool_val);
                                printf("AND %s %s %s\n", temp_symbol->name, expr2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot apply AND operation on string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot apply AND operation on program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr2, temp_symbol);
                                result->value.bool_val = (expr1->value.bool_val && temp_symbol->value.bool_val);
                                printf("AND %s %s %s\n", expr1->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr2, temp_symbol);
                                result->value.bool_val = (expr1->value.bool_val && temp_symbol->value.bool_val);
                                printf("AND %s %s %s\n", expr1->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val && expr2->value.bool_val);
                                printf("AND %s %s %s\n", expr1->name, expr2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot apply AND operation on string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot apply AND operation on program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_name("Cannot apply AND operation on string.", "Type");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot apply AND operation on program name.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case OR_MICROEX: {
                switch (expr1->type) {
                    case TYPE_INT: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1, temp_symbol1);
                                int_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                printf("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1, temp_symbol1);
                                double_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                printf("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val || expr2->value.bool_val);
                                printf("OR %s %s %s\n", temp_symbol->name, expr2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot apply OR operation on string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot apply OR operation on program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1, temp_symbol1);
                                int_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                printf("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1, temp_symbol1);
                                double_to_bool(expr2, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                printf("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val || expr2->value.bool_val);
                                printf("OR %s %s %s\n", temp_symbol->name, expr2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot apply OR operation on string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot apply OR operation on program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr2, temp_symbol);
                                result->value.bool_val = (expr1->value.bool_val || temp_symbol->value.bool_val);
                                printf("OR %s %s %s\n", expr1->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr2, temp_symbol);
                                result->value.bool_val = (expr1->value.bool_val || temp_symbol->value.bool_val);
                                printf("OR %s %s %s\n", expr1->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->value.bool_val || expr2->value.bool_val);
                                printf("OR %s %s %s\n", expr1->name, expr2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot apply OR operation on string.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot apply OR operation on program name.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_name("Cannot apply OR operation on string.", "Type");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot apply OR operation on program name.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_proccess`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            default: {
                yyerror_name("Unknown condition in `condition_proccess`.", "Parsing");
                break;
            }
        }

        if (is_code_generation) {
            printf("J %s\n", false_label->name);
            printf("%s:\n", true_label->name);
            printf("I_STORE 1 %s\n", result->name);
            printf("J %s\n", end_label->name);
            printf("%s:\n", false_label->name);
            printf("I_STORE 0 %s\n", result->name);
            printf("%s:\n", end_label->name);
        }

        condition_info info = {
            .result_ptr = result,
            .true_label_ptr = true_label,
            .false_label_ptr = false_label,
            .end_label_ptr = end_label
        };

        return info;
    }
%}

%union {
    long long int_val;
    char *str_val;
    double double_val;
    bool bool_val;
    symbol *symbol_ptr;
    data_type type;
    array_type array_info;
    direction direction;
    label *label_ptr;
    for_info for_info;
    while_info while_info;
}

%token PROGRAM_MICROEX
%token BEGIN_MICROEX
%token END_MICROEX
%token READ_MICROEX
%token WRITE_MICROEX
%token <symbol_ptr> ID_MICROEX
%token <int_val> INTEGER_LITERAL_MICROEX
%token <double_val> FLOAT_LITERAL_MICROEX
%token <double_val> EXP_FLOAT_LITERAL_MICROEX
%token <str_val> STRING_LITERAL_MICROEX
%token <bool_val> TRUE_LITERAL_MICROEX
%token <bool_val> FALSE_LITERAL_MICROEX
%token LEFT_PARENT_MICROEX
%token RIGHT_PARENT_MICROEX
%token LEFT_BRACKET_MICROEX
%token RIGHT_BRACKET_MICROEX
%token SEMICOLON_MICROEX
%token COMMA_MICROEX
%token ASSIGN_MICROEX
%token PLUS_MICROEX
%token MINUS_MICROEX
%token MULTIPLY_MICROEX
%token DIVISION_MICROEX
%token NOT_EQUAL_MICROEX
%token EQUAL_MICROEX
%token GREAT_MICROEX
%token LESS_MICROEX
%token GREAT_EQUAL_MICROEX
%token LESS_EQUAL_MICROEX
%token AND_MICROEX
%token OR_MICROEX
%token NOT_MICROEX
%token IF_MICROEX
%token THEN_MICROEX
%token ELSE_MICROEX
%token ENDIF_MICROEX
%token FOR_MICROEX
%token ENDFOR_MICROEX
%token WHILE_MICROEX
%token ENDWHILE_MICROEX
%token DECLARE_MICROEX
%token AS_MICROEX
%token <type> INTEGER_MICROEX
%token <type> REAL_MICROEX
%token <type> STRING_MICROEX
%token <type> BOOL_MICROEX
%token TO_MICROEX
%token DOWNTO_MICROEX

%type <type> type
%type <symbol_ptr> program_title
%type <symbol_ptr> id_list
%type <symbol_ptr> id
%type <array_info> array_dimension
%type <array_info> array_dimension_list
%type <symbol_ptr> expression
// ensure expression isn't array symbol (already handled in `expression: id` rule)
%type <symbol_ptr> expression_list
%type <direction> direction
%type <label_ptr> if_prefix
%type <for_info> for_prefix
%type <while_info> while_prefix

%left OR_MICROEX
%left AND_MICROEX
%left NOT_EQUAL_MICROEX EQUAL_MICROEX
%left GREAT_MICROEX LESS_MICROEX GREAT_EQUAL_MICROEX LESS_EQUAL_MICROEX
%left PLUS_MICROEX MINUS_MICROEX
%left MULTIPLY_MICROEX DIVISION_MICROEX
%nonassoc UMINUS_MICROEX NOT_MICROEX

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
    PROGRAM_MICROEX ID_MICROEX {
        $2->type = TYPE_PROGRAM_NAME;
        $$ = $2;
        printf("START %s\n", $2->name);
        printf("\t> program_title -> program id (program_title -> program %s)\n", $2->name);
        printf("\t\t> Program start with name: `%s`\n", $2->name);
    }
    ;
program_body:
    BEGIN_MICROEX
        statement_list
    END_MICROEX {
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
    DECLARE_MICROEX id_list AS_MICROEX type SEMICOLON_MICROEX {
        node *current = id_list.head;
        size_t ids_name_len = 1; // start with 1 for null terminator
        while (current != NULL) {
            if (current->symbol_ptr->type != TYPE_UNKNOWN) {
                yyerror_name("Variable already declared.", "Redeclaration");
            }
            current->symbol_ptr->type = $4;
            if (current->symbol_ptr->array_pointer.dimensions > 0) {
                if (current->symbol_ptr->array_pointer.is_static_checkable) {
                    for (size_t i = 0; i < current->symbol_ptr->array_pointer.dimensions; i++) {
                        if (current->symbol_ptr->array_pointer.dimension_sizes[i] <= 0) {
                            yyerror_name("Array dimension must be greater than 0 when declaring.", "Index");
                        }
                    }
                }
                else {
                    yyerror_name("Array dimension must be static checkable when declaring.", "Compile");
                }
                char *array_dimensions = array_range_to_string(current->symbol_ptr->array_pointer);
                char *type_str = data_array_type_to_string($4);
                printf("DECLARE %s %s %s\n", current->symbol_ptr->name, type_str, array_dimensions);
                free(type_str);
                free(array_dimensions);
                current->symbol_ptr->array_info = current->symbol_ptr->array_pointer;
                array_type empty_pointer = {
                    .dimensions = 0,
                    .dimension_sizes = NULL,
                    .is_static_checkable = true
                };
                current->symbol_ptr->array_pointer = empty_pointer;

                size_t array_size = array_range(current->symbol_ptr->array_info);
                switch ($4) {
                    case TYPE_INT: {
                        current->symbol_ptr->value.int_array = (long long *)calloc(array_size, sizeof(long long));
                        if (current->symbol_ptr->value.int_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_size; i++) {
                            printf("I_STORE 0 %s[%zu]\n", current->symbol_ptr->name, i);
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        current->symbol_ptr->value.double_array = (double *)calloc(array_size, sizeof(double));
                        if (current->symbol_ptr->value.double_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_size; i++) {
                            printf("F_STORE 0.0 %s[%zu]\n", current->symbol_ptr->name, i);
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        current->symbol_ptr->value.str_array = (char **)calloc(array_size, sizeof(char *));
                        if (current->symbol_ptr->value.str_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_size; i++) {
                            current->symbol_ptr->value.str_array[i] = (char *)malloc(sizeof(char) * 1); // Allocate memory for empty string
                            if (current->symbol_ptr->value.str_array[i] == NULL) {
                                yyerror_name("Out of memory when malloc.", "Parsing");
                            }
                            current->symbol_ptr->value.str_array[i][0] = '\0'; // Initialize to empty string
                        }
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    }
                    case TYPE_BOOL: {
                        current->symbol_ptr->value.bool_array = (bool *)calloc(array_size, sizeof(bool));
                        if (current->symbol_ptr->value.bool_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_size; i++) {
                            printf("I_STORE 0 %s[%zu]\n", current->symbol_ptr->name, i);
                            // boolean actually stored as int, so we use I_STORE
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror("Cannot declare program name as variable.");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in declare statement.", "Parsing");
                        break;
                    }
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
                    case TYPE_INT: {
                        current->symbol_ptr->value.int_val = 0;
                        printf("I_STORE 0 %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        current->symbol_ptr->value.double_val = 0.0;
                        printf("F_STORE 0.0 %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_STRING: {
                        current->symbol_ptr->value.str_val = (char *)malloc(sizeof(char) * 1); // Allocate memory for empty string
                        if (current->symbol_ptr->value.str_val == NULL) {
                            yyerror_name("Out of memory when malloc.", "Parsing");
                        }
                        current->symbol_ptr->value.str_val[0] = '\0'; // Initialize to empty string
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    }
                    case TYPE_BOOL: {
                        current->symbol_ptr->value.bool_val = false;
                        printf("I_STORE 0 %s\n", current->symbol_ptr->name);
                        // boolean actually stored as int, so we use I_STORE
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror("Cannot declare program name as variable.");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in declare statement.", "Parsing");
                        break;
                    }
                }
            }
            ids_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                ids_name_len += 2; // for ", "
            }
            current = current->next;
        }

        reallocable_char ids_name = {
            .str = (char *)malloc(sizeof(char) * ids_name_len), 
            .capacity = ids_name_len
        };
        if (ids_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        ids_name.str[0] = '\0';
        current = id_list.head;
        while (current != NULL) {
            if (ids_name.str[0] != '\0') {
                strcat(ids_name.str, ", ");
            }
            strcat(ids_name.str, current->symbol_ptr->name);
            if (current->symbol_ptr->array_info.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->symbol_ptr->array_info);
                if (realloc_char(&ids_name, ids_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(ids_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        char *type_str = data_type_to_string($4);
        printf("\t> declare_statement -> declare id_list as type semicolon (declare_statement -> declare %s as %s;)\n", ids_name.str, type_str);
        free(type_str);
        free(ids_name.str);
        
        free_id_list();
    }
    ;
id_list:
    id {
        $$ = $1;
        add_id_node($1);
        printf("\t> id_list -> id (id_list -> %s)\n", $1->name);
    }
    | id_list COMMA_MICROEX id {
        $$ = $1;
        add_id_node($3);

        size_t ids_name_len = 1; // start with 1 for null terminator
        node *current = id_list.head;
        while (current != NULL) {
            ids_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                ids_name_len += 2; // for ", "
            }
            current = current->next;
        }
        
        reallocable_char ids_name = {
            .str = (char *)malloc(sizeof(char) * ids_name_len), 
            .capacity = ids_name_len
        };
        if (ids_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        ids_name.str[0] = '\0';
        current = id_list.head;
        while (current != NULL) {
            if (ids_name.str[0] != '\0') {
                strcat(ids_name.str, ", ");
            }
            strcat(ids_name.str, current->symbol_ptr->name);
            if (current->symbol_ptr->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->symbol_ptr->array_pointer);
                if (realloc_char(&ids_name, ids_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(ids_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        printf("\t> id_list -> id_list comma id (id_list -> %s)\n", ids_name.str);
        free(ids_name.str);
    }
    ;
id:
    ID_MICROEX {
        $$ = $1;
        printf("\t> id -> ID (id -> %s)\n", $1->name);
    }
    | ID_MICROEX array_dimension_list {
        $$ = $1;
        $$->array_pointer = $2;
        dimensions = array_dimensions_to_string($2);
        printf("\t> id -> ID array_dimension_list (id -> %s%s)\n", $1->name, dimensions);
        free(dimensions);

        $$->is_static_checkable = $2.is_static_checkable; // propagate static checkability
    }
    ;
array_dimension:
    LEFT_BRACKET_MICROEX expression RIGHT_BRACKET_MICROEX {
        if ($2->type != TYPE_INT && $2->type != TYPE_BOOL) {
            yyerror_name("Array dimension must be integer greater than 0.", "Index");
        }
        symbol *temp_symbol = $2;
        if ($2->type == TYPE_BOOL) {
            // add temporary symbol to make sure array index semantic record always has type int
            temp_symbol = add_temp_symbol(TYPE_INT);
            temp_symbol->value.int_val = $2->value.bool_val ? 1 : 0; // convert bool to int
            temp_symbol->is_static_checkable = $2->is_static_checkable; // propagate static checkability
            printf("I_STORE %s %s\n", $2->name, temp_symbol->name);
        }
        $$.dimensions = 1;
        $$.dimension_sizes = (size_t *)malloc(sizeof(size_t) * $$.dimensions);
        if ($$.dimension_sizes == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        $$.dimension_sizes_symbol = (symbol **)malloc(sizeof(symbol *) * $$.dimensions);
        if ($$.dimension_sizes_symbol == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }

        if (temp_symbol->is_static_checkable && temp_symbol->value.int_val < 0) {
            yyerror_name("Array dimension must be greater equal than 0.", "Index");
        }
        if (temp_symbol->is_static_checkable) {
            $$.dimension_sizes[$$.dimensions - 1] = temp_symbol->value.int_val;
            $$.dimension_sizes_symbol[$$.dimensions - 1] = NULL; // static checkable dimension, no symbol needed
            printf("\t> array_dimension -> LEFT_BRACKET expression RIGHT_BRACKET (array_dimension -> [%lld])\n", temp_symbol->value.int_val);
        }
        else {
            $$.dimension_sizes[$$.dimensions - 1] = 0; // non-static checkable dimension, set to 0
            $$.dimension_sizes_symbol[$$.dimensions - 1] = temp_symbol; // store the symbol for non-static checkable dimension
            printf("\t> array_dimension -> LEFT_BRACKET expression RIGHT_BRACKET (array_dimension -> [%s])\n", temp_symbol->name);
        }

        $$.is_static_checkable = temp_symbol->is_static_checkable; // propagate static checkability
    }
    ;
array_dimension_list:
    array_dimension {
        $$ = $1;

        if ($1.is_static_checkable) {
            printf("\t> array_dimension_list -> array_dimension (array_dimension_list -> [%zu])\n", $1.dimension_sizes[0]);
        }
        else {
            printf("\t> array_dimension_list -> array_dimension (array_dimension_list -> [%s])\n", $1.dimension_sizes_symbol[0]->name);
        }
        // propagate static checkability inherited from $1, so we don't need to set it again
    }
    | array_dimension_list array_dimension {
        $$.dimensions = $1.dimensions + 1;
        $$.dimension_sizes = (size_t *)realloc($$.dimension_sizes, sizeof(size_t) * $$.dimensions);
        if ($$.dimension_sizes == NULL) {
            yyerror_name("Out of memory when realloc.", "Parsing");
        }
        $$.dimension_sizes_symbol = (symbol **)realloc($$.dimension_sizes_symbol, sizeof(symbol *) * $$.dimensions);
        if ($$.dimension_sizes_symbol == NULL) {
            yyerror_name("Out of memory when realloc.", "Parsing");
        }

        $$.dimension_sizes[$$.dimensions - 1] = $2.dimension_sizes[0];
        $$.dimension_sizes_symbol[$$.dimensions - 1] = $2.dimension_sizes_symbol[0];

        dimensions = array_dimensions_to_string($$);
        printf("\t> array_dimension_list -> array_dimension_list array_dimension (array_dimension_list -> %s)\n", dimensions);
        free(dimensions);

        $$.is_static_checkable = $1.is_static_checkable && $2.is_static_checkable; // propagate static checkability
    }
    ;

type:
    INTEGER_MICROEX {
        $$ = $1;
        printf("\t> type -> INTEGER\n");
    }
    | REAL_MICROEX {
        $$ = $1;
        printf("\t> type -> REAL\n");
    }
    | BOOL_MICROEX {
        $$ = $1;
        printf("\t> type -> BOOL\n");
    }
    // This bad body is too difficult to implement,
    // so we currently do not support string and won't generate code for it.
    | STRING_MICROEX {
        // TODO: implement STRING type if have time
        $$ = $1;
        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
        printf("\t> type -> STRING\n");
    }
    ;
// assignment statement
assignment_statement:
    id ASSIGN_MICROEX expression SEMICOLON_MICROEX {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Variable not declared.", "Undeclared");
        }
        if ($1->array_pointer.dimensions > 0) { // Handle array assignment
            if ($1->array_pointer.is_static_checkable) {
                size_t index = get_array_offset($1->array_info, $1->array_pointer);
                switch ($1->type) {
                    case TYPE_INT: {
                        if ($3->type != TYPE_INT && $3->type != TYPE_DOUBLE && $3->type != TYPE_BOOL) {
                            yyerror_name("Cannot assign non-numeric value to integer array.", "Type");
                        }
                        switch ($3->type) {
                            case TYPE_INT: {
                                $1->value.int_array[index] = $3->value.int_val;
                                printf("I_STORE %s %s[%zu]\n", $3->name, $1->name, index);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                $1->value.int_array[index] = (long long) $3->value.double_val;
                                printf("F_TO_I %s %s[%zu]\n", $3->name, $1->name, index);
                                
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_BOOL: {
                                $1->value.int_array[index] = $3->value.bool_val ? 1 : 0;
                                printf("I_STORE %s %s[%zu]\n", $3->name, $1->name, index);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3->value.bool_val ? "true" : "false");
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot assign program name to integer array.", "Type");
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot assign string to integer array.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in assignment statement.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        if ($3->type != TYPE_DOUBLE && $3->type != TYPE_INT && $3->type != TYPE_BOOL) {
                            yyerror_name("Cannot assign non-numeric value to double array.", "Type");
                        }
                        switch ($3->type) {
                            case TYPE_DOUBLE: {
                                $1->value.double_array[index] = $3->value.double_val;
                                printf("F_STORE %s %s[%zu]\n", $3->name, $1->name, index);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_INT: {
                                $1->value.double_array[index] = (double) $3->value.int_val;
                                printf("I_TO_F %s %s[%zu]\n", $3->name, $1->name, index);
                                
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_BOOL: {
                                $1->value.double_array[index] = $3->value.bool_val ? 1.0 : 0.0;
                                printf("I_TO_F %s %s[%zu]\n", $3->name, $1->name, index);

                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3->value.bool_val ? "true" : "false");
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot assign program name to double array.", "Type");
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot assign string to double array.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in assignment statement.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
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
                        if (!$3->is_static_checkable) {
                            printf("\t\t> %s = \"%s\" is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.str_val);
                        }
                        free(dimensions);
                        break;
                    }
                    case TYPE_BOOL: {
                        switch ($3->type) {
                            case TYPE_BOOL: {
                                $1->value.bool_array[index] = $3->value.bool_val;
                                printf("I_STORE %s %s[%zu]\n", $3->name, $1->name, index);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3->value.bool_val ? "true" : "false");
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_INT: {
                                itob_array($3, $1, index);
                                
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                ftob_array($3, $1, index);

                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot assign program name to boolean array.", "Type");
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot assign string to boolean array.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in assignment statement.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot assign program name to array.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in assignment statement.", "Parsing");
                        break;
                    }
                }
            }
            else { // Handle unstatic array assignment
                symbol *offset = get_array_offset_unstatic($1->array_info, $1->array_pointer);
                switch ($1->type) {
                    case TYPE_INT: {
                        if ($3->type != TYPE_INT && $3->type != TYPE_DOUBLE && $3->type != TYPE_BOOL) {
                            yyerror_name("Cannot assign non-numeric value to integer array.", "Type");
                        }
                        switch ($3->type) {
                            case TYPE_INT: {
                                // we won't do any semantic propogation here, since we are not sure about the real array offset
                                printf("I_STORE %s %s[%s]\n", $3->name, $1->name, offset->name);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                // we won't do any semantic propogation here, since we are not sure about the real array offset
                                printf("F_TO_I %s %s[%s]\n", $3->name, $1->name, offset->name);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_BOOL: {
                                // we won't do any semantic propogation here, since we are not sure about the real array offset
                                printf("I_STORE %s %s[%s]\n", $3->name, $1->name, offset->name);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3->value.bool_val ? "true" : "false");
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot assign string to integer array.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot assign program name to integer array.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in assignment statement.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        if ($3->type != TYPE_DOUBLE && $3->type != TYPE_INT && $3->type != TYPE_BOOL) {
                            yyerror_name("Cannot assign non-numeric value to double array.", "Type");
                        }
                        switch ($3->type) {
                            case TYPE_DOUBLE: {
                                // we won't do any semantic propogation here, since we are not sure about the real array offset
                                printf("F_STORE %s %s[%s]\n", $3->name, $1->name, offset->name);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_INT: {
                                // we won't do any semantic propogation here, since we are not sure about the real array offset
                                printf("I_TO_F %s %s[%s]\n", $3->name, $1->name, offset->name);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_BOOL: {
                                // we won't do any semantic propogation here, since we are not sure about the real array offset
                                printf("I_TO_F %s %s[%s]\n", $3->name, $1->name, offset->name);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3->value.bool_val ? "true" : "false");
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot assign string to double array.", "Type");
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot assign program name to double array.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in assignment statement.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if ($3->type != TYPE_STRING) {
                            yyerror_name("Cannot assign non-string value to string array.", "Type");
                        }
                        // we won't do any semantic propogation here, since we are not sure about the real array offset
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := \"%s\";)\n", $1->name, dimensions, $3->value.str_val);
                        if (!$3->is_static_checkable) {
                            printf("\t\t> %s = \"%s\" is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.str_val);
                        }
                        free(dimensions);
                        break;
                    }
                    case TYPE_BOOL: {
                        if ($3->type != TYPE_BOOL && $3->type != TYPE_INT && $3->type != TYPE_DOUBLE) {
                            yyerror_name("Cannot assign non-boolean value to boolean array.", "Type");
                        }
                        switch ($3->type) {
                            case TYPE_BOOL: {
                                // we won't do any semantic propogation here, since we are not sure about the real array offset
                                printf("I_STORE %s %s[%s]\n", $3->name, $1->name, offset->name);
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3->value.bool_val ? "true" : "false");
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_INT: {
                                itob_array_unstatic($3, $1, offset);

                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3->value.int_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                ftob_array_unstatic($3, $1, offset);
                                
                                dimensions = array_dimensions_to_string($1->array_pointer);
                                printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3->value.double_val);
                                if (!$3->is_static_checkable) {
                                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                                }
                                free(dimensions);
                                break;
                            }
                            case TYPE_PROGRAM_NAME: {
                                yyerror_name("Cannot assign program name to boolean array.", "Type");
                                break;
                            }
                            case TYPE_STRING: {
                                yyerror_name("Cannot assign string to boolean array.", "Type");
                                break;
                            }
                            default: {
                                yyerror_name("Unknown data type in assignment statement.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot assign program name to array.", "Type");
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in assignment statement.", "Parsing");
                        break;
                    }
                }
            }
        }
        else { // Handle normal variable assignment
            switch ($1->type) {
                case TYPE_INT: {
                    if ($3->type != TYPE_INT && $3->type != TYPE_DOUBLE && $3->type != TYPE_BOOL) {
                        yyerror_name("Cannot assign non-numeric value to integer variable.", "Type");
                    }
                    switch ($3->type) {
                        case TYPE_INT: {
                            $1->value.int_val = $3->value.int_val;
                            printf("I_STORE %s %s\n", $3->name, $1->name);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3->value.int_val);
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                            }
                            break;
                        }
                        case TYPE_DOUBLE: {
                            $1->value.int_val = (long long) $3->value.double_val;
                            printf("F_TO_I %s %s\n", $3->name, $1->name);
                            
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3->value.double_val);
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                            }
                            break;
                        }
                        case TYPE_BOOL: {
                            $1->value.int_val = $3->value.bool_val ? 1 : 0; // convert bool to int
                            printf("I_STORE %s %s\n", $3->name, $1->name);

                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %s;)\n", $1->name, $3->value.bool_val ? "true" : "false");
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                            }
                            break;
                        }
                        case TYPE_PROGRAM_NAME: {
                            yyerror_name("Cannot assign program name to integer variable.", "Type");
                            break;
                        }
                        case TYPE_STRING: {
                            yyerror_name("Cannot assign string to integer variable.", "Type");
                            break;
                        }
                        default: {
                            yyerror_name("Unknown data type in assignment statement.", "Parsing");
                            break;
                        }
                    }
                    break;
                }
                case TYPE_DOUBLE: {
                    if ($3->type != TYPE_DOUBLE && $3->type != TYPE_INT && $3->type != TYPE_BOOL) {
                        yyerror_name("Cannot assign non-numeric value to double variable.", "Type");
                    }
                    switch ($3->type) {
                        case TYPE_DOUBLE: {
                            $1->value.double_val = $3->value.double_val;
                            printf("F_STORE %s %s\n", $3->name, $1->name);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3->value.double_val);
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                            }
                            break;
                        }
                        case TYPE_INT: {
                            $1->value.double_val = (double) $3->value.int_val;
                            printf("I_TO_F %s %s\n", $3->name, $1->name);
                            
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3->value.int_val);
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                            }
                            break;
                        }
                        case TYPE_BOOL: {
                            $1->value.double_val = $3->value.bool_val ? 1.0 : 0.0;
                            printf("I_TO_F %s %s\n", $3->name, $1->name);
                            
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %s;)\n", $1->name, $3->value.bool_val ? "true" : "false");
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                            }
                            break;
                        }
                        case TYPE_PROGRAM_NAME: {
                            yyerror_name("Cannot assign program name to double variable.", "Type");
                            break;
                        }
                        case TYPE_STRING: {
                            yyerror_name("Cannot assign string to double variable.", "Type");
                            break;
                        }
                        default: {
                            yyerror_name("Unknown data type in assignment statement.", "Parsing");
                            break;
                        }
                    }
                    break;
                }
                case TYPE_STRING: {
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
                    if (!$3->is_static_checkable) {
                        printf("\t\t> %s = \"%s\" is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.str_val);
                    }
                    break;
                }
                case TYPE_BOOL: {
                    if ($3->type != TYPE_BOOL && $3->type != TYPE_INT && $3->type != TYPE_DOUBLE) {
                        yyerror_name("Cannot assign non-boolean value to boolean variable.", "Type");
                    }
                    switch ($3->type) {
                        case TYPE_BOOL: {
                            $1->value.bool_val = $3->value.bool_val;
                            printf("I_STORE %s %s\n", $3->name, $1->name);
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %s;)\n", $1->name, $3->value.bool_val ? "true" : "false");
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                            }
                            break;
                        }
                        case TYPE_INT: {
                            int_to_bool($3, $1);
                            
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3->value.int_val);
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                            }
                            break;
                        }
                        case TYPE_DOUBLE: {
                            double_to_bool($3, $1);
                            
                            printf("\t> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3->value.double_val);
                            if (!$3->is_static_checkable) {
                                printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                            }
                            break;
                        }
                        case TYPE_PROGRAM_NAME: {
                            yyerror_name("Cannot assign program name to boolean variable.", "Type");
                            break;
                        }
                        case TYPE_STRING: {
                            yyerror_name("Cannot assign string to boolean variable.", "Type");
                            break;
                        }
                        default: {
                            yyerror_name("Unknown data type in assignment statement.", "Parsing");
                            break;
                        }
                    }
                    break;
                }
                default: {
                    yyerror_name("Unknown data type in assignment statement.", "Parsing");
                    break;
                }
            }
        }

        $1->is_static_checkable = $3->is_static_checkable && $1->array_pointer.is_static_checkable; 
        // propagate static checkability
        // if array_pointer is not static checkable, then the whole assignment is not static checkable
    }
    ;
expression:
    expression PLUS_MICROEX expression {
        switch ($1->type) {
            case TYPE_INT: {
                switch ($3->type) {
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val + $3->value.int_val;
                        printf("I_ADD %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression PLUS expression (%lld -> %lld + %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);
                        
                        $$->value.double_val = temp_symbol->value.double_val + $3->value.double_val;
                        printf("F_ADD %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        
                        printf("\t> expression -> expression PLUS expression (%g -> %lld + %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val + ($3->value.bool_val ? 1 : 0); // convert bool to int
                        printf("I_ADD %s %s %s\n", $1->name, $3->name, $$->name);
                        
                        printf("\t> expression -> expression PLUS expression (%lld -> %lld + %s)\n", $$->value.int_val, $1->value.int_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot add int with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot add int with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot add int with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_DOUBLE: {
                switch ($3->type) {
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val + temp_symbol->value.double_val;
                        printf("F_ADD %s %s %s\n", $1->name, temp_symbol->name, $$->name);

                        printf("\t> expression -> expression PLUS expression (%g -> %g + %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val + $3->value.double_val;
                        printf("F_ADD %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression PLUS expression (%g -> %g + %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $3->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $3->value.bool_val ? "true" : "false");

                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val + temp_symbol->value.double_val;
                        printf("F_ADD %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        
                        printf("\t> expression -> expression PLUS expression (%g -> %g + %s)\n", $$->value.double_val, $1->value.double_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot add double with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot add double with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot add double with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_STRING: {
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
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot add program name with another type.", "Type");
                break;
            }
            case TYPE_BOOL: {
                switch ($3->type) {
                    case TYPE_BOOL: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.bool_val + $3->value.bool_val; // c99 bool is int
                        printf("I_ADD %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression PLUS expression (%lld -> %s + %s)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.bool_val + $3->value.int_val;
                        printf("I_ADD %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression PLUS expression (%lld -> %s + %lld)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $1->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $1->value.bool_val ? "true" : "false");
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = temp_symbol->value.double_val + $3->value.double_val;
                        printf("F_ADD %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression PLUS expression (%g -> %s + %g)\n", $$->value.double_val, $1->value.bool_val ? "true" : "false", $3->value.double_val);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot add bool with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot add bool with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot add bool with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$->is_static_checkable = $1->is_static_checkable && $3->is_static_checkable; // propagate static checkability
    }
    | expression MINUS_MICROEX expression {
        switch ($1->type) {
            case TYPE_INT: {
                switch ($3->type) {
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val - $3->value.int_val;
                        printf("I_SUB %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%lld -> %lld - %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);

                        $$->value.double_val = temp_symbol->value.double_val - $3->value.double_val;
                        printf("F_SUB %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %lld - %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val - ($3->value.bool_val ? 1 : 0); // convert bool to int
                        printf("I_SUB %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%lld -> %lld - %s)\n", $$->value.int_val, $1->value.int_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot subtract int with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot subtract int with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot subtract int with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_DOUBLE: {
                switch ($3->type) {
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val - temp_symbol->value.double_val;
                        printf("F_SUB %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %g - %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val - $3->value.double_val;
                        printf("F_SUB %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %g - %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $3->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $3->value.bool_val ? "true" : "false");

                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val - temp_symbol->value.double_val;
                        printf("F_SUB %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %g - %s)\n", $$->value.double_val, $1->value.double_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot subtract double with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot subtract double with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot subtract double with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_STRING: {
                yyerror("Cannot subtract string type.");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot subtract program name with another type.", "Type");
                break;
            }
            case TYPE_BOOL: {
                switch ($3->type) {
                    case TYPE_BOOL: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.bool_val - $3->value.bool_val; // c99 bool is int
                        printf("I_SUB %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%lld -> %s - %s)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.bool_val - $3->value.int_val;
                        printf("I_SUB %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%lld -> %s - %lld)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $1->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $1->value.bool_val ? "true" : "false");
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = temp_symbol->value.double_val - $3->value.double_val;
                        printf("F_SUB %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression MINUS expression (%g -> %s - %g)\n", $$->value.double_val, $1->value.bool_val ? "true" : "false", $3->value.double_val);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot subtract bool with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot subtract bool with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot subtract bool with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$->is_static_checkable = $1->is_static_checkable && $3->is_static_checkable; // propagate static checkability
    }
    | expression MULTIPLY_MICROEX expression {
        switch ($1->type) {
            case TYPE_INT: {
                switch ($3->type) {
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val * $3->value.int_val;
                        printf("I_MUL %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%lld -> %lld * %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);

                        $$->value.double_val = temp_symbol->value.double_val * $3->value.double_val;
                        printf("F_MUL %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %lld * %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_val * ($3->value.bool_val ? 1 : 0);
                        printf("I_MUL %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%lld -> %lld * %s)\n", $$->value.int_val, $1->value.int_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot multiply int with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot multiply int with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot multiply int with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_DOUBLE: {
                switch ($3->type) {
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val * temp_symbol->value.double_val;
                        printf("F_MUL %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %g * %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val * $3->value.double_val;
                        printf("F_MUL %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %g * %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $3->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $3->value.bool_val ? "true" : "false");

                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val * temp_symbol->value.double_val;
                        printf("F_MUL %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %g * %s)\n", $$->value.double_val, $1->value.double_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot multiply double with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot multiply double with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot multiply double with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_BOOL: {
                switch ($3->type) {
                    case TYPE_BOOL: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.bool_val * $3->value.bool_val; // c99 bool is int
                        printf("I_MUL %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%lld -> %s * %s)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.bool_val * $3->value.int_val;
                        printf("I_MUL %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%lld -> %s * %lld)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $1->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $1->value.bool_val ? "true" : "false");
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = temp_symbol->value.double_val * $3->value.double_val;
                        printf("F_MUL %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression MULTIPLY expression (%g -> %s * %g)\n", $$->value.double_val, $1->value.bool_val ? "true" : "false", $3->value.double_val);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot multiply bool with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot multiply bool with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot multiply bool with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_STRING: {
                yyerror("Cannot multiply string type.");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot multiply program name with another type.", "Type");
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$->is_static_checkable = $1->is_static_checkable && $3->is_static_checkable; // propagate static checkability
    }
    | expression DIVISION_MICROEX expression {
        switch ($1->type) {
            case TYPE_INT: {
                switch ($3->type) {
                    case TYPE_INT: {
                        if ($3->value.int_val == 0 && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = ($3->value.int_val)? $1->value.int_val / $3->value.int_val : 0;
                        printf("I_DIV %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%lld -> %lld / %lld)\n", $$->value.int_val, $1->value.int_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        if ($3->value.double_val == 0.0 && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $1->value.int_val;
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $1->value.int_val);

                        $$->value.double_val = ($3->value.double_val)? temp_symbol->value.double_val / $3->value.double_val : 0.0;
                        printf("\t> expression -> expression DIVISION expression (%g -> %lld / %g)\n", $$->value.double_val, $1->value.int_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        if ($3->value.bool_val == false && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = ($3->value.bool_val)? ($1->value.int_val / ($3->value.bool_val ? 1 : 0)) : 0;
                        // convert bool to int & prevent division by zero when $3 is false and $3 isn't static checkable
                        printf("I_DIV %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%lld -> %lld / %s)\n", $$->value.int_val, $1->value.int_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot divide int with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot divide int with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot divide int with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_DOUBLE: {
                switch ($3->type) {
                    case TYPE_INT: {
                        if ($3->value.int_val == 0 && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = (double) $3->value.int_val;
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, $3->value.int_val);

                        $$->value.double_val = $1->value.double_val / temp_symbol->value.double_val;
                        printf("\t> expression -> expression DIVISION expression (%g -> %g / %lld)\n", $$->value.double_val, $1->value.double_val, $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        if ($3->value.double_val == 0.0 && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_val / $3->value.double_val;
                        printf("F_DIV %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%g -> %g / %g)\n", $$->value.double_val, $1->value.double_val, $3->value.double_val);
                        break;
                    }
                    case TYPE_BOOL: {
                        if ($3->value.bool_val == false && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $3->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $3->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $3->value.bool_val ? "true" : "false");

                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = ($3->value.bool_val)? ($1->value.double_val / temp_symbol->value.double_val) : 0.0;
                        // prevent division by zero when $3 is false and $3 isn't static checkable
                        printf("F_DIV %s %s %s\n", $1->name, temp_symbol->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%g -> %g / %s)\n", $$->value.double_val, $1->value.double_val, $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot divide double with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot divide double with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot divide double with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            case TYPE_STRING: {
                yyerror("Cannot divide string type.");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot divide program name with another type.", "Type");
                break;
            }
            case TYPE_BOOL: {
                switch ($3->type) {
                    case TYPE_BOOL: {
                        if ($3->value.bool_val == false && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = ($3->value.bool_val) ? ($1->value.bool_val / $3->value.bool_val) : 0;
                        // convert bool to int & prevent division by zero when $3 is false and $3 isn't static checkable
                        printf("I_DIV %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%lld -> %s / %s)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.bool_val ? "true" : "false");
                        break;
                    }
                    case TYPE_INT: {
                        if ($3->value.int_val == 0 && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = ($3->value.int_val)? $1->value.bool_val / $3->value.int_val : 0;
                        // prevent division by zero when $3 is zero and $3 isn't static checkable
                        printf("I_DIV %s %s %s\n", $1->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%lld -> %s / %lld)\n", $$->value.int_val, $1->value.bool_val ? "true" : "false", $3->value.int_val);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        if ($3->value.double_val == 0.0 && $3->is_static_checkable) {
                            yyerror_name("Division by zero is not allowed.", "Division");
                        }
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        temp_symbol->value.double_val = $1->value.bool_val ? 1.0 : 0.0; // convert bool to double
                        printf("I_TO_F %s %s\n", $1->name, temp_symbol->name);
                        printf("\t\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, $1->value.bool_val ? "true" : "false");

                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = ($3->value.double_val) ? (temp_symbol->value.double_val / $3->value.double_val) : 0.0;
                        // prevent division by zero when $3 is zero and $3 isn't static checkable
                        printf("F_DIV %s %s %s\n", temp_symbol->name, $3->name, $$->name);
                        printf("\t> expression -> expression DIVISION expression (%g -> %s / %g)\n", $$->value.double_val, $1->value.bool_val ? "true" : "false", $3->value.double_val);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror("Cannot divide bool with string type.");
                        break;
                    }
                    case TYPE_PROGRAM_NAME: {
                        yyerror_name("Cannot divide bool with program name type.", "Type");
                        break;
                    }
                    default: {
                        yyerror("Cannot divide bool with non-numeric type.");
                        break;
                    }
                }
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$->is_static_checkable = $1->is_static_checkable && $3->is_static_checkable; // propagate static checkability
    }
    | MINUS_MICROEX expression %prec UMINUS_MICROEX {
        switch ($2->type) {
            case TYPE_INT: {
                $$ = add_temp_symbol(TYPE_INT);
                $$->value.int_val = -$2->value.int_val;
                printf("I_UMINUS %s %s\n", $2->name, $$->name);
                printf("\t> expression -> MINUS expression (expression -> %lld)\n", $$->value.int_val);

                $$->is_static_checkable = $2->is_static_checkable; // propagate static checkability
                break;
            }
            case TYPE_DOUBLE: {
                $$ = add_temp_symbol(TYPE_DOUBLE);
                $$->value.double_val = -$2->value.double_val;
                printf("F_UMINUS %s %s\n", $2->name, $$->name);
                printf("\t> expression -> MINUS expression (expression -> %g)\n", $$->value.double_val);

                $$->is_static_checkable = $2->is_static_checkable; // propagate static checkability
                break;
            }
            case TYPE_STRING: {
                yyerror("Cannot apply unary minus on string type.");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot apply unary minus on program name type.", "Type");
                break;
            }
            case TYPE_BOOL: {
                $$ = add_temp_symbol(TYPE_INT);
                $$->value.int_val = -$2->value.bool_val;
                printf("I_UMINUS %s %s\n", $2->name, $$->name);
                printf("\t> expression -> MINUS expression (expression -> -%s)\n", $2->value.bool_val ? "true" : "false");

                $$->is_static_checkable = $2->is_static_checkable; // propagate static checkability
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$->is_static_checkable = $2->is_static_checkable; // propagate static checkability
    }
    | LEFT_PARENT_MICROEX expression RIGHT_PARENT_MICROEX {
        $$ = $2;
        switch ($2->type) {
            case TYPE_INT: {
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%lld))\n", $2->value.int_val);
                break;
            }
            case TYPE_DOUBLE: {
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%g))\n", $2->value.double_val);
                break;
            }
            case TYPE_STRING: {
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%s))\n", $2->value.str_val);
                break;
            }
            case TYPE_BOOL: {
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%s))\n", $2->value.bool_val ? "true" : "false");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                printf("\t> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%s))\n", $2->name);
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        // since propagate static checkability inherited from $2, so we don't need to set it again
    }
    | expression GREAT_MICROEX expression {
        $$ = condition_proccess($1, GREAT_MICROEX, $3).result_ptr;
    }
    | expression LESS_MICROEX expression {
        $$ = condition_proccess($1, LESS_MICROEX, $3).result_ptr;
    }
    | expression GREAT_EQUAL_MICROEX expression {
        $$ = condition_proccess($1, GREAT_EQUAL_MICROEX, $3).result_ptr;
    }
    | expression LESS_EQUAL_MICROEX expression {
        $$ = condition_proccess($1, LESS_EQUAL_MICROEX, $3).result_ptr;
    }
    | expression EQUAL_MICROEX expression {
        $$ = condition_proccess($1, EQUAL_MICROEX, $3).result_ptr;
    }
    | expression NOT_EQUAL_MICROEX expression {
        $$ = condition_proccess($1, NOT_EQUAL_MICROEX, $3).result_ptr;
    }
    | expression AND_MICROEX expression {
        $$ = condition_proccess($1, AND_MICROEX, $3).result_ptr;
    }
    | expression OR_MICROEX expression {
        $$ = condition_proccess($1, OR_MICROEX, $3).result_ptr;
    }
    | NOT_MICROEX expression {
        $$ = add_temp_symbol(TYPE_BOOL);
        switch ($2->type) {
            case TYPE_BOOL: {
                $$->value.bool_val = !$2->value.bool_val;
                printf("NOT %s %s\n", $2->name, $$->name);
                printf("\t> expression -> NOT expression (expression -> !%s)\n", $2->value.bool_val ? "true" : "false");
                break;
            }
            case TYPE_INT: {
                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                int_to_bool($2, temp_symbol);
                $$->value.bool_val = !temp_symbol->value.bool_val;
                printf("NOT %s %s\n", temp_symbol->name, $$->name);
                printf("\t> expression -> NOT expression (expression -> !%lld)\n", $2->value.int_val);
                break;
            }
            case TYPE_DOUBLE: {
                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                double_to_bool($2, temp_symbol);
                $$->value.bool_val = !temp_symbol->value.bool_val;
                printf("NOT %s %s\n", temp_symbol->name, $$->name);
                printf("\t> expression -> NOT expression (expression -> !%g)\n", $2->value.double_val);
                break;
            }
            case TYPE_STRING: {
                yyerror("Cannot apply NOT on string type.");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot apply NOT on program name type.", "Type");
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$->is_static_checkable = $2->is_static_checkable; // propagate static checkability
    }
    | id {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Variable not declared.", "Undeclared");
        }

        if ($1->array_pointer.dimensions > 0) { // array access
            if ($1->array_info.dimensions == 0) {
                yyerror_name("Array access with non-array variable.", "Type");
            }
            if ($1->array_info.dimensions != $1->array_pointer.dimensions) {
                yyerror_name("Array access with wrong number of dimensions.", "Index");
            }
            if ($1->array_pointer.is_static_checkable) {
                size_t index = get_array_offset($1->array_info, $1->array_pointer);
                switch ($1->type) {
                    case TYPE_INT: {
                        $$ = add_temp_symbol(TYPE_INT);
                        $$->value.int_val = $1->value.int_array[index];
                        printf("I_STORE %s[%zu] %s\n", $1->name, index, $$->name);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $1->name, dimensions);
                        free(dimensions);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        $$->value.double_val = $1->value.double_array[index];
                        printf("F_STORE %s[%zu] %s\n", $1->name, index, $$->name);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $$->name, dimensions);
                        free(dimensions);
                        break;
                    }
                    case TYPE_STRING: {
                        $$ = add_temp_symbol(TYPE_STRING);
                        $$->value.str_val = strdup($1->value.str_array[index]);
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $$->name, dimensions);
                        free(dimensions);
                        break;
                    }
                    case TYPE_BOOL: {
                        $$ = add_temp_symbol(TYPE_BOOL);
                        $$->value.bool_val = $1->value.bool_array[index];
                        printf("I_STORE %s[%zu] %s\n", $1->name, index, $$->name);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $$->name, dimensions);
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
            }
            else {
                symbol *offset = get_array_offset_unstatic($1->array_info, $1->array_pointer);
                switch ($1->type) {
                    case TYPE_INT: {
                        // we won't do any semantic propogation here, since we are not sure about the real array offset
                        $$ = add_temp_symbol(TYPE_INT);
                        printf("I_STORE %s[%s] %s\n", $1->name, offset->name, $$->name);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $1->name, dimensions);
                        free(dimensions);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        // we won't do any semantic propogation here, since we are not sure about the real array offset
                        $$ = add_temp_symbol(TYPE_DOUBLE);
                        printf("F_STORE %s[%s] %s\n", $1->name, offset->name, $$->name);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $1->name, dimensions);
                        free(dimensions);
                        break;
                    }
                    case TYPE_STRING: {
                        // we won't do any semantic propogation here, since we are not sure about the real array offset
                        $$ = add_temp_symbol(TYPE_STRING);
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $1->name, dimensions);
                        free(dimensions);
                        break;
                    }
                    case TYPE_BOOL: {
                        // we won't do any semantic propogation here, since we are not sure about the real array offset
                        $$ = add_temp_symbol(TYPE_BOOL);
                        printf("I_STORE %s[%s] %s\n", $1->name, offset->name, $$->name);
                        dimensions = array_dimensions_to_string($1->array_pointer);
                        printf("\t> expression -> id (expression -> %s%s)\n", $1->name, dimensions);
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
            }
        }
        else {
            $$ = $1;
            printf("\t> expression -> id (expression -> %s)\n", $1->name);
        }

        $$->is_static_checkable = $1->is_static_checkable; // propagate static checkability
    }
    | INTEGER_LITERAL_MICROEX {
        $$ = add_temp_symbol(TYPE_INT);
        $$->value.int_val = $1;
        printf("I_STORE %lld %s\n", $1, $$->name);
        printf("\t> expression -> INTEGER_LITERAL (expression -> %lld)\n", $1);

        $$->is_static_checkable = true; // integer literals are always static checkable
    }
    | FLOAT_LITERAL_MICROEX {
        $$ = add_temp_symbol(TYPE_DOUBLE);
        $$->value.double_val = $1;
        printf("F_STORE %g %s\n", $1, $$->name);
        printf("\t> expression -> FLOAT_LITERAL (expression -> %g)\n", $1);

        $$->is_static_checkable = true; // float literals are always static checkable
    }
    | EXP_FLOAT_LITERAL_MICROEX {
        $$ = add_temp_symbol(TYPE_DOUBLE);
        $$->value.double_val = $1;
        printf("F_STORE %g %s\n", $1, $$->name);
        printf("\t> expression -> EXP_FLOAT_LITERAL (expression -> %g)\n", $1);

        $$->is_static_checkable = true; // exp float literals are always static checkable
    }
    // This bad body is too difficult to implement,
    // so we currently do not support string and won't generate code for it.
    | STRING_LITERAL_MICROEX {
        // TODO: implement STRING_LITERAL if have time
        $$ = add_temp_symbol(TYPE_STRING);
        $$->value.str_val = $1; // $1 is a valid string by yytext
        yyerror_warning_test_mode("STRING_LITERAL is not supported yet and won't generate code for it.", "Feature", true, true);
        printf("\t> expression -> STRING_LITERAL (expression -> %s)\n", $1);

        $$->is_static_checkable = true; // string literals are always static checkable
    }
    | TRUE_LITERAL_MICROEX {
        $$ = add_temp_symbol(TYPE_BOOL);
        $$->value.bool_val = true;
        printf("I_STORE 1 %s\n", $$->name);
        printf("\t> expression -> TRUE_LITERAL (expression -> true)\n");

        $$->is_static_checkable = true; // boolean literals are always static checkable
    }
    | FALSE_LITERAL_MICROEX {
        $$ = add_temp_symbol(TYPE_BOOL);
        $$->value.bool_val = false;
        printf("I_STORE 0 %s\n", $$->name);
        printf("\t> expression -> FALSE_LITERAL (expression -> false)\n");

        $$->is_static_checkable = true; // boolean literals are always static checkable
    }
    ;
// read statement
read_statement:
    READ_MICROEX LEFT_PARENT_MICROEX id_list RIGHT_PARENT_MICROEX SEMICOLON_MICROEX {
        node *current = id_list.head;
        size_t ids_name_len = 1; // 1 for null terminator
        while (current != NULL) {
            if (current->symbol_ptr->type == TYPE_UNKNOWN) {
                yyerror_name("Error: Variable not declared.", "Undeclared");
            }
            if (current->symbol_ptr->array_pointer.dimensions > 0) { // array access
                if (current->symbol_ptr->array_pointer.is_static_checkable) {
                    size_t index = get_array_offset(current->symbol_ptr->array_info, current->symbol_ptr->array_pointer);
                    switch (current->symbol_ptr->type) {
                        case TYPE_INT: {
                            printf("CALL read_i %s[%zu]\n", current->symbol_ptr->name, index);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            printf("CALL read_f %s[%zu]\n", current->symbol_ptr->name, index);
                            break;
                        }
                        case TYPE_STRING: {
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            break;
                        }
                        case TYPE_BOOL: {
                            printf("CALL read_b %s[%zu]\n", current->symbol_ptr->name, index);
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
                }
            } 
            else {
                switch (current->symbol_ptr->type) {
                    case TYPE_INT: {
                        printf("CALL read_i %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        printf("CALL read_f %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    }
                    case TYPE_BOOL: {
                        printf("CALL read_b %s\n", current->symbol_ptr->name);
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in variable access.", "Parsing");
                        break;
                    }
                }
            }
            current->symbol_ptr->is_static_checkable = false; // read operation is not static checkable

            ids_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                ids_name_len += 2; // for ", "
            }
            current = current->next;
        }

        reallocable_char ids_name = {
            .str = (char *)malloc(sizeof(char) * ids_name_len), 
            .capacity = ids_name_len
        };
        if (ids_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        ids_name.str[0] = '\0';
        current = id_list.head;
        while (current != NULL) {
            if (ids_name.str[0] != '\0') {
                strcat(ids_name.str, ", ");
            }
            strcat(ids_name.str, current->symbol_ptr->name);
            if (current->symbol_ptr->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->symbol_ptr->array_pointer);
                if (realloc_char(&ids_name, ids_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(ids_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        printf("\t> read_statement -> read left_parent id_list right_parent semicolon (read_statement -> read(%s);)\n", ids_name.str);
        free(ids_name.str);
        free_id_list();
    }
    ;
// write statement
write_statement:
    WRITE_MICROEX LEFT_PARENT_MICROEX expression_list RIGHT_PARENT_MICROEX SEMICOLON_MICROEX {
        node *current = expression_list.head;
        size_t expressions_name_len = 1; // 1 for null terminator
        while (current != NULL) {
            if (current->symbol_ptr->type == TYPE_UNKNOWN) {
                yyerror_name("Error: Variable not declared.", "Undeclared");
            }
            switch (current->symbol_ptr->type) {
                case TYPE_INT: {
                    printf("CALL write_i %s\n", current->symbol_ptr->name);
                    break;
                }
                case TYPE_DOUBLE: {
                    printf("CALL write_f %s\n", current->symbol_ptr->name);
                    break;
                }
                case TYPE_STRING: {
                    yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                    break;
                }
                case TYPE_BOOL: {
                    printf("CALL write_b %s\n", current->symbol_ptr->name);
                    break;
                }
                case TYPE_PROGRAM_NAME: {
                    yyerror_name("Cannot access program name in write statement.", "Type");
                    break;
                }
                default: {
                    yyerror_name("Unknown data type in variable access.", "Parsing");
                    break;
                }
            }

            expressions_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                expressions_name_len += 2; // for ", "
            }
            current = current->next;
        }

        reallocable_char expressions_name = {
            .str = (char *)malloc(sizeof(char) * expressions_name_len), 
            .capacity = expressions_name_len
        };
        if (expressions_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        expressions_name.str[0] = '\0';
        current = expression_list.head;
        while (current != NULL) {
            if (expressions_name.str[0] != '\0') {
                strcat(expressions_name.str, ", ");
            }
            strcat(expressions_name.str, current->symbol_ptr->name);
            // expression semantics record is already handle array access in expression rule
            current = current->next;
        }
        printf("\t> write_statement -> write left_parent expression_list right_parent semicolon (write_statement -> write(%s);)\n", expressions_name.str);
        free(expressions_name.str);
        free_expression_list();
    }
    ;
expression_list:
    expression {
        $$ = $1;
        add_expression_node($1);
        printf("\t> expression_list -> expression (expression_list -> %s)\n", $1->name);
    }
    | expression_list COMMA_MICROEX expression {
        $$ = $1;
        add_expression_node($3);

        size_t expressions_name_len = 1; // 1 for null terminator
        node *current = expression_list.head;
        while (current != NULL) {
            expressions_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                expressions_name_len += 2; // for ", "
            }
            current = current->next;
        }

        reallocable_char expressions_name = {
            .str = (char *)malloc(sizeof(char) * expressions_name_len), 
            .capacity = expressions_name_len
        };
        if (expressions_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        expressions_name.str[0] = '\0';
        current = expression_list.head;
        while (current != NULL) {
            if (expressions_name.str[0] != '\0') {
                strcat(expressions_name.str, ", ");
            }
            strcat(expressions_name.str, current->symbol_ptr->name);
            // expression semantics record is already handle array access in expression rule
            current = current->next;
        }
        printf("\t> expression_list -> expression_list COMMA expression (expression_list -> %s)\n", expressions_name.str);
        free(expressions_name.str);
    }
    ;
// if statement
if_statement:
    if_prefix if_suffix {
        printf("%s:\n", $1->name); // false label for if condition isn't true
        printf("\t> if_statement -> if_prefix if_suffix\n");
    }
    | if_else_prefix if_suffix {
        printf("\t> if_statement -> if_else_prefix if_suffix\n");
    }
    ;
if_prefix:
    IF_MICROEX LEFT_PARENT_MICROEX expression RIGHT_PARENT_MICROEX THEN_MICROEX {
        label *true_label = add_label();
        label *false_label = add_label();
        $$ = false_label; // propagate false label for else part
        switch ($3->type) {
            case TYPE_INT:
            case TYPE_BOOL: {
                printf("I_CMP 0 %s\n", $3->name);
                printf("JNE %s\n", true_label->name);
                printf("JUMP %s\n", false_label->name);
                printf("%s:\n", true_label->name);
                if ($3->type == TYPE_INT) {
                    printf("\t> if_prefix -> if left_parent expression right_parent then (if_prefix -> if (%lld) then)\n", $3->value.int_val);
                } else {
                    printf("\t> if_prefix -> if left_parent expression right_parent then (if_prefix -> if (%s) then)\n", $3->value.bool_val ? "true" : "false");
                }
                break;
            }
            case TYPE_DOUBLE: {
                printf("F_CMP 0.0 %s\n", $3->name);
                printf("JNE %s\n", true_label->name);
                printf("JUMP %s\n", false_label->name);
                printf("%s:\n", true_label->name);
                printf("\t> if_prefix -> if left_parent expression right_parent then (if_prefix -> if (%g) then)\n", $3->value.double_val);
                break;
            }
            case TYPE_STRING: {
                yyerror("Cannot use string type in if statement condition.");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Cannot use program name type in if statement condition.", "Type");
                break;
            }
            default: {
                yyerror_name("Unknown data type in if statement condition.", "Parsing");
                break;
            }
        }
    }
    ;
if_else_prefix:
    if_prefix statement_list ELSE_MICROEX {
        printf("%s:\n", $1->name); // false label for if condition isn't true
        printf("\t> if_statement -> if_prefix statement_list else if_suffix\n");
    }
    ;
if_suffix:
    statement_list ENDIF_MICROEX {
        printf("\t> if_suffix -> statement_list endif\n");
    }
    ;

// for statement
for_statement:
    for_prefix statement_list ENDFOR_MICROEX {
        // increment/decrement the for variable
        if ($1.for_variable->array_pointer.dimensions > 0) {
            if ($1.for_variable->array_pointer.is_static_checkable) {
                size_t index = get_array_offset($1.for_variable->array_info, $1.for_variable->array_pointer);
                switch ($1.for_variable->type) {
                    case TYPE_INT: {
                        if ($1.for_direction == DIRECTION_TO) {
                            $1.for_variable->value.int_array[index]++;
                            printf("INC %s[%zu]\n", $1.for_variable->name, index);
                        }
                        else {
                            $1.for_variable->value.int_array[index]--;
                            printf("DEC %s[%zu]\n", $1.for_variable->name, index);
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        if ($1.for_direction == DIRECTION_TO) {
                            $1.for_variable->value.double_array[index]++;
                            printf("F_ADD %s[%zu] 1.0 %s\n", $1.for_variable->name, index, temp_symbol->name);
                        } else {
                            $1.for_variable->value.double_array[index]--;
                            printf("F_SUB %s[%zu] 1.0 %s\n", $1.for_variable->name, index, temp_symbol->name);
                        }
                        printf("F_STORE %s %s[%zu]\n", temp_symbol->name, $1.for_variable->name, index);
                        break;
                    }
                    case TYPE_BOOL:
                    case TYPE_STRING:
                    case TYPE_PROGRAM_NAME:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
            else {
                symbol *offset = get_array_offset_unstatic($1.for_variable->array_info, $1.for_variable->array_pointer);
                switch ($1.for_variable->type) {
                    case TYPE_INT: {
                        if ($1.for_direction == DIRECTION_TO) {
                            printf("INC %s[%s]\n", $1.for_variable->name, offset->name);
                        }
                        else {
                            printf("DEC %s[%s]\n", $1.for_variable->name, offset->name);
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                        if ($1.for_direction == DIRECTION_TO) {
                            printf("F_ADD %s[%s] 1.0 %s\n", $1.for_variable->name, offset->name, temp_symbol->name);
                        } else {
                            printf("F_SUB %s[%s] 1.0 %s\n", $1.for_variable->name, offset->name, temp_symbol->name);
                        }
                        printf("F_STORE %s %s[%s]\n", temp_symbol->name, $1.for_variable->name, offset->name);
                        break;
                    }
                    case TYPE_BOOL:
                    case TYPE_STRING:
                    case TYPE_PROGRAM_NAME:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
        }
        else {
            switch ($1.for_variable->type) {
                case TYPE_INT: {
                    if ($1.for_direction == DIRECTION_TO) {
                        $1.for_variable->value.int_val++;
                        printf("INC %s\n", $1.for_variable->name);
                    }
                    else {
                        $1.for_variable->value.int_val--;
                        printf("DEC %s\n", $1.for_variable->name);
                    }
                    break;
                }
                case TYPE_DOUBLE: {
                    symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                    if ($1.for_direction == DIRECTION_TO) {
                        $1.for_variable->value.double_val++;
                        printf("F_ADD %s 1.0 %s\n", $1.for_variable->name, temp_symbol->name);
                    } else {
                        $1.for_variable->value.double_val--;
                        printf("F_SUB %s 1.0 %s\n", $1.for_variable->name, temp_symbol->name);
                    }
                    printf("F_STORE %s %s\n", temp_symbol->name, $1.for_variable->name);
                    break;
                }
                case TYPE_BOOL:
                case TYPE_STRING:
                case TYPE_PROGRAM_NAME:
                default: {
                    yyerror_name("Impossible data type when parsing.", "Parsing");
                    break;
                }
            }
        }

        condition_info info = condition_proccess($1.for_variable, (($1.for_direction == DIRECTION_TO) ? LESS_MICROEX : GREAT_MICROEX), $1.for_end_expression);
        printf("I_CMP 0 %s\n", info.result_ptr->name);
        printf("JNE %s\n", $1.for_start_label->name);
        printf("%s\n", $1.for_end_label->name); // end label for for loop
        printf("\t> for_statement -> for_prefix statement_list endfor\n");
    }
for_prefix:
    FOR_MICROEX LEFT_PARENT_MICROEX id ASSIGN_MICROEX expression direction expression RIGHT_PARENT_MICROEX {
        if ($3->type == TYPE_UNKNOWN) {
            yyerror_name("Error: Variable not declared.", "Undeclared");
        }
        if ($3->type != TYPE_INT && $3->type != TYPE_DOUBLE) {
            yyerror_name("Loop variable must be of type int or double.", "Type");
        }
        if ($5->type != TYPE_INT && $5->type != TYPE_DOUBLE && $5->type != TYPE_BOOL) {
            yyerror_name("Loop start expression must be of type int, double or bool.", "Type");
        }
        if ($7->type != TYPE_INT && $7->type != TYPE_DOUBLE && $7->type != TYPE_BOOL) {
            yyerror_name("Loop end expression must be of type int, double or bool.", "Type");
        }

        // loop variable initialization
        if ($3->array_pointer.dimensions > 0) {
            if ($3->array_info.dimensions == 0) {
                yyerror_name("Array access with non-array variable.", "Type");
            }
            if ($3->array_info.dimensions != $3->array_pointer.dimensions) {
                yyerror_name("Array access with wrong number of dimensions.", "Index");
            }
            if ($3->array_pointer.is_static_checkable) {
                size_t index = get_array_offset($3->array_info, $3->array_pointer);
                switch ($3->type) {
                    case TYPE_INT: {
                        switch ($5->type) {
                            case TYPE_BOOL: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %s %s %s))\n", $3->name, index, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %s %s %lld))\n", $3->name, index, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %s %s %g))\n", $3->name, index, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_STORE %s %s[%zu]\n", $5->name, $3->name, index);
                                break;
                            }
                            case TYPE_INT: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %lld %s %s))\n", $3->name, index, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %lld %s %lld))\n", $3->name, index, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %lld %s %g))\n", $3->name, index, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_STORE %s %s[%zu]\n", $5->name, $3->name, index);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %g %s %s))\n", $3->name, index, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %g %s %lld))\n", $3->name, index, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %g %s %g))\n", $3->name, index, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("F_TO_I %s %s[%zu]\n", $5->name, $3->name, index);
                                break;
                            }
                            case TYPE_STRING: 
                            case TYPE_PROGRAM_NAME: 
                            default: {
                                yyerror_name("Impossible data type when parsing.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch ($5->type) {
                            case TYPE_BOOL: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %s %s %s))\n", $3->name, index, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %s %s %lld))\n", $3->name, index, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %s %s %g))\n", $3->name, index, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_TO_F %s %s[%zu]\n", $5->name, $3->name, index);
                                break;
                            }
                            case TYPE_INT: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %lld %s %s))\n", $3->name, index, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %lld %s %lld))\n", $3->name, index, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %lld %s %g))\n", $3->name, index, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_TO_F %s %s[%zu]\n", $5->name, $3->name, index);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %g %s %s))\n", $3->name, index, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %g %s %lld))\n", $3->name, index, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%zu] := %g %s %g))\n", $3->name, index, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("F_STORE %s %s[%zu]\n", $5->name, $3->name, index);
                                break;
                            }
                            case TYPE_STRING: 
                            case TYPE_PROGRAM_NAME: 
                            default: {
                                yyerror_name("Impossible data type when parsing.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL:
                    case TYPE_STRING: 
                    case TYPE_PROGRAM_NAME: 
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
            else {
                symbol *offset = get_array_offset_unstatic($3->array_info, $3->array_pointer);
                switch ($3->type) {
                    case TYPE_INT: {
                        switch ($5->type) {
                            case TYPE_BOOL: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %s))\n", $3->name, offset->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %lld))\n", $3->name, offset->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %g))\n", $3->name, offset->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_STORE %s %s[%s]\n", $5->name, $3->name, offset->name);
                                break;
                            }
                            case TYPE_INT: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %s))\n", $3->name, offset->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %lld))\n", $3->name, offset->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %g))\n", $3->name, offset->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_STORE %s %s[%s]\n", $5->name, $3->name, offset->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %s))\n", $3->name, offset->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %lld))\n", $3->name, offset->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %g))\n", $3->name, offset->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("F_TO_I %s %s[%s]\n", $5->name, $3->name, offset->name);
                                break;
                            }
                            case TYPE_STRING:
                            case TYPE_PROGRAM_NAME:
                            default: {
                                yyerror_name("Impossible data type when parsing.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch ($5->type) {
                            case TYPE_BOOL: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %s))\n", $3->name, offset->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %lld))\n", $3->name, offset->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %g))\n", $3->name, offset->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_TO_F %s %s[%s]\n", $5->name, $3->name, offset->name);
                                break;
                            }
                            case TYPE_INT: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %s))\n", $3->name, offset->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %lld))\n", $3->name, offset->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %g))\n", $3->name, offset->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("I_TO_F %s %s[%s]\n", $5->name, $3->name, offset->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                switch ($7->type) {
                                    case TYPE_BOOL: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %s))\n", $3->name, offset->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                        break;
                                    }
                                    case TYPE_INT: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %lld))\n", $3->name, offset->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                        break;
                                    }
                                    case TYPE_DOUBLE: {
                                        printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %g))\n", $3->name, offset->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                        break;
                                    }
                                    case TYPE_STRING:
                                    case TYPE_PROGRAM_NAME:
                                    default: {
                                        yyerror_name("Impossible data type when parsing.", "Parsing");
                                        break;
                                    }
                                }
                                printf("F_STORE %s %s[%s]\n", $5->name, $3->name, offset->name);
                                break;
                            }
                            case TYPE_STRING:
                            case TYPE_PROGRAM_NAME:
                            default: {
                                yyerror_name("Impossible data type when parsing.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL:
                    case TYPE_STRING:
                    case TYPE_PROGRAM_NAME:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
        }
        else {
            switch ($3->type) {
                case TYPE_INT: {
                    switch ($5->type) {
                        case TYPE_INT: {
                            switch ($7->type) {
                                case TYPE_BOOL: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %s))\n", $3->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %lld))\n", $3->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %g))\n", $3->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            printf("I_STORE %s %s\n", $5->name, $3->name);
                            break;
                        }
                        case TYPE_BOOL: {
                            switch ($7->type) {
                                case TYPE_BOOL: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %s))\n", $3->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %lld))\n", $3->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %g))\n", $3->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            printf("I_STORE %s %s\n", $5->name, $3->name);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            switch ($7->type) {
                                case TYPE_BOOL: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %g %s %s))\n", $3->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %g %s %lld))\n", $3->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %g %s %g))\n", $3->name, $5->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            printf("F_TO_I %s %s\n", $5->name, $3->name);
                            break;
                        }
                        case TYPE_STRING:
                        case TYPE_PROGRAM_NAME:
                        default: {
                            yyerror_name("Impossible data type when parsing.", "Parsing");
                            break;
                        }
                    }
                    break;
                }
                case TYPE_DOUBLE: {
                    switch ($5->type) {
                        case TYPE_INT: {
                            switch ($7->type) {
                                case TYPE_BOOL: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %s))\n", $3->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %lld))\n", $3->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %g))\n", $3->name, $5->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            printf("I_TO_F %s %s\n", $5->name, $3->name);
                            break;
                        }
                        case TYPE_BOOL: {
                            switch ($7->type) {
                                case TYPE_BOOL: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %s))\n", $3->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %lld))\n", $3->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    printf("\t> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %g))\n", $3->name, $5->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            printf("I_TO_F %s %s\n", $5->name, $3->name);
                            break;
                        }
                        case TYPE_STRING:
                        case TYPE_PROGRAM_NAME:
                        default: {
                            yyerror_name("Impossible data type when parsing.", "Parsing");
                            break;
                        }
                    }
                    break;
                }
                case TYPE_BOOL:
                case TYPE_STRING:
                case TYPE_PROGRAM_NAME:
                default: {
                    yyerror_name("Impossible data type when parsing.", "Parsing");
                    break;
                }
            }
        }
        if (!$5->is_static_checkable) {
            switch ($5->type) {
                case TYPE_INT: {
                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $5->name, $5->value.int_val);
                    break;
                }
                case TYPE_DOUBLE: {
                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $5->name, $5->value.double_val);
                    break;
                }
                case TYPE_BOOL: {
                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $5->name, $5->value.bool_val ? "true" : "false");
                    break;
                }
                case TYPE_STRING:
                case TYPE_PROGRAM_NAME:
                default: {
                    yyerror_name("Impossible data type when parsing.", "Parsing");
                    break;
                }
            }
        }
        if (!$7->is_static_checkable) {
            switch ($7->type) {
                case TYPE_INT: {
                    printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $7->name, $7->value.int_val);
                    break;
                }
                case TYPE_DOUBLE: {
                    printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $7->name, $7->value.double_val);
                    break;
                }
                case TYPE_BOOL: {
                    printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $7->name, $7->value.bool_val ? "true" : "false");
                    break;
                }
                case TYPE_STRING:
                case TYPE_PROGRAM_NAME:
                default: {
                    yyerror_name("Impossible data type when parsing.", "Parsing");
                    break;
                }
            }
        }

        label *for_start_label = add_label();
        label *for_end_label = add_label();
        condition_info info = condition_proccess($3, (($6 == DIRECTION_TO)? LESS_MICROEX : GREAT_MICROEX), $7);
        printf("I_CMP 0 %s\n", info.result_ptr->name);
        printf("JNE %s\n", for_start_label->name);
        printf("J %s\n", for_end_label->name);
        printf("%s:\n", for_start_label->name);

        $$.for_start_label = for_start_label;
        $$.for_end_label = for_end_label;
        $$.for_variable = $3;
        $$.for_direction = $6;
        $$.for_end_expression = $7;

        $3->is_static_checkable = $5->is_static_checkable && $7->is_static_checkable; // propagate static checkability
    }
    ;
direction:
    TO_MICROEX {
        $$ = DIRECTION_TO;
        printf("\t> direction -> to\n");
    }
    | DOWNTO_MICROEX {
        $$ = DIRECTION_DOWNTO;
        printf("\t> direction -> downto\n");
    }
    ;

// while statement
while_statement:
    while_prefix statement_list ENDWHILE_MICROEX {
        if ($1.while_condition->array_pointer.dimensions > 0) {
            if ($1.while_condition->array_pointer.is_static_checkable) {
                size_t index = get_array_offset($1.while_condition->array_info, $1.while_condition->array_pointer);
                switch ($1.while_condition->type) {
                    case TYPE_INT: {
                        printf("I_CMP 0 %s[%zu]\n", $1.while_condition->name, index);
                        printf("JNE %s\n", $1.while_start_label->name);

                        printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                        break;
                    }
                    case TYPE_DOUBLE: {
                        printf("F_CMP 0.0 %s[%zu]\n", $1.while_condition->name, index);
                        printf("JNE %s\n", $1.while_start_label->name);

                        printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                        break;
                    }
                    case TYPE_BOOL: {
                        printf("I_CMP 0 %s[%zu]\n", $1.while_condition->name, index);
                        printf("JNE %s\n", $1.while_start_label->name);

                        printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                        break;
                    }
                    case TYPE_STRING:
                    case TYPE_PROGRAM_NAME:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
            else {
                symbol *offset = get_array_offset_unstatic($1.while_condition->array_info, $1.while_condition->array_pointer);
                switch ($1.while_condition->type) {
                    case TYPE_INT: {
                        printf("I_CMP 0 %s[%s]\n", $1.while_condition->name, offset->name);
                        printf("JNE %s\n", $1.while_start_label->name);

                        printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                        break;
                    }
                    case TYPE_DOUBLE: {
                        printf("F_CMP 0.0 %s[%s]\n", $1.while_condition->name, offset->name);
                        printf("JNE %s\n", $1.while_start_label->name);

                        printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                        break;
                    }
                    case TYPE_BOOL: {
                        printf("I_CMP 0 %s[%s]\n", $1.while_condition->name, offset->name);
                        printf("JNE %s\n", $1.while_start_label->name);

                        printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                        break;
                    }
                    case TYPE_STRING:
                    case TYPE_PROGRAM_NAME:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
        }
        else {
            switch ($1.while_condition->type) {
                case TYPE_BOOL: {
                    printf("I_CMP 0 %s\n", $1.while_condition->name);
                    printf("JNE %s\n", $1.while_start_label->name);

                    printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                    break;
                }
                case TYPE_INT: {
                    printf("I_CMP 0 %s\n", $1.while_condition->name);
                    printf("JNE %s\n", $1.while_start_label->name);

                    printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                    break;
                }
                case TYPE_DOUBLE: {
                    printf("F_CMP 0.0 %s\n", $1.while_condition->name);
                    printf("JNE %s\n", $1.while_start_label->name);

                    printf("\t> while_statement -> while_prefix statement_list endwhile\n");
                    break;
                }
                case TYPE_STRING:
                case TYPE_PROGRAM_NAME:
                default: {
                    yyerror_name("Impossible data type when parsing.", "Parsing");
                    break;
                }
            }
        }

        printf("%s:\n", $1.while_end_label->name);
    }
    ;
while_prefix:
    WHILE_MICROEX LEFT_PARENT_MICROEX expression RIGHT_PARENT_MICROEX {
        if ($3->type != TYPE_BOOL && $3->type != TYPE_INT && $3->type != TYPE_DOUBLE) {
            yyerror("Condition in while statement must be of type bool, int or double.");
        }

        label *while_start_label = add_label();
        label *while_end_label = add_label();

        if ($3->array_pointer.dimensions > 0) {
            if ($3->array_pointer.is_static_checkable) {
                size_t index = get_array_offset($3->array_info, $3->array_pointer);
                switch ($3->type) {
                    case TYPE_INT: {
                        printf("I_CMP 0 %s[%zu]\n", $3->name, index);
                        printf("JNE %s\n", while_start_label->name);

                        printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%lld))\n", $3->value.int_array[index]);
                        if (!$3->is_static_checkable) {
                            printf("\t\t> %s[%zu] = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, index, $3->value.int_array[index]);
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        printf("F_CMP 0.0 %s[%zu]\n", $3->name, index);
                        printf("JNE %s\n", while_start_label->name);

                        printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%g))\n", $3->value.double_array[index]);
                        if (!$3->is_static_checkable) {
                            printf("\t\t> %s[%zu] = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, index, $3->value.double_array[index]);
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        printf("I_CMP 0 %s[%zu]\n", $3->name, index);
                        printf("JNE %s\n", while_start_label->name);

                        printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s))\n", $3->value.bool_array[index] ? "true" : "false");
                        if (!$3->is_static_checkable) {
                            printf("\t\t> %s[%zu] = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, index, $3->value.bool_array[index] ? "true" : "false");
                        }
                        break;
                    }
                    case TYPE_STRING:
                    case TYPE_PROGRAM_NAME:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
            else {
                symbol *offset = get_array_offset_unstatic($3->array_info, $3->array_pointer);
                dimensions = array_dimensions_to_string($3->array_pointer);
                switch ($3->type) {
                    case TYPE_INT: {
                        printf("I_CMP 0 %s[%s]\n", $3->name, offset->name);
                        printf("JNE %s\n", while_start_label->name);

                        printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s%s))\n", $3->name, dimensions);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        printf("F_CMP 0.0 %s[%s]\n", $3->name, offset->name);
                        printf("JNE %s\n", while_start_label->name);

                        printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s%s))\n", $3->name, dimensions);
                        break;
                    }
                    case TYPE_BOOL: {
                        printf("I_CMP 0 %s[%s]\n", $3->name, offset->name);
                        printf("JNE %s\n", while_start_label->name);

                        printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s%s))\n", $3->name, dimensions);
                        break;
                    }
                    case TYPE_STRING:
                    case TYPE_PROGRAM_NAME:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }
        }
        else {
            switch ($3->type) {
                case TYPE_BOOL: {
                    printf("I_CMP 0 %s\n", $3->name);
                    printf("JNE %s\n", while_start_label->name);

                    printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s))\n", $3->value.bool_val ? "true" : "false");
                    if (!$3->is_static_checkable) {
                        printf("\t\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.bool_val ? "true" : "false");
                    }
                    break;
                }
                case TYPE_INT: {
                    printf("I_CMP 0 %s\n", $3->name);
                    printf("JNE %s\n", while_start_label->name);

                    printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%lld))\n", $3->value.int_val);
                    if (!$3->is_static_checkable) {
                        printf("\t\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.int_val);
                    }
                    break;
                }
                case TYPE_DOUBLE: {
                    printf("F_CMP 0.0 %s\n", $3->name);
                    printf("JNE %s\n", while_start_label->name);

                    printf("\t> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%g))\n", $3->value.double_val);
                    if (!$3->is_static_checkable) {
                        printf("\t\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3->name, $3->value.double_val);
                    }
                    break;
                }
                case TYPE_STRING:
                case TYPE_PROGRAM_NAME:
                default: {
                    yyerror_name("Impossible data type when parsing.", "Parsing");
                    break;
                }
            }
        }

        $$.while_start_label = while_start_label;
        $$.while_end_label = while_end_label;
        $$.while_condition = $3;

        printf("J %s\n", while_end_label->name);
        printf("%s:\n", while_start_label->name);
    }
    ;
%%
