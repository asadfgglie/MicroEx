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

    function_info *current_function_info = NULL;
    // Not NULL when parsing function statement
    // when parsing function statement, here will store all local variable
    // after function statement parsing done, it will turn back to NULL
    // nested function is not allow in microex

    label *label_table = NULL;
    // label table for jump instructions
    // ensure that labels do not conflict with user-defined variables

    list id_list = {
        .head = NULL,
        .tail = NULL,
        .len = 0
    };

    list expression_list = {
        .head = NULL,
        .tail = NULL,
        .len = 0
    };

    list arg_list = {
        .head = NULL,
        .tail = NULL,
        .len = 0
    };

    char *dimensions = NULL;
    // temporary variable to store array dimensions string
    // to avoid memory leak, we will free this variable after use

    void add_node(symbol *symbol_ptr, list *list_ptr) {
        node* new_node = (node*)malloc(sizeof(node));
        if (new_node == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        new_node->symbol_ptr = symbol_ptr;
        new_node->next = NULL;
        new_node->array_pointer = symbol_ptr->array_pointer;

        if (list_ptr->head == NULL) {
            list_ptr->head = new_node;
            list_ptr->tail = new_node;
        } else {
            list_ptr->tail->next = new_node;
            list_ptr->tail = new_node;
        }
        list_ptr->len++;
    }

    void free_list(list *list_ptr) {
        node* current = list_ptr->head;
        node* next_node;

        while (current != NULL) {
            next_node = current->next;
            if (current->array_pointer.dimensions > 0){
                if (current->array_pointer.dimension_sizes != NULL) {
                    free(current->array_pointer.dimension_sizes);
                }
                if (current->array_pointer.dimension_sizes_symbol != NULL) {
                    free(current->array_pointer.dimension_sizes_symbol);
                }
            }
            free(current);
            current = next_node;
        }

        list_ptr->head = NULL;
        list_ptr->tail = NULL;
        list_ptr->len = 0;
    }

    void add_id_node(symbol *symbol_ptr) {
        add_node(symbol_ptr, &id_list);
    }
    void free_id_list() {
        free_list(&id_list);
    }

    void add_expression_node(symbol *symbol_ptr) {
        add_node(symbol_ptr, &expression_list);
    }
    void free_expression_list() {
        free_list(&expression_list);
    }

    void add_arg_node(symbol *symbol_ptr) {
        add_node(symbol_ptr, &arg_list);
    }
    void free_arg_list() {
        free_list(&arg_list);
    }

    /**
     * Convert an integer symbol to a boolean symbol.
     * If the integer is non-zero, the boolean will be true (1), otherwise false (0).
     * This function generates the necessary assembly code for the conversion.
     * This function assumes that index_symbol is not static checkable.
     * @param index_symbol The index symbol should get by `get_array_offset` function.
    */
    void itob_array(symbol *src, symbol *dest, symbol *index_symbol) {
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
        generate("I_CMP 0 %s\n", src->name);
        generate("JNE %s\n", true_label->name);
        generate("J %s\n", false_label->name);
        generate("%s:\n", true_label->name);
        generate("I_STORE 1 %s[%s]\n", dest->name, index_symbol->name);
        generate("J %s\n", end_label->name);
        generate("%s:\n", false_label->name);
        generate("I_STORE 0 %s[%s]\n", dest->name, index_symbol->name);
        generate("%s:\n", end_label->name);

        // since index_symbol is not static checkable, we don't do semantic propagation here
    }

    /** 
     * Convert a double symbol to a boolean symbol.
     * If the double is non-zero, the boolean will be true (1), otherwise false (0).
     * This function generates the necessary assembly code for the conversion.
     * This function assumes that index_symbol is not static checkable.
     * @param index_symbol The index symbol should get by `get_array_offset` function.
    */
    void ftob_array(symbol *src, symbol *dest, symbol *index_symbol) {
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
        generate("F_CMP 0.0 %s\n", src->name);
        generate("JNE %s\n", true_label->name);
        generate("J %s\n", false_label->name);
        generate("%s:\n", true_label->name);
        generate("I_STORE 1 %s[%s]\n", dest->name, index_symbol->name);
        generate("J %s\n", end_label->name);
        generate("%s:\n", false_label->name);
        generate("I_STORE 0 %s[%s]\n", dest->name, index_symbol->name);
        generate("%s:\n", end_label->name);

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
        generate("I_CMP 0 %s\n", src->name);
        generate("JNE %s\n", true_label->name);
        generate("J %s\n", false_label->name);
        generate("%s:\n", true_label->name);
        generate("I_STORE 1 %s\n", dest->name);
        generate("J %s\n", end_label->name);
        generate("%s:\n", false_label->name);
        generate("I_STORE 0 %s\n", dest->name);
        generate("%s:\n", end_label->name);

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
        generate("F_CMP 0.0 %s\n", src->name);
        generate("JNE %s\n", true_label->name);
        generate("J %s\n", false_label->name);
        generate("%s:\n", true_label->name);
        generate("I_STORE 1 %s\n", dest->name);
        generate("J %s\n", end_label->name);
        generate("%s:\n", false_label->name);
        generate("I_STORE 0 %s\n", dest->name);
        generate("%s:\n", end_label->name);

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
    condition_info condition_process(node *expr1, size_t condition, node *expr2) {
        if(expr1->symbol_ptr->array_info.dimensions > 0 && expr1->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        if(expr2->symbol_ptr->array_info.dimensions > 0 && expr2->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }

        if (expr1->symbol_ptr == NULL || expr2->symbol_ptr == NULL) {
            yyerror_name("expr1 or expr2 symbol is NULL.", "Parsing");
        }

        expr1->symbol_ptr = extract_array_symbol(expr1->symbol_ptr);
        expr2->symbol_ptr = extract_array_symbol(expr2->symbol_ptr);

        bool is_code_generation = true; // flag to indicate if code generation is needed

        symbol *result = add_temp_symbol(TYPE_BOOL);
        result->is_static_checkable = expr1->symbol_ptr->is_static_checkable && expr2->symbol_ptr->is_static_checkable; // propagate static checkability

        label *true_label, *false_label, *end_label;
        if (condition != AND_MICROEX && condition != OR_MICROEX && condition != NOT_MICROEX) {
            // for AND, OR, NOT conditions, we don't need labels
            true_label = add_label();
            false_label = add_label();
            end_label = add_label();
        }

        switch (condition) {
            case NOT_EQUAL_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val != expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val != expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val != expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JNE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val != temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->symbol_ptr->value.double_val != expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val != temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JNE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val != expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.double_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val != expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JNE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val != expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JNE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->symbol_ptr->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->symbol_ptr->value.str_val, expr2->symbol_ptr->value.str_val) != 0);
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
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case EQUAL_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val == expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val == expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val == expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JEQ %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val == temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->symbol_ptr->value.double_val == expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val == temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JEQ %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val == expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.double_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val == expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JEQ %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val == expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JEQ %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->symbol_ptr->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->symbol_ptr->value.str_val, expr2->symbol_ptr->value.str_val) == 0);
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
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case GREAT_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val > expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val > expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val > expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGT %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val > temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->symbol_ptr->value.double_val > expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val > temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JGT %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val > expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val > expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JGT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val > expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGT %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
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
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case LESS_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val < expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val < expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val < expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLT %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val < temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->symbol_ptr->value.double_val < expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val < temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JLT %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val < expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val < expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JLT %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val < expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLT %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->symbol_ptr->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->symbol_ptr->value.str_val, expr2->symbol_ptr->value.str_val) < 0);
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            is_code_generation = false; // no code generation for string comparison
                        }
                        else {
                            yyerror_name("Cannot compare string with other types.", "Type");
                        }
                        break;
                    }
                    default: {
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case GREAT_EQUAL_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val >= expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val >= expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val >= expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val >= temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->symbol_ptr->value.double_val >= expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val >= temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JGE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val >= expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val >= expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JGE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val >= expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JGE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->symbol_ptr->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->symbol_ptr->value.str_val, expr2->symbol_ptr->value.str_val) >= 0);
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
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case LESS_EQUAL_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val <= expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val <= expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.int_val <= expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val <= temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result->value.bool_val = (expr1->symbol_ptr->value.double_val <= expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (expr1->symbol_ptr->value.double_val <= temp_symbol->value.double_val);
                                generate("F_CMP %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                generate("JLE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val <= expr2->symbol_ptr->value.int_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.bool_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);

                                result->value.bool_val = (temp_symbol->value.double_val <= expr2->symbol_ptr->value.double_val);
                                generate("F_CMP %s %s\n", temp_symbol->name, expr2->symbol_ptr->name);
                                generate("JLE %s\n", true_label->name);
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val <= expr2->symbol_ptr->value.bool_val);
                                generate("I_CMP %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name);
                                generate("JLE %s\n", true_label->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        if (expr2->symbol_ptr->type == TYPE_STRING) {
                            result->value.bool_val = (strcmp(expr1->symbol_ptr->value.str_val, expr2->symbol_ptr->value.str_val) <= 0);
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
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case AND_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1->symbol_ptr, temp_symbol1);
                                int_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                generate("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1->symbol_ptr, temp_symbol1);
                                double_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                generate("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1->symbol_ptr, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val && expr2->symbol_ptr->value.bool_val);
                                generate("AND %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1->symbol_ptr, temp_symbol1);
                                int_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                generate("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1->symbol_ptr, temp_symbol1);
                                double_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val && temp_symbol2->value.bool_val);
                                generate("AND %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1->symbol_ptr, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val && expr2->symbol_ptr->value.bool_val);
                                generate("AND %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr2->symbol_ptr, temp_symbol);
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val && temp_symbol->value.bool_val);
                                generate("AND %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr2->symbol_ptr, temp_symbol);
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val && temp_symbol->value.bool_val);
                                generate("AND %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for AND operation
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val && expr2->symbol_ptr->value.bool_val);
                                generate("AND %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
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
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            case OR_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1->symbol_ptr, temp_symbol1);
                                int_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                generate("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1->symbol_ptr, temp_symbol1);
                                double_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                generate("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr1->symbol_ptr, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val || expr2->symbol_ptr->value.bool_val);
                                generate("OR %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1->symbol_ptr, temp_symbol1);
                                int_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                generate("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol1 = add_temp_symbol(TYPE_BOOL), *temp_symbol2 = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1->symbol_ptr, temp_symbol1);
                                double_to_bool(expr2->symbol_ptr, temp_symbol2);
                                result->value.bool_val = (temp_symbol1->value.bool_val || temp_symbol2->value.bool_val);
                                generate("OR %s %s %s\n", temp_symbol1->name, temp_symbol2->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr1->symbol_ptr, temp_symbol);
                                result->value.bool_val = (temp_symbol->value.bool_val || expr2->symbol_ptr->value.bool_val);
                                generate("OR %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                                break;
                            }
                        }
                        break;
                    }
                    case TYPE_BOOL: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                int_to_bool(expr2->symbol_ptr, temp_symbol);
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val || temp_symbol->value.bool_val);
                                generate("OR %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                                double_to_bool(expr2->symbol_ptr, temp_symbol);
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val || temp_symbol->value.bool_val);
                                generate("OR %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                is_code_generation = false; // no more code generation for OR operation
                                break;
                            }
                            case TYPE_BOOL: {
                                result->value.bool_val = (expr1->symbol_ptr->value.bool_val || expr2->symbol_ptr->value.bool_val);
                                generate("OR %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
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
                                yyerror_name("Unknown data type in `condition_process`.", "Parsing");
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
                        yyerror_name("Unknown data type in `condition_process`.", "Parsing");
                        break;
                    }
                }
                break;
            }
            default: {
                yyerror_name("Unknown condition in `condition_process`.", "Parsing");
                break;
            }
        }

        if (is_code_generation) {
            generate("J %s\n", false_label->name);
            generate("%s:\n", true_label->name);
            generate("I_STORE 1 %s\n", result->name);
            generate("J %s\n", end_label->name);
            generate("%s:\n", false_label->name);
            generate("I_STORE 0 %s\n", result->name);
            generate("%s:\n", end_label->name);
        }

        node result_node = {
            .symbol_ptr = result,
            .next = NULL,
            .array_pointer = empty_array_info()
        };

        condition_info info = {
            .result_node = result_node,
            .true_label_ptr = true_label,
            .false_label_ptr = false_label,
            .end_label_ptr = end_label
        };

        return info;
    }

    /**
     * Process the operator for `expr1 operator expr2`.
     * This function generates the necessary assembly code for the operator.
     * @param operator The operator to process, define by operator token id e.g. PLUS_MICROEX, MINUS_MICROEX, etc.
     * @param expr1 The first expression to evaluate.
     * @param expr2 The second expression to evaluate.
     * @return A symbol representing the result of the operation. Propagates static checkability from expr1 and expr2.
     */
    node operator_process(node *expr1, size_t operator, node *expr2) {
        if(expr1->symbol_ptr->array_info.dimensions > 0 && expr1->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        if(expr2->symbol_ptr->array_info.dimensions > 0 && expr2->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        
        if (expr1->symbol_ptr == NULL || expr2->symbol_ptr == NULL) {
            yyerror_name("expr1 or expr2 symbol is NULL.", "Parsing");
        }

        expr1->symbol_ptr->array_pointer = expr1->array_pointer;
        expr1->symbol_ptr = extract_array_symbol(expr1->symbol_ptr);
        expr1->symbol_ptr->array_pointer = empty_array_info();

        expr2->symbol_ptr->array_pointer = expr2->array_pointer;
        expr2->symbol_ptr = extract_array_symbol(expr2->symbol_ptr);
        expr2->symbol_ptr->array_pointer = empty_array_info();

        symbol *result;

        switch (operator) {
            case PLUS_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.int_val + expr2->symbol_ptr->value.int_val;
                                generate("I_ADD %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression PLUS expression (%lld -> %lld + %lld)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr1->symbol_ptr->value.int_val);
                                
                                result->value.double_val = temp_symbol->value.double_val + expr2->symbol_ptr->value.double_val;
                                generate("F_ADD %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
                                
                                logging("> expression -> expression PLUS expression (%g -> %lld + %g)\n", result->value.double_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.int_val + (expr2->symbol_ptr->value.bool_val ? 1 : 0); // convert bool to int
                                generate("I_ADD %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                
                                logging("> expression -> expression PLUS expression (%lld -> %lld + %s)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr2->symbol_ptr->value.int_val);

                                result->value.double_val = expr1->symbol_ptr->value.double_val + temp_symbol->value.double_val;
                                generate("F_ADD %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);

                                logging("> expression -> expression PLUS expression (%g -> %g + %lld)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = expr1->symbol_ptr->value.double_val + expr2->symbol_ptr->value.double_val;
                                generate("F_ADD %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression PLUS expression (%g -> %g + %g)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr2->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr2->symbol_ptr->value.bool_val ? "true" : "false");

                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = expr1->symbol_ptr->value.double_val + temp_symbol->value.double_val;
                                generate("F_ADD %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                
                                logging("> expression -> expression PLUS expression (%g -> %g + %s)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        if (expr2->symbol_ptr->type == TYPE_STRING) {
                            result = add_temp_symbol(TYPE_STRING);
                            result->value.str_val = (char *)malloc(strlen(expr1->symbol_ptr->value.str_val) + strlen(expr2->symbol_ptr->value.str_val) + 1);
                            if (result->value.str_val == NULL) {
                                yyerror_name("Out of memory when malloc.", "Parsing");
                            }
                            result->value.str_val[0] = '\0'; // Initialize to empty string
                            sprintf(result->value.str_val, "%s%s", expr1->symbol_ptr->value.str_val, expr2->symbol_ptr->value.str_val);
                            yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                            logging("> expression -> expression PLUS expression (%s -> %s + %s)\n", result->value.str_val, expr1->symbol_ptr->value.str_val, expr2->symbol_ptr->value.str_val);
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_BOOL: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.bool_val + expr2->symbol_ptr->value.bool_val; // c99 bool is int
                                generate("I_ADD %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression PLUS expression (%lld -> %s + %s)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.bool_val ? "true" : "false");
                                break;
                            }
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.bool_val + expr2->symbol_ptr->value.int_val;
                                generate("I_ADD %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression PLUS expression (%lld -> %s + %lld)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr1->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr1->symbol_ptr->value.bool_val ? "true" : "false");
                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = temp_symbol->value.double_val + expr2->symbol_ptr->value.double_val;
                                generate("F_ADD %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression PLUS expression (%g -> %s + %g)\n", result->value.double_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.double_val);
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
                break;
            }
            case MINUS_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.int_val - expr2->symbol_ptr->value.int_val;
                                generate("I_SUB %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MINUS expression (%lld -> %lld - %lld)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr1->symbol_ptr->value.int_val);

                                result->value.double_val = temp_symbol->value.double_val - expr2->symbol_ptr->value.double_val;
                                generate("F_SUB %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MINUS expression (%g -> %lld - %g)\n", result->value.double_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.int_val - (expr2->symbol_ptr->value.bool_val ? 1 : 0); // convert bool to int
                                generate("I_SUB %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MINUS expression (%lld -> %lld - %s)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr2->symbol_ptr->value.int_val);

                                result->value.double_val = expr1->symbol_ptr->value.double_val - temp_symbol->value.double_val;
                                generate("F_SUB %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                logging("> expression -> expression MINUS expression (%g -> %g - %lld)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = expr1->symbol_ptr->value.double_val - expr2->symbol_ptr->value.double_val;
                                generate("F_SUB %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MINUS expression (%g -> %g - %g)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr2->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr2->symbol_ptr->value.bool_val ? "true" : "false");

                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = expr1->symbol_ptr->value.double_val - temp_symbol->value.double_val;
                                generate("F_SUB %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                logging("> expression -> expression MINUS expression (%g -> %g - %s)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_BOOL: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.bool_val - expr2->symbol_ptr->value.bool_val; // c99 bool is int
                                generate("I_SUB %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MINUS expression (%lld -> %s - %s)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.bool_val ? "true" : "false");
                                break;
                            }
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.bool_val - expr2->symbol_ptr->value.int_val;
                                generate("I_SUB %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MINUS expression (%lld -> %s - %lld)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr1->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr1->symbol_ptr->value.bool_val ? "true" : "false");
                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = temp_symbol->value.double_val - expr2->symbol_ptr->value.double_val;
                                generate("F_SUB %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MINUS expression (%g -> %s - %g)\n", result->value.double_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.double_val);
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
                break;
            }
            case MULTIPLY_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.int_val * expr2->symbol_ptr->value.int_val;
                                generate("I_MUL %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%lld -> %lld * %lld)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr1->symbol_ptr->value.int_val);

                                result->value.double_val = temp_symbol->value.double_val * expr2->symbol_ptr->value.double_val;
                                generate("F_MUL %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%g -> %lld * %g)\n", result->value.double_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.int_val * (expr2->symbol_ptr->value.bool_val ? 1 : 0);
                                generate("I_MUL %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%lld -> %lld * %s)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr2->symbol_ptr->value.int_val);

                                result->value.double_val = expr1->symbol_ptr->value.double_val * temp_symbol->value.double_val;
                                generate("F_MUL %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%g -> %g * %lld)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = expr1->symbol_ptr->value.double_val * expr2->symbol_ptr->value.double_val;
                                generate("F_MUL %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%g -> %g * %g)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr2->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr2->symbol_ptr->value.bool_val ? "true" : "false");

                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = expr1->symbol_ptr->value.double_val * temp_symbol->value.double_val;
                                generate("F_MUL %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%g -> %g * %s)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_BOOL: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.bool_val * expr2->symbol_ptr->value.bool_val; // c99 bool is int
                                generate("I_MUL %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%lld -> %s * %s)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.bool_val ? "true" : "false");
                                break;
                            }
                            case TYPE_INT: {
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = expr1->symbol_ptr->value.bool_val * expr2->symbol_ptr->value.int_val;
                                generate("I_MUL %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%lld -> %s * %lld)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr1->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr1->symbol_ptr->value.bool_val ? "true" : "false");
                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = temp_symbol->value.double_val * expr2->symbol_ptr->value.double_val;
                                generate("F_MUL %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression MULTIPLY expression (%g -> %s * %g)\n", result->value.double_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.double_val);
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
                break;
            }
            case DIVISION_MICROEX: {
                switch (expr1->symbol_ptr->type) {
                    case TYPE_INT: {
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                if (expr2->symbol_ptr->value.int_val == 0 && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = (expr2->symbol_ptr->value.int_val)? expr1->symbol_ptr->value.int_val / expr2->symbol_ptr->value.int_val : 0;
                                generate("I_DIV %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression DIVISION expression (%lld -> %lld / %lld)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                if (expr2->symbol_ptr->value.double_val == 0.0 && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr1->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr1->symbol_ptr->value.int_val);

                                result->value.double_val = (expr2->symbol_ptr->value.double_val)? temp_symbol->value.double_val / expr2->symbol_ptr->value.double_val : 0.0;
                                logging("> expression -> expression DIVISION expression (%g -> %lld / %g)\n", result->value.double_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                if (expr2->symbol_ptr->value.bool_val == false && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = (expr2->symbol_ptr->value.bool_val)? (expr1->symbol_ptr->value.int_val / (expr2->symbol_ptr->value.bool_val ? 1 : 0)) : 0;
                                // convert bool to int & prevent division by zero when expr2->symbol_ptr is false and expr2->symbol_ptr isn't static checkable
                                generate("I_DIV %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression DIVISION expression (%lld -> %lld / %s)\n", result->value.int_val, expr1->symbol_ptr->value.int_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_INT: {
                                if (expr2->symbol_ptr->value.int_val == 0 && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                result = add_temp_symbol(TYPE_DOUBLE);
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = (double) expr2->symbol_ptr->value.int_val;
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting int to double (%s -> %lld)\n", temp_symbol->name, expr2->symbol_ptr->value.int_val);

                                result->value.double_val = expr1->symbol_ptr->value.double_val / temp_symbol->value.double_val;
                                logging("> expression -> expression DIVISION expression (%g -> %g / %lld)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                if (expr2->symbol_ptr->value.double_val == 0.0 && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = expr1->symbol_ptr->value.double_val / expr2->symbol_ptr->value.double_val;
                                generate("F_DIV %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression DIVISION expression (%g -> %g / %g)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.double_val);
                                break;
                            }
                            case TYPE_BOOL: {
                                if (expr2->symbol_ptr->value.bool_val == false && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr2->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr2->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr2->symbol_ptr->value.bool_val ? "true" : "false");

                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = (expr2->symbol_ptr->value.bool_val)? (expr1->symbol_ptr->value.double_val / temp_symbol->value.double_val) : 0.0;
                                // prevent division by zero when expr2->symbol_ptr is false and expr2->symbol_ptr isn't static checkable
                                generate("F_DIV %s %s %s\n", expr1->symbol_ptr->name, temp_symbol->name, result->name);
                                logging("> expression -> expression DIVISION expression (%g -> %g / %s)\n", result->value.double_val, expr1->symbol_ptr->value.double_val, expr2->symbol_ptr->value.bool_val ? "true" : "false");
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
                        switch (expr2->symbol_ptr->type) {
                            case TYPE_BOOL: {
                                if (expr2->symbol_ptr->value.bool_val == false && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = (expr2->symbol_ptr->value.bool_val) ? (expr1->symbol_ptr->value.bool_val / expr2->symbol_ptr->value.bool_val) : 0;
                                // convert bool to int & prevent division by zero when expr2->symbol_ptr is false and expr2->symbol_ptr isn't static checkable
                                generate("I_DIV %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression DIVISION expression (%lld -> %s / %s)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.bool_val ? "true" : "false");
                                break;
                            }
                            case TYPE_INT: {
                                if (expr2->symbol_ptr->value.int_val == 0 && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                result = add_temp_symbol(TYPE_INT);
                                result->value.int_val = (expr2->symbol_ptr->value.int_val)? expr1->symbol_ptr->value.bool_val / expr2->symbol_ptr->value.int_val : 0;
                                // prevent division by zero when expr2->symbol_ptr is zero and expr2->symbol_ptr isn't static checkable
                                generate("I_DIV %s %s %s\n", expr1->symbol_ptr->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression DIVISION expression (%lld -> %s / %lld)\n", result->value.int_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.int_val);
                                break;
                            }
                            case TYPE_DOUBLE: {
                                if (expr2->symbol_ptr->value.double_val == 0.0 && expr2->symbol_ptr->is_static_checkable) {
                                    yyerror_name("Division by zero is not allowed.", "Division");
                                }
                                symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                                temp_symbol->value.double_val = expr1->symbol_ptr->value.bool_val ? 1.0 : 0.0; // convert bool to double
                                generate("I_TO_F %s %s\n", expr1->symbol_ptr->name, temp_symbol->name);
                                logging("\t> auto casting bool to double (%s -> %s)\n", temp_symbol->name, expr1->symbol_ptr->value.bool_val ? "true" : "false");

                                result = add_temp_symbol(TYPE_DOUBLE);
                                result->value.double_val = (expr2->symbol_ptr->value.double_val) ? (temp_symbol->value.double_val / expr2->symbol_ptr->value.double_val) : 0.0;
                                // prevent division by zero when expr2->symbol_ptr is zero and expr2->symbol_ptr isn't static checkable
                                generate("F_DIV %s %s %s\n", temp_symbol->name, expr2->symbol_ptr->name, result->name);
                                logging("> expression -> expression DIVISION expression (%g -> %s / %g)\n", result->value.double_val, expr1->symbol_ptr->value.bool_val ? "true" : "false", expr2->symbol_ptr->value.double_val);
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
                break;
            }
            default: {
                yyerror_name("Unknow operator.", "Parsing");
                break;
            }
        }

        result->is_static_checkable = expr1->symbol_ptr->is_static_checkable && expr2->symbol_ptr->is_static_checkable; // propagate static checkability

        node result_node = {
            .symbol_ptr = result,
            .next = NULL,
            .array_pointer = empty_array_info()
        };

        return result_node;
    }

    /**
     * Process function declaration head.
     * This function generates the necessary assembly code.
     */
    void function_prefix_process(function_head head) {
        data_type return_type = head.return_type;
        symbol *function_ptr = head.symbol_ptr;
        char *type_str;

        current_function_info->argc = arg_list.len;
        current_function_info->args = (symbol **)malloc(sizeof(symbol *) * arg_list.len);
        if (current_function_info->args == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        char *return_name = (char *)malloc(sizeof(char) * (strlen(function_ptr->name) + strlen(FN_RETURN_SYMBOL_PREFIX) + 1));
        type_str = data_type_to_string(return_type);
        if (return_name == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        return_name[0] = '\0';
        sprintf(return_name, "%s%s", FN_RETURN_SYMBOL_PREFIX, type_str);
        current_function_info->return_arg = get_symbol(return_name);
        current_function_info->return_arg->type = return_type;
        current_function_info->local_symbol_table = NULL;
        free(type_str);

        node *current = arg_list.head;

        generate("%s%s:\n", FN_NAME_LABEL_PREFIX, function_ptr->name);
        // use label for marking function args since label do not affect execution
        size_t index = 0;
        while (current != NULL) {
            generate("%s%s:\n", FN_ARG_LABEL_PREFIX, current->symbol_ptr->name);
            current_function_info->args[index] = current->symbol_ptr;
            HASH_ADD_STR(current_function_info->local_symbol_table, name, current->symbol_ptr);
            
            current = current->next;
            index++;
        }

        current = arg_list.head;
        // declare position arg
        while (current != NULL) {
            if (current->array_pointer.dimensions > 0) {
                for (size_t i = 0; i < current->array_pointer.dimensions; i++) {
                    if (current->array_pointer.dimension_sizes[i] <= 0) {
                        yyerror_name("Array dimension must be greater than 0 when declaring.", "Index");
                    }
                }
                char *array_dimensions = array_range_to_string(current->array_pointer);
                type_str = data_array_type_to_string(current->symbol_ptr->type);

                generate("DECLARE %s %s %s\n", current->symbol_ptr->name, type_str, array_dimensions);
                free(type_str);
                free(array_dimensions);
                copy_array_info(&(current->symbol_ptr->array_info), &(current->array_pointer));
                current->symbol_ptr->array_pointer = empty_array_info();

                size_t array_size = array_range(current->symbol_ptr->array_info);
                switch (current->symbol_ptr->type) {
                    case TYPE_INT: {
                        current->symbol_ptr->value.int_array = (long long *)calloc(array_size, sizeof(long long));
                        if (current->symbol_ptr->value.int_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        current->symbol_ptr->value.double_array = (double *)calloc(array_size, sizeof(double));
                        if (current->symbol_ptr->value.double_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        break;
                    }
                    case TYPE_STRING: {
                        current->symbol_ptr->value.str_array = (char **)calloc(array_size, sizeof(char *));
                        if (current->symbol_ptr->value.str_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    }
                    case TYPE_BOOL: {
                        current->symbol_ptr->value.bool_array = (bool *)calloc(array_size, sizeof(bool));
                        if (current->symbol_ptr->value.bool_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
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
                type_str = data_type_to_string(current->symbol_ptr->type);
                generate("DECLARE %s %s\n", current->symbol_ptr->name, type_str);
                free(type_str);
            }
            // we don't need to initialize since position arg will be determined when function is called

            current = current->next;
        }
        
        type_str = data_type_to_string(function_ptr->type);
        generate("DECLARE %s %s\n", function_ptr->name, type_str);
        free(type_str);
        

        type_str = data_type_to_string(return_type);
        generate("DECLARE %s %s\n", current_function_info->return_arg->name, type_str);
        free(type_str);

        free_arg_list();
    }

    /**
     * Process function statement for return statement.
     * This function generates the necessary assembly code.
    */
    void function_statement_process(node *node_ptr) {
        if(node_ptr->symbol_ptr->array_info.dimensions > 0 && node_ptr->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        node_ptr->symbol_ptr = extract_array_symbol(node_ptr->symbol_ptr);

        data_type return_type = current_function_info->return_arg->type;
        char *type_str = data_type_to_string(return_type);
        switch (node_ptr->symbol_ptr->type) {
            case TYPE_INT: {
                if (return_type != TYPE_INT && return_type != TYPE_BOOL && return_type != TYPE_DOUBLE) {
                    char *tmp = (char *)malloc(sizeof(char) * (49 + strlen(type_str)));
                    if (tmp == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    tmp[0] = '\0';
                    sprintf(tmp, "Return variable type should be numeric, but is %s", type_str);
                    yyerror_name(tmp, "Type");
                }

                if (return_type == TYPE_INT) {
                    current_function_info->return_arg->value.int_val = node_ptr->symbol_ptr->value.int_val;
                    generate("I_STORE %s %s\n", node_ptr->symbol_ptr->name, current_function_info->return_arg->name);
                }
                else if (return_type == TYPE_BOOL) {
                    current_function_info->return_arg->value.bool_val = (node_ptr->symbol_ptr->value.int_val) ? 1 : 0;
                    int_to_bool(node_ptr->symbol_ptr, current_function_info->return_arg);
                }
                else {
                    current_function_info->return_arg->value.double_val = (double)node_ptr->symbol_ptr->value.int_val;
                    generate("I_TO_F %s %s\n", node_ptr->symbol_ptr->name, current_function_info->return_arg->name);
                }

                break;
            }
            case TYPE_BOOL: {
                if (return_type != TYPE_INT && return_type != TYPE_BOOL && return_type != TYPE_DOUBLE) {
                    char *tmp = (char *)malloc(sizeof(char) * (49 + strlen(type_str)));
                    if (tmp == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    tmp[0] = '\0';
                    sprintf(tmp, "Return variable type should be numeric, but is %s", type_str);
                    yyerror_name(tmp, "Type");
                }

                if (return_type == TYPE_INT) {
                    current_function_info->return_arg->value.int_val = node_ptr->symbol_ptr->value.bool_val;
                    generate("I_STORE %s %s\n", node_ptr->symbol_ptr->name, current_function_info->return_arg->name);
                }
                else if (return_type == TYPE_BOOL) {
                    current_function_info->return_arg->value.bool_val = node_ptr->symbol_ptr->value.bool_val;
                    generate("I_STORE %s %s\n", node_ptr->symbol_ptr->name, current_function_info->return_arg->name);
                }
                else {
                    current_function_info->return_arg->value.double_val = (double)node_ptr->symbol_ptr->value.bool_val;
                    generate("I_TO_F %s %s\n", node_ptr->symbol_ptr->name, current_function_info->return_arg->name);
                }

                break;
            }
            case TYPE_DOUBLE: {
                if (return_type != TYPE_INT && return_type != TYPE_BOOL && return_type != TYPE_DOUBLE) {
                    char *tmp = (char *)malloc(sizeof(char) * (49 + strlen(type_str)));
                    if (tmp == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    tmp[0] = '\0';
                    sprintf(tmp, "Return variable type should be numeric, but is %s", type_str);
                    yyerror_name(tmp, "Type");
                }

                if (return_type == TYPE_INT) {
                    current_function_info->return_arg->value.int_val = node_ptr->symbol_ptr->value.double_val;
                    generate("F_TO_I %s %s\n", node_ptr->symbol_ptr->name, current_function_info->return_arg->name);
                }
                else if (return_type == TYPE_BOOL) {
                    current_function_info->return_arg->value.bool_val = node_ptr->symbol_ptr->value.double_val;
                    double_to_bool(node_ptr->symbol_ptr, current_function_info->return_arg);
                }
                else {
                    current_function_info->return_arg->value.double_val = node_ptr->symbol_ptr->value.double_val;
                    generate("F_STORE %s %s\n", node_ptr->symbol_ptr->name, current_function_info->return_arg->name);
                }

                break;
            }
            case TYPE_STRING: {
                if (return_type != TYPE_STRING) {
                    char *tmp = (char *)malloc(sizeof(char) * (48 + strlen(type_str)));
                    if (tmp == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    tmp[0] = '\0';
                    sprintf(tmp, "Return variable type should be String, but is %s", type_str);
                    yyerror_name(tmp, "Type");
                }
                current_function_info->return_arg->value.str_val = strdup(node_ptr->symbol_ptr->value.str_val);
                if (current_function_info->return_arg->value.str_val == NULL) {
                    yyerror_name("Out of memory when calloc.", "Parsing");
                } 
                yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                break;
            }
            case TYPE_PROGRAM_NAME: {
                yyerror_name("Program name type should not become expression type.", "Parsing");
                break;
            }
            default: {
                yyerror_name("Unknown data type in function statement.", "Parsing");
                break;
            }
        }

        generate("RETURN %s\n", current_function_info->return_arg->name);

        current_function_info = NULL;
        // parsing done of function statement
        free(type_str);
    }
%}

%union {
    long long int_val;
    char *str_val;
    double double_val;
    bool bool_val;
    symbol *symbol_ptr;
    node node;
    data_type type;
    array_type array_info;
    direction direction;
    if_info if_info;
    for_info for_info;
    while_info while_info;
    function_head function_head;
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

%token FN_MICROEX
%token RETURN_MICROEX
%token ENDFN_MICROEX

%type <type> type
%type <symbol_ptr> program_title
%type <symbol_ptr> id_list
%type <symbol_ptr> id
%type <array_info> array_dimension
%type <array_info> array_dimension_list
%type <node> expression
%type <node> expression_list
%type <direction> direction
%type <if_info> if_prefix
%type <if_info> if_else_prefix
%type <for_info> for_prefix
%type <while_info> while_prefix
%type <symbol_ptr> arg
%type <symbol_ptr> arg_list
%type <function_head> function_statement_head

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
        generate("%s%s:\n", TEMP_DECLARE_LABEL, $1->name);
        symbol *current_symbol, *next_symbol;
        HASH_ITER(hh, temp_symbol_table, current_symbol, next_symbol) {
            generate("DECLARE %s %s\n", current_symbol->name, data_type_to_string(current_symbol->type));
        }
        generate("J %s%s\n", START_LABEL, $1->name);

        generate("\n");

        generate("HALT %s\n", $1->name);
        logging("> program -> program_title program_body\n");
        logging("\t> Program done with name: `%s`\n", $1->name);
    }
    ;
program_title:
    PROGRAM_MICROEX ID_MICROEX {
        $2->type = TYPE_PROGRAM_NAME;
        $$ = $2;
        generate("START %s\n", $2->name);
        add_comment("declare all usaged temp variable");
        generate("J %s%s\n", TEMP_DECLARE_LABEL, $2->name);
        generate("%s%s:\n", START_LABEL, $2->name);
        logging("> program_title -> program id (program_title -> program %s)\n", $2->name);
        logging("\t> Program start with name: `%s`\n", $2->name);
        
        generate("\n");
    }
    ;
program_body:
    BEGIN_MICROEX statement_list END_MICROEX {
        logging("> program_body -> begin statement_list end\n");
    }
    ;
statement_list:
    statement {
        logging("> statement_list -> statement\n");
    }
    | statement_list statement {
        logging("> statement_list -> statement_list statement\n");
    }
    ;
statement:
    declare_statement {
        logging("> statement -> declare_statement\n");
    }
    | assignment_statement {
        logging("> statement -> assignment_statement\n");
    }
    | read_statement {
        logging("> statement -> read_statement\n");
    }
    | write_statement {
        logging("> statement -> write_statement\n");
    }
    | if_statement {
        logging("> statement -> if_statement\n");
    }
    | for_statement {
        logging("> statement -> for_statement\n");
    }
    | while_statement {
        logging("> statement -> while_statement\n");
    }
    | function_statement {
        logging("> statement -> function_statement\n");
    }
    ;

// function declare statement
function_statement:
    function_statement_prefix statement_list RETURN_MICROEX expression SEMICOLON_MICROEX ENDFN_MICROEX {
        function_statement_process(&$4);

        logging("> function_statement -> function_statement_prefix statement_list RETURN expression SEMICOLON FNEND\n");
        
        generate("\n");
    }
    | function_statement_prefix RETURN_MICROEX expression SEMICOLON_MICROEX ENDFN_MICROEX {
        function_statement_process(&$3);

        logging("> function_statement -> function_statement_prefix RETURN expression SEMICOLON FNEND\n");
        
        generate("\n");
    }
    ;
function_statement_prefix:
    function_statement_head RIGHT_PARENT_MICROEX {
        char *type_str = data_type_to_string($1.return_type);
        logging("> function_statement_prefix -> function_statement_head RIGHT_PARENT (function_statement_prefix -> fn %s %s ())\n", type_str, $1.symbol_ptr->name);
        free(type_str);
        function_prefix_process($1);
    }
    | function_statement_head arg_list RIGHT_PARENT_MICROEX {
        size_t args_name_len = 1; // start with 1 for null terminator
        node *current = arg_list.head;
        while (current != NULL) {
            args_name_len += strlen(current->symbol_ptr->name) + DTYPE_NAME_LEN + 1;
            // for type_str
            if (current->next != NULL) {
                args_name_len += 2; // for ", "
            }
            current = current->next;
        }

        reallocable_char args_name = {
            .str = (char *)malloc(sizeof(char) * args_name_len), 
            .capacity = args_name_len
        };
        if (args_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        args_name.str[0] = '\0';
        char *type_str = NULL;
        current = arg_list.head;
        while (current != NULL) {
            if (args_name.str[0] != '\0') {
                strcat(args_name.str, ", ");
            }
            type_str = data_type_to_string(current->symbol_ptr->type);
            strcat(args_name.str, type_str);
            free(type_str);
            strcat(args_name.str, " ");
            strcat(args_name.str, current->symbol_ptr->name);
            if (current->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->array_pointer);
                if (!realloc_char(&args_name, args_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(args_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }

        type_str = data_type_to_string($1.return_type);
        logging("> function_statement_prefix -> function_statement_head RIGHT_PARENT (function_statement_prefix -> fn %s %s (%s))\n", type_str, $1.symbol_ptr->name, args_name.str);
        free(args_name.str);
        free(type_str);
        function_prefix_process($1);
    }
    ;
function_statement_head:
    FN_MICROEX type ID_MICROEX LEFT_PARENT_MICROEX {
        if (current_function_info != NULL) {
            yyerror("Nested function is not allowed.");
        }

        if ($3->type != TYPE_UNKNOWN) {
            yyerror_name("Symbol already declared.", "Redeclaration");
        }
        
        $3->type = TYPE_FUNCTION;
        $3->function_info = (function_info *)malloc(sizeof(function_info));
        if ($3->function_info == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }

        current_function_info = $3->function_info;
        current_function_info->name = $3->name;

        $$.return_type = $2;
        $$.symbol_ptr = $3;
        char *type_str = data_type_to_string($2);
        logging("> function_statement_head -> FN type ID LEFT_PARENT (function_statement_head -> fn %s %s ()\n", type_str, $3->name);
        free(type_str);
    }
    ;
arg_list:
    arg {
        $$ = $1;
        add_arg_node($1);
        $1->array_pointer = empty_array_info();

        char *type_str = data_type_to_string($1->type);
        logging("> arg_list -> arg (arg_list -> %s %s)\n", type_str, $1->name);
        free(type_str);
    }
    | arg_list COMMA_MICROEX arg {
        $$ = $1;
        add_arg_node($3);
        $3->array_pointer = empty_array_info();

        size_t args_name_len = 1; // start with 1 for null terminator
        node *current = arg_list.head;
        while (current != NULL) {
            args_name_len += strlen(current->symbol_ptr->name) + DTYPE_NAME_LEN + 1;
            // for type_str
            if (current->next != NULL) {
                args_name_len += 2; // for ", "
            }
            current = current->next;
        }

        reallocable_char args_name = {
            .str = (char *)malloc(sizeof(char) * args_name_len), 
            .capacity = args_name_len
        };
        if (args_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        args_name.str[0] = '\0';
        char *type_str = NULL;
        current = arg_list.head;
        while (current != NULL) {
            if (args_name.str[0] != '\0') {
                strcat(args_name.str, ", ");
            }
            type_str = data_type_to_string(current->symbol_ptr->type);
            strcat(args_name.str, type_str);
            free(type_str);
            strcat(args_name.str, " ");
            strcat(args_name.str, current->symbol_ptr->name);
            if (current->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->array_pointer);
                if (!realloc_char(&args_name, args_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(args_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        logging("> arg_list -> arg_list comma arg (arg_list -> %s)\n", args_name.str);
        free(args_name.str);
    }
    ;
arg:
    type id {
        $$ = $2;

        $$->type = $1;
        char *type_str = data_type_to_string($$->type);
        if ($$->array_pointer.dimensions == 0) {
            logging("> arg -> type id (arg -> %s %s)\n", type_str, $$->name);
        }
        else {
            dimensions = array_dimensions_to_string($$->array_pointer);
            logging("> arg -> type id (arg -> %s %s%s)\n", type_str, $$->name, dimensions);
            free(dimensions);
        }
        free(type_str);
    }
    ;

// declare statement
declare_statement:
    DECLARE_MICROEX id_list AS_MICROEX type SEMICOLON_MICROEX {
        node *current = id_list.head;
        size_t ids_name_len = 1; // start with 1 for null terminator
        while (current != NULL) {
            if (current->symbol_ptr->type != TYPE_UNKNOWN) {
                if (current_function_info == NULL) {
                    yyerror_name("Variable already declared.", "Redeclaration");
                }
                else {
                    // shawdow global variable
                    symbol *tmp = add_function_symbol(current->symbol_ptr->name);
                    tmp->type = current->symbol_ptr->type;
                    tmp->array_pointer = current->array_pointer;
                    tmp->is_static_checkable = true;

                    current->symbol_ptr = tmp;
                }
            }
            current->symbol_ptr->type = $4;
            if (current->array_pointer.dimensions > 0) {
                if (current->array_pointer.is_static_checkable) {
                    for (size_t i = 0; i < current->array_pointer.dimensions; i++) {
                        if (current->array_pointer.dimension_sizes[i] <= 0) {
                            yyerror_name("Array dimension must be greater than 0 when declaring.", "Index");
                        }
                    }
                }
                else {
                    yyerror_name("Array dimension must be static checkable when declaring.", "Compile");
                }
                char *array_dimensions = array_range_to_string(current->array_pointer);
                char *type_str = data_array_type_to_string($4);
                generate("DECLARE %s %s %s\n", current->symbol_ptr->name, type_str, array_dimensions);
                free(type_str);
                free(array_dimensions);
                copy_array_info(&(current->symbol_ptr->array_info), &(current->array_pointer));
                current->symbol_ptr->array_pointer = empty_array_info();

                size_t array_size = array_range(current->symbol_ptr->array_info);
                switch ($4) {
                    case TYPE_INT: {
                        current->symbol_ptr->value.int_array = (long long *)calloc(array_size, sizeof(long long));
                        if (current->symbol_ptr->value.int_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_size; i++) {
                            generate("I_STORE 0 %s[%zu]\n", current->symbol_ptr->name, i);
                        }
                        break;
                    }
                    case TYPE_DOUBLE: {
                        current->symbol_ptr->value.double_array = (double *)calloc(array_size, sizeof(double));
                        if (current->symbol_ptr->value.double_array == NULL) {
                            yyerror_name("Out of memory when calloc.", "Parsing");
                        }
                        for (size_t i = 0; i < array_size; i++) {
                            generate("F_STORE 0.0 %s[%zu]\n", current->symbol_ptr->name, i);
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
                            generate("I_STORE 0 %s[%zu]\n", current->symbol_ptr->name, i);
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
                generate("DECLARE %s %s\n", current->symbol_ptr->name, type_str);
                free(type_str);

                switch ($4) {
                    case TYPE_INT: {
                        current->symbol_ptr->value.int_val = 0;
                        generate("I_STORE 0 %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        current->symbol_ptr->value.double_val = 0.0;
                        generate("F_STORE 0.0 %s\n", current->symbol_ptr->name);
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
                        generate("I_STORE 0 %s\n", current->symbol_ptr->name);
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
                if (!realloc_char(&ids_name, ids_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(ids_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        char *type_str = data_type_to_string($4);
        logging("> declare_statement -> declare id_list as type semicolon (declare_statement -> declare %s as %s;)\n", ids_name.str, type_str);
        free(type_str);
        free(ids_name.str);
        
        free_id_list();

        generate("\n");
    }
    ;
id_list:
    id {
        $$ = $1;
        add_id_node($1);
        if ($1->array_pointer.dimensions > 0) {
            dimensions = array_dimensions_to_string($1->array_pointer);
            logging("> id_list -> id (id_list -> %s%s)\n", $1->name, dimensions);
            free(dimensions);
        }
        else {
            logging("> id_list -> id (id_list -> %s)\n", $1->name);
        }

        $1->array_pointer = empty_array_info();
    }
    | id_list COMMA_MICROEX id {
        $$ = $1;
        add_id_node($3);
        $3->array_pointer = empty_array_info();

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
            if (current->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->array_pointer);
                if (!realloc_char(&ids_name, ids_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(ids_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        logging("> id_list -> id_list comma id (id_list -> %s)\n", ids_name.str);
        free(ids_name.str);
    }
    ;
id:
    ID_MICROEX {
        $$ = $1;
        $1->array_pointer = empty_array_info();

        logging("> id -> ID (id -> %s)\n", $1->name);
    }
    | ID_MICROEX array_dimension_list {
        $$ = $1;
        $$->array_pointer = $2;
        dimensions = array_dimensions_to_string($2);
        logging("> id -> ID array_dimension_list (id -> %s%s)\n", $1->name, dimensions);
        free(dimensions);

        $$->is_static_checkable = $2.is_static_checkable; // propagate static checkability
    }
    ;
array_dimension:
    LEFT_BRACKET_MICROEX expression RIGHT_BRACKET_MICROEX {
        if($2.symbol_ptr->array_info.dimensions > 0 && $2.array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }

        $2.symbol_ptr = extract_array_symbol($2.symbol_ptr);
        
        if ($2.symbol_ptr->type != TYPE_INT && $2.symbol_ptr->type != TYPE_BOOL) {
            yyerror_name("Array dimension must be integer greater euqal than 0.", "Index");
        }
        symbol *temp_symbol = $2.symbol_ptr;
        if ($2.symbol_ptr->type == TYPE_BOOL) {
            // add temporary symbol to make sure array index semantic record always has type int
            temp_symbol = add_temp_symbol(TYPE_INT);
            temp_symbol->value.int_val = $2.symbol_ptr->value.bool_val ? 1 : 0; // convert bool to int
            temp_symbol->is_static_checkable = $2.symbol_ptr->is_static_checkable; // propagate static checkability
            generate("I_STORE %s %s\n", $2.symbol_ptr->name, temp_symbol->name);
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

        $$.dimension_sizes[$$.dimensions - 1] = 0; // non-static checkable dimension, set to 0
        $$.dimension_sizes_symbol[$$.dimensions - 1] = temp_symbol; // store the symbol for non-static checkable dimension
        if (temp_symbol->is_static_checkable) {
            $$.dimension_sizes[$$.dimensions - 1] = temp_symbol->value.int_val;
            logging("> array_dimension -> LEFT_BRACKET expression RIGHT_BRACKET (array_dimension -> [%lld])\n", temp_symbol->value.int_val);
        }
        else {
            logging("> array_dimension -> LEFT_BRACKET expression RIGHT_BRACKET (array_dimension -> [%s])\n", temp_symbol->name);
        }

        $$.is_static_checkable = temp_symbol->is_static_checkable; // propagate static checkability
    }
    ;
array_dimension_list:
    array_dimension {
        $$ = $1;

        if ($1.is_static_checkable) {
            logging("> array_dimension_list -> array_dimension (array_dimension_list -> [%zu])\n", $1.dimension_sizes[0]);
        }
        else {
            logging("> array_dimension_list -> array_dimension (array_dimension_list -> [%s])\n", $1.dimension_sizes_symbol[0]->name);
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
        logging("> array_dimension_list -> array_dimension_list array_dimension (array_dimension_list -> %s)\n", dimensions);
        free(dimensions);

        $$.is_static_checkable = $1.is_static_checkable && $2.is_static_checkable; // propagate static checkability
    }
    ;

type:
    INTEGER_MICROEX {
        $$ = $1;
        logging("> type -> INTEGER\n");
    }
    | REAL_MICROEX {
        $$ = $1;
        logging("> type -> REAL\n");
    }
    | BOOL_MICROEX {
        $$ = $1;
        logging("> type -> BOOL\n");
    }
    // This bad body is too difficult to implement,
    // so we currently do not support string and won't generate code for it.
    | STRING_MICROEX {
        // TODO: implement STRING type if have time
        $$ = $1;
        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
        logging("> type -> STRING\n");
    }
    ;
// assignment statement
assignment_statement:
    id ASSIGN_MICROEX expression SEMICOLON_MICROEX {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Variable not declared.", "Undeclared");
        }
        if($1->array_info.dimensions > 0 && $1->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        if($3.symbol_ptr->array_info.dimensions > 0 && $3.array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        $3.symbol_ptr = extract_array_symbol($3.symbol_ptr);

        if ($1->array_pointer.dimensions > 0) { // Handle array assignment
            symbol *offset = get_array_offset($1->array_info, $1->array_pointer);
            switch ($1->type) {
                case TYPE_INT: {
                    if ($3.symbol_ptr->type != TYPE_INT && $3.symbol_ptr->type != TYPE_DOUBLE && $3.symbol_ptr->type != TYPE_BOOL) {
                        yyerror_name("Cannot assign non-numeric value to integer array.", "Type");
                    }
                    switch ($3.symbol_ptr->type) {
                        case TYPE_INT: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.int_array[offset->value.int_val] = $3.symbol_ptr->value.int_val;
                            }
                            // we won't do any semantic propogation here, since we are not sure about the real array offset
                            generate("I_STORE %s %s[%s]\n", $3.symbol_ptr->name, $1->name, offset->name);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3.symbol_ptr->value.int_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.int_val);
                            }
                            free(dimensions);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.int_array[offset->value.int_val] = $3.symbol_ptr->value.double_val;
                            }
                            // we won't do any semantic propogation here, since we are not sure about the real array offset
                            generate("F_TO_I %s %s[%s]\n", $3.symbol_ptr->name, $1->name, offset->name);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3.symbol_ptr->value.double_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.double_val);
                            }
                            free(dimensions);
                            break;
                        }
                        case TYPE_BOOL: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.int_array[offset->value.int_val] = $3.symbol_ptr->value.bool_val;
                            }
                            // we won't do any semantic propogation here, since we are not sure about the real array offset
                            generate("I_STORE %s %s[%s]\n", $3.symbol_ptr->name, $1->name, offset->name);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
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
                    if ($3.symbol_ptr->type != TYPE_DOUBLE && $3.symbol_ptr->type != TYPE_INT && $3.symbol_ptr->type != TYPE_BOOL) {
                        yyerror_name("Cannot assign non-numeric value to double array.", "Type");
                    }
                    switch ($3.symbol_ptr->type) {
                        case TYPE_DOUBLE: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.double_array[offset->value.int_val] = $3.symbol_ptr->value.double_val;
                            }
                            // we won't do any semantic propogation here, since we are not sure about the real array offset
                            generate("F_STORE %s %s[%s]\n", $3.symbol_ptr->name, $1->name, offset->name);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3.symbol_ptr->value.double_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.double_val);
                            }
                            free(dimensions);
                            break;
                        }
                        case TYPE_INT: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.double_array[offset->value.int_val] = $3.symbol_ptr->value.int_val;
                            }
                            // we won't do any semantic propogation here, since we are not sure about the real array offset
                            generate("I_TO_F %s %s[%s]\n", $3.symbol_ptr->name, $1->name, offset->name);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3.symbol_ptr->value.int_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.int_val);
                            }
                            free(dimensions);
                            break;
                        }
                        case TYPE_BOOL: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.double_array[offset->value.int_val] = $3.symbol_ptr->value.bool_val;
                            }
                            // we won't do any semantic propogation here, since we are not sure about the real array offset
                            generate("I_TO_F %s %s[%s]\n", $3.symbol_ptr->name, $1->name, offset->name);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
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
                    if ($3.symbol_ptr->type != TYPE_STRING) {
                        yyerror_name("Cannot assign non-string value to string array.", "Type");
                    }
                    // we won't do any semantic propogation here, since we are not sure about the real array offset
                    yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                    
                    dimensions = array_dimensions_to_string($1->array_pointer);
                    logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := \"%s\";)\n", $1->name, dimensions, $3.symbol_ptr->value.str_val);
                    if (!$3.symbol_ptr->is_static_checkable) {
                        logging("\t> %s = \"%s\" is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.str_val);
                    }
                    free(dimensions);
                    break;
                }
                case TYPE_BOOL: {
                    if ($3.symbol_ptr->type != TYPE_BOOL && $3.symbol_ptr->type != TYPE_INT && $3.symbol_ptr->type != TYPE_DOUBLE) {
                        yyerror_name("Cannot assign non-boolean value to boolean array.", "Type");
                    }
                    switch ($3.symbol_ptr->type) {
                        case TYPE_BOOL: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.bool_array[offset->value.int_val] = $3.symbol_ptr->value.bool_val;
                            }
                            // we won't do any semantic propogation here, since we are not sure about the real array offset
                            generate("I_STORE %s %s[%s]\n", $3.symbol_ptr->name, $1->name, offset->name);
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %s;)\n", $1->name, dimensions, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            }
                            free(dimensions);
                            break;
                        }
                        case TYPE_INT: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.bool_array[offset->value.int_val] = $3.symbol_ptr->value.int_val;
                            }
                            itob_array($3.symbol_ptr, $1, offset);

                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %lld;)\n", $1->name, dimensions, $3.symbol_ptr->value.int_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.int_val);
                            }
                            free(dimensions);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            if ($1->array_pointer.is_static_checkable) {
                                $1->value.bool_array[offset->value.int_val] = $3.symbol_ptr->value.double_val;
                            }
                            ftob_array($3.symbol_ptr, $1, offset);
                            
                            dimensions = array_dimensions_to_string($1->array_pointer);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s%s := %g;)\n", $1->name, dimensions, $3.symbol_ptr->value.double_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.double_val);
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
        else { // Handle normal variable assignment
            switch ($1->type) {
                case TYPE_INT: {
                    if ($3.symbol_ptr->type != TYPE_INT && $3.symbol_ptr->type != TYPE_DOUBLE && $3.symbol_ptr->type != TYPE_BOOL) {
                        yyerror_name("Cannot assign non-numeric value to integer variable.", "Type");
                    }
                    switch ($3.symbol_ptr->type) {
                        case TYPE_INT: {
                            $1->value.int_val = $3.symbol_ptr->value.int_val;
                            generate("I_STORE %s %s\n", $3.symbol_ptr->name, $1->name);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3.symbol_ptr->value.int_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.int_val);
                            }
                            break;
                        }
                        case TYPE_DOUBLE: {
                            $1->value.int_val = (long long) $3.symbol_ptr->value.double_val;
                            generate("F_TO_I %s %s\n", $3.symbol_ptr->name, $1->name);
                            
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3.symbol_ptr->value.double_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.double_val);
                            }
                            break;
                        }
                        case TYPE_BOOL: {
                            $1->value.int_val = $3.symbol_ptr->value.bool_val ? 1 : 0; // convert bool to int
                            generate("I_STORE %s %s\n", $3.symbol_ptr->name, $1->name);

                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %s;)\n", $1->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
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
                    if ($3.symbol_ptr->type != TYPE_DOUBLE && $3.symbol_ptr->type != TYPE_INT && $3.symbol_ptr->type != TYPE_BOOL) {
                        yyerror_name("Cannot assign non-numeric value to double variable.", "Type");
                    }
                    switch ($3.symbol_ptr->type) {
                        case TYPE_DOUBLE: {
                            $1->value.double_val = $3.symbol_ptr->value.double_val;
                            generate("F_STORE %s %s\n", $3.symbol_ptr->name, $1->name);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3.symbol_ptr->value.double_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.double_val);
                            }
                            break;
                        }
                        case TYPE_INT: {
                            $1->value.double_val = (double) $3.symbol_ptr->value.int_val;
                            generate("I_TO_F %s %s\n", $3.symbol_ptr->name, $1->name);
                            
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3.symbol_ptr->value.int_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.int_val);
                            }
                            break;
                        }
                        case TYPE_BOOL: {
                            $1->value.double_val = $3.symbol_ptr->value.bool_val ? 1.0 : 0.0;
                            generate("I_TO_F %s %s\n", $3.symbol_ptr->name, $1->name);
                            
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %s;)\n", $1->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
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
                    if ($3.symbol_ptr->type != TYPE_STRING) {
                        yyerror_name("Cannot assign non-string value to string variable.", "Type");
                    }
                    $1->value.str_val = (char *)realloc($1->value.str_val, strlen($3.symbol_ptr->value.str_val) + 1);
                    if ($1->value.str_val == NULL) {
                        yyerror_name("Out of memory when realloc.", "Parsing");
                    }
                    strcpy($1->value.str_val, $3.symbol_ptr->value.str_val);
                    yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                    
                    logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := \"%s\";)\n", $1->name, $3.symbol_ptr->value.str_val);
                    if (!$3.symbol_ptr->is_static_checkable) {
                        logging("\t> %s = \"%s\" is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.str_val);
                    }
                    break;
                }
                case TYPE_BOOL: {
                    if ($3.symbol_ptr->type != TYPE_BOOL && $3.symbol_ptr->type != TYPE_INT && $3.symbol_ptr->type != TYPE_DOUBLE) {
                        yyerror_name("Cannot assign non-boolean value to boolean variable.", "Type");
                    }
                    switch ($3.symbol_ptr->type) {
                        case TYPE_BOOL: {
                            $1->value.bool_val = $3.symbol_ptr->value.bool_val;
                            generate("I_STORE %s %s\n", $3.symbol_ptr->name, $1->name);
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %s;)\n", $1->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
                            }
                            break;
                        }
                        case TYPE_INT: {
                            int_to_bool($3.symbol_ptr, $1);
                            
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %lld;)\n", $1->name, $3.symbol_ptr->value.int_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.int_val);
                            }
                            break;
                        }
                        case TYPE_DOUBLE: {
                            double_to_bool($3.symbol_ptr, $1);
                            
                            logging("> assignment_statement -> id ASSIGN expression semicolon (assignment -> %s := %g;)\n", $1->name, $3.symbol_ptr->value.double_val);
                            if (!$3.symbol_ptr->is_static_checkable) {
                                logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.double_val);
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

        $1->is_static_checkable = $3.symbol_ptr->is_static_checkable && $1->array_pointer.is_static_checkable; 
        // propagate static checkability
        // if array_pointer is not static checkable, then the whole assignment is not static checkable
        
        generate("\n");
    }
    ;
expression:
    expression PLUS_MICROEX expression {
        $$ = operator_process(&$1, PLUS_MICROEX, &$3);
    }
    | expression MINUS_MICROEX expression {
        $$ = operator_process(&$1, MINUS_MICROEX, &$3);
    }
    | expression MULTIPLY_MICROEX expression {
        $$ = operator_process(&$1, MULTIPLY_MICROEX, &$3);
    }
    | expression DIVISION_MICROEX expression {
        $$ = operator_process(&$1, DIVISION_MICROEX, &$3);
    }
    | MINUS_MICROEX expression %prec UMINUS_MICROEX {
        if($2.symbol_ptr->array_info.dimensions > 0 && $2.array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        
        $2.symbol_ptr = extract_array_symbol($2.symbol_ptr);

        switch ($2.symbol_ptr->type) {
            case TYPE_INT: {
                $$.symbol_ptr = add_temp_symbol(TYPE_INT);
                $$.symbol_ptr->value.int_val = -$2.symbol_ptr->value.int_val;
                generate("I_UMINUS %s %s\n", $2.symbol_ptr->name, $$.symbol_ptr->name);
                logging("> expression -> MINUS expression (expression -> %lld)\n", $$.symbol_ptr->value.int_val);

                $$.symbol_ptr->is_static_checkable = $2.symbol_ptr->is_static_checkable; // propagate static checkability
                break;
            }
            case TYPE_DOUBLE: {
                $$.symbol_ptr = add_temp_symbol(TYPE_DOUBLE);
                $$.symbol_ptr->value.double_val = -$2.symbol_ptr->value.double_val;
                generate("F_UMINUS %s %s\n", $2.symbol_ptr->name, $$.symbol_ptr->name);
                logging("> expression -> MINUS expression (expression -> %g)\n", $$.symbol_ptr->value.double_val);

                $$.symbol_ptr->is_static_checkable = $2.symbol_ptr->is_static_checkable; // propagate static checkability
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
                $$.symbol_ptr = add_temp_symbol(TYPE_INT);
                $$.symbol_ptr->value.int_val = -$2.symbol_ptr->value.bool_val;
                generate("I_UMINUS %s %s\n", $2.symbol_ptr->name, $$.symbol_ptr->name);
                logging("> expression -> MINUS expression (expression -> -%s)\n", $2.symbol_ptr->value.bool_val ? "true" : "false");

                $$.symbol_ptr->is_static_checkable = $2.symbol_ptr->is_static_checkable; // propagate static checkability
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$.array_pointer = empty_array_info();
        $$.next = NULL;

        $$.symbol_ptr->is_static_checkable = $2.symbol_ptr->is_static_checkable; // propagate static checkability
    }
    | LEFT_PARENT_MICROEX expression RIGHT_PARENT_MICROEX {
        $$ = $2;

        switch ($2.symbol_ptr->type) {
            case TYPE_INT: {
                logging("> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%lld))\n", $2.symbol_ptr->value.int_val);
                break;
            }
            case TYPE_DOUBLE: {
                logging("> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%g))\n", $2.symbol_ptr->value.double_val);
                break;
            }
            case TYPE_STRING: {
                logging("> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%s))\n", $2.symbol_ptr->value.str_val);
                break;
            }
            case TYPE_BOOL: {
                logging("> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%s))\n", $2.symbol_ptr->value.bool_val ? "true" : "false");
                break;
            }
            case TYPE_PROGRAM_NAME: {
                logging("> expression -> LEFT_PARENT expression RIGHT_PARENT (expression -> (%s))\n", $2.symbol_ptr->name);
                break;
            }
            default: {
                yyerror_name("Unknown data type in expression.", "Parsing");
                break;
            }
        }

        $$.array_pointer = empty_array_info();
        $$.next = NULL;
        // since propagate static checkability inherited from $2, so we don't need to set it again
    }
    | expression GREAT_MICROEX expression {
        $$ = condition_process(&$1, GREAT_MICROEX, &$3).result_node;
    }
    | expression LESS_MICROEX expression {
        $$ = condition_process(&$1, LESS_MICROEX, &$3).result_node;
    }
    | expression GREAT_EQUAL_MICROEX expression {
        $$ = condition_process(&$1, GREAT_EQUAL_MICROEX, &$3).result_node;
    }
    | expression LESS_EQUAL_MICROEX expression {
        $$ = condition_process(&$1, LESS_EQUAL_MICROEX, &$3).result_node;
    }
    | expression EQUAL_MICROEX expression {
        $$ = condition_process(&$1, EQUAL_MICROEX, &$3).result_node;
    }
    | expression NOT_EQUAL_MICROEX expression {
        $$ = condition_process(&$1, NOT_EQUAL_MICROEX, &$3).result_node;
    }
    | expression AND_MICROEX expression {
        $$ = condition_process(&$1, AND_MICROEX, &$3).result_node;
    }
    | expression OR_MICROEX expression {
        $$ = condition_process(&$1, OR_MICROEX, &$3).result_node;
    }
    | NOT_MICROEX expression {
        if($2.symbol_ptr->array_info.dimensions > 0 && $2.array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        
        $$.symbol_ptr = add_temp_symbol(TYPE_BOOL);
        $2.symbol_ptr = extract_array_symbol($2.symbol_ptr);

        switch ($2.symbol_ptr->type) {
            case TYPE_BOOL: {
                $$.symbol_ptr->value.bool_val = !$2.symbol_ptr->value.bool_val;
                generate("NOT %s %s\n", $2.symbol_ptr->name, $$.symbol_ptr->name);
                logging("> expression -> NOT expression (expression -> !%s)\n", $2.symbol_ptr->value.bool_val ? "true" : "false");
                break;
            }
            case TYPE_INT: {
                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                int_to_bool($2.symbol_ptr, temp_symbol);
                $$.symbol_ptr->value.bool_val = !temp_symbol->value.bool_val;
                generate("NOT %s %s\n", temp_symbol->name, $$.symbol_ptr->name);
                logging("> expression -> NOT expression (expression -> !%lld)\n", $2.symbol_ptr->value.int_val);
                break;
            }
            case TYPE_DOUBLE: {
                symbol *temp_symbol = add_temp_symbol(TYPE_BOOL);
                double_to_bool($2.symbol_ptr, temp_symbol);
                $$.symbol_ptr->value.bool_val = !temp_symbol->value.bool_val;
                generate("NOT %s %s\n", temp_symbol->name, $$.symbol_ptr->name);
                logging("> expression -> NOT expression (expression -> !%g)\n", $2.symbol_ptr->value.double_val);
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

        $$.next = NULL;
        $$.array_pointer = empty_array_info();

        $$.symbol_ptr->is_static_checkable = $2.symbol_ptr->is_static_checkable; // propagate static checkability
    }
    | id {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Variable not declared.", "Undeclared");
        }

        $$.next = NULL;
        $$.array_pointer = $1->array_pointer;
        $1->array_pointer = empty_array_info();

        $$.symbol_ptr = $1;

        if ($$.array_pointer.dimensions > 0) {
            dimensions = array_dimensions_to_string($$.array_pointer);
            logging("> expression -> id (expression -> %s%s)\n", $1->name, dimensions);
            free(dimensions);
        }
        else {
            logging("> expression -> id (expression -> %s)\n", $1->name);
        }
    }
    // function call
    | ID_MICROEX LEFT_PARENT_MICROEX expression_list RIGHT_PARENT_MICROEX {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Function not declared.", "Undeclared");
        }
        char *tmp;
        if ($1->type != TYPE_FUNCTION) {
            tmp = (char *)malloc(sizeof(char) * (strlen($1->name) + 20));
            if (tmp == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            tmp[0] = '\0';
            sprintf(tmp, "%s is not a function.", $1->name);
            yyerror_name(tmp, "Type");
        }
        if ($1->function_info->argc != expression_list.len) {
            tmp = (char *)malloc(sizeof(char) * (41 + 2 * SIZE_T_CHARLEN));
            if (tmp == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            tmp[0] = '\0';
            sprintf(tmp, "Unexcept number of args, except %zu, got %zu", $1->function_info->argc, expression_list.len);
            yyerror_name(tmp, "ArgsNumbers");
        }

        $$.symbol_ptr = add_temp_symbol($1->function_info->return_arg->type);
        size_t i = 0;
        size_t exprs_name_len = 1; // start with 1 for null terminator
        node *current = expression_list.head;
        while (current != NULL) {
            if ($1->function_info->args[i]->type != current->symbol_ptr->type) {
                char *type1 = data_type_to_string($1->function_info->args[i]->type);
                char *type2 = data_type_to_string(current->symbol_ptr->type);
                tmp = (char *)malloc(sizeof(char) * (48 + strlen(type1) + strlen(type2) + SIZE_T_CHARLEN));
                if (tmp == NULL) {
                    yyerror_name("Out of memory when malloc.", "Parsing");
                }
                tmp[0] = '\0';
                sprintf(tmp, "Args at position %zu except type %s, but got %s.", i, type1, type2);
                yyerror_name(tmp, "Type");
            }
            if ($1->function_info->args[i]->array_info.dimensions > 0 && current->symbol_ptr->array_pointer.dimensions > 0) {
                tmp = (char *)malloc(sizeof(char) * (71 + SIZE_T_CHARLEN));
                if (tmp == NULL) {
                    yyerror_name("Out of memory when malloc.", "Parsing");
                }
                tmp[0] = '\0';
                sprintf(tmp, "Args at position %zu except array symbol, but got array access variable.", i);
                yyerror_name(tmp, "Type");
            }
            if ($1->function_info->args[i]->array_info.dimensions > 0 && current->symbol_ptr->array_info.dimensions == 0) {
                tmp = (char *)malloc(sizeof(char) * (69 + SIZE_T_CHARLEN));
                if (tmp == NULL) {
                    yyerror_name("Out of memory when malloc.", "Parsing");
                }
                tmp[0] = '\0';
                sprintf(tmp, "Args at position %zu except array symbol, but got non-array variable.", i);
                yyerror_name(tmp, "Type");
            }
            if ($1->function_info->args[i]->array_info.dimensions == 0 && current->symbol_ptr->array_info.dimensions > 0) {
                if (current->array_pointer.dimensions == 0) {
                    tmp = (char *)malloc(sizeof(char) * (69 + SIZE_T_CHARLEN));
                    if (tmp == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    tmp[0] = '\0';
                    sprintf(tmp, "Args at position %zu except non-array symbol, but got array symbol.", i);
                    yyerror_name(tmp, "Type");
                }
                else {
                    current->symbol_ptr = extract_array_symbol(current->symbol_ptr);
                }
            }

            if ($1->function_info->args[i]->array_info.dimensions > 0 && current->symbol_ptr->array_info.dimensions > 0) {
                char *dim1 = array_dimensions_to_string($1->function_info->args[i]->array_info);
                char *dim2 = array_dimensions_to_string(current->symbol_ptr->array_info);
                if ($1->function_info->args[i]->array_info.dimensions != current->symbol_ptr->array_info.dimensions || strcmp(dim1, dim2) != 0) {
                    tmp = (char *)malloc(sizeof(char) * (59 + SIZE_T_CHARLEN + strlen(dim1) + strlen(dim2)));
                    if (tmp == NULL) {
                        yyerror_name("Out of memory when malloc.", "Parsing");
                    }
                    tmp[0] = '\0';
                    sprintf(tmp, "Args at position %zu except array dimensions %s, but got %s", i, dim1, dim2);
                    yyerror_name(tmp, "Type");
                }
                
                // copy value to arg's array
                // all function now only call by value
                size_t max_index = array_range($1->function_info->args[i]->array_info);
                for (size_t index = 0; index < max_index; index++) {
                    switch (current->symbol_ptr->type) {
                        case TYPE_INT:
                        case TYPE_BOOL: {
                            if (current->symbol_ptr->type == TYPE_INT) {
                                $1->function_info->args[i]->value.int_array[index] = current->symbol_ptr->value.int_array[index];
                            }
                            else {
                                $1->function_info->args[i]->value.bool_array[index] = current->symbol_ptr->value.bool_array[index];
                            }
                            generate("I_STORE %s[%zu] %s[%zu]\n", current->symbol_ptr->name, index, $1->function_info->args[i]->name, index);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            $1->function_info->args[i]->value.double_array[index] = current->symbol_ptr->value.double_array[index];
                            generate("F_STORE %s[%zu] %s[%zu]\n", current->symbol_ptr->name, index, $1->function_info->args[i]->name, index);
                            break;
                        }
                        case TYPE_STRING: {
                            $1->function_info->args[i]->value.str_array[index] = (char *)realloc($1->function_info->args[i]->value.str_array[index], strlen(current->symbol_ptr->value.str_array[index]) + 1);
                            if ($1->function_info->args[i]->value.str_array[index] == NULL) {
                                yyerror_name("Out of memory when realloc.", "Parsing");
                            }
                            strcpy($1->function_info->args[i]->value.str_array[index], current->symbol_ptr->value.str_array[index]);
                            yyerror_warning_test_mode("STRING_LITERAL is not supported yet and won't generate code for it.", "Feature", true, true);
                            break;
                        }
                        case TYPE_PROGRAM_NAME:
                        case TYPE_FUNCTION:
                        default: {
                            yyerror_name("Impossible data type when parsing.", "Parsing");
                            break;
                        }
                    }
                }

                free(dim1);
                free(dim2);
            }
            else {
                switch (current->symbol_ptr->type) {
                    case TYPE_INT:
                    case TYPE_BOOL: {
                        if (current->symbol_ptr->type == TYPE_INT) {
                            $1->function_info->args[i]->value.int_val = current->symbol_ptr->value.int_val;
                        }
                        else {
                            $1->function_info->args[i]->value.bool_val = current->symbol_ptr->value.bool_val;
                        }
                        generate("I_STORE %s %s\n", current->symbol_ptr->name, $1->function_info->args[i]->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        $1->function_info->args[i]->value.double_val = current->symbol_ptr->value.double_val;
                        generate("F_STORE %s %s\n", current->symbol_ptr->name, $1->function_info->args[i]->name);
                        break;
                    }
                    case TYPE_STRING: {
                        $1->function_info->args[i]->value.str_val = (char *)realloc($1->function_info->args[i]->value.str_val, strlen(current->symbol_ptr->value.str_val) + 1);
                        if ($1->function_info->args[i]->value.str_val == NULL) {
                            yyerror_name("Out of memory when realloc.", "Parsing");
                        }
                        strcpy($1->function_info->args[i]->value.str_val, current->symbol_ptr->value.str_val);
                        yyerror_warning_test_mode("STRING_LITERAL is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    }
                    case TYPE_PROGRAM_NAME:
                    case TYPE_FUNCTION:
                    default: {
                        yyerror_name("Impossible data type when parsing.", "Parsing");
                        break;
                    }
                }
            }

            $1->function_info->args[i]->is_static_checkable = current->symbol_ptr->is_static_checkable;

            exprs_name_len += strlen(current->symbol_ptr->name);
            if (current->next != NULL) {
                exprs_name_len += 2; // for ", "
            }
            current = current->next;
            i++;
        }
        
        reallocable_char exprs_name = {
            .str = (char *)malloc(sizeof(char) * exprs_name_len), 
            .capacity = exprs_name_len
        };
        if (exprs_name.str == NULL) {
            yyerror_name("Out of memory when malloc.", "Parsing");
        }
        exprs_name.str[0] = '\0';
        current = expression_list.head;
        while (current != NULL) {
            if (exprs_name.str[0] != '\0') {
                strcat(exprs_name.str, ", ");
            }
            strcat(exprs_name.str, current->symbol_ptr->name);
            if (current->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->array_pointer);
                if (!realloc_char(&exprs_name, exprs_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(exprs_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }

        generate("CALL %s %s\n", $1->name, $$.symbol_ptr->name);
        logging("> expression -> ID LEFT_PARENT expression_list RIGHT_PARENT (expression -> %s(%s))\n", $1->name, exprs_name.str);
        free(exprs_name.str);

        free_expression_list();

        $$.next = NULL;
        $$.array_pointer = empty_array_info();

        $$.symbol_ptr->is_static_checkable = $1->function_info->return_arg->is_static_checkable; // propagate static checkability
    }
    | ID_MICROEX LEFT_PARENT_MICROEX RIGHT_PARENT_MICROEX {
        if ($1->type == TYPE_UNKNOWN) {
            yyerror_name("Function not declared.", "Undeclared");
        }
        char *tmp;
        if ($1->type != TYPE_FUNCTION) {
            tmp = (char *)malloc(sizeof(char) * (strlen($1->name) + 20));
            if (tmp == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            tmp[0] = '\0';
            sprintf(tmp, "%s is not a function.", $1->name);
            yyerror_name(tmp, "Type");
        }
        if ($1->function_info->argc != id_list.len) {
            tmp = (char *)malloc(sizeof(char) * (41 + 2 * SIZE_T_CHARLEN));
            if (tmp == NULL) {
                yyerror_name("Out of memory when malloc.", "Parsing");
            }
            tmp[0] = '\0';
            sprintf(tmp, "Unexcept number of args, except %zu, got %zu", $1->function_info->argc, id_list.len);
            yyerror_name(tmp, "ArgsNumbers");
        }

        $$.next = NULL;
        $$.array_pointer = empty_array_info();

        $$.symbol_ptr = add_temp_symbol($1->function_info->return_arg->type);
        generate("CALL %s %s\n", $1->name, $$.symbol_ptr->name);
        logging("> expression -> ID_MICROEX LEFT_PARENT_MICROEX RIGHT_PARENT_MICROEX (expression -> %s())\n", $1->name);

        $$.symbol_ptr->is_static_checkable = $1->function_info->return_arg->is_static_checkable; // propagate static checkability
    }
    | INTEGER_LITERAL_MICROEX {
        $$.symbol_ptr = add_temp_symbol(TYPE_INT);
        $$.symbol_ptr->value.int_val = $1;
        generate("I_STORE %lld %s\n", $1, $$.symbol_ptr->name);
        logging("> expression -> INTEGER_LITERAL (expression -> %lld)\n", $1);

        $$.symbol_ptr->is_static_checkable = true; // integer literals are always static checkable
    }
    | FLOAT_LITERAL_MICROEX {
        $$.symbol_ptr = add_temp_symbol(TYPE_DOUBLE);
        $$.symbol_ptr->value.double_val = $1;
        generate("F_STORE %g %s\n", $1, $$.symbol_ptr->name);
        logging("> expression -> FLOAT_LITERAL (expression -> %g)\n", $1);

        $$.symbol_ptr->is_static_checkable = true; // float literals are always static checkable
    }
    | EXP_FLOAT_LITERAL_MICROEX {
        $$.symbol_ptr = add_temp_symbol(TYPE_DOUBLE);
        $$.symbol_ptr->value.double_val = $1;
        generate("F_STORE %g %s\n", $1, $$.symbol_ptr->name);
        logging("> expression -> EXP_FLOAT_LITERAL (expression -> %g)\n", $1);

        $$.symbol_ptr->is_static_checkable = true; // exp float literals are always static checkable
    }
    // This bad body is too difficult to implement,
    // so we currently do not support string and won't generate code for it.
    | STRING_LITERAL_MICROEX {
        // TODO: implement STRING_LITERAL if have time
        $$.symbol_ptr = add_temp_symbol(TYPE_STRING);
        $$.symbol_ptr->value.str_val = $1; // $1 is a valid string by yytext
        yyerror_warning_test_mode("STRING_LITERAL is not supported yet and won't generate code for it.", "Feature", true, true);
        logging("> expression -> STRING_LITERAL (expression -> %s)\n", $1);

        $$.symbol_ptr->is_static_checkable = true; // string literals are always static checkable
    }
    | TRUE_LITERAL_MICROEX {
        $$.symbol_ptr = add_temp_symbol(TYPE_BOOL);
        $$.symbol_ptr->value.bool_val = true;
        generate("I_STORE 1 %s\n", $$.symbol_ptr->name);
        logging("> expression -> TRUE_LITERAL (expression -> true)\n");

        $$.symbol_ptr->is_static_checkable = true; // boolean literals are always static checkable
    }
    | FALSE_LITERAL_MICROEX {
        $$.symbol_ptr = add_temp_symbol(TYPE_BOOL);
        $$.symbol_ptr->value.bool_val = false;
        generate("I_STORE 0 %s\n", $$.symbol_ptr->name);
        logging("> expression -> FALSE_LITERAL (expression -> false)\n");

        $$.symbol_ptr->is_static_checkable = true; // boolean literals are always static checkable
    }
    ;
// read statement
read_statement:
    READ_MICROEX LEFT_PARENT_MICROEX id_list RIGHT_PARENT_MICROEX SEMICOLON_MICROEX {
        node *current = id_list.head;
        size_t ids_name_len = 1; // 1 for null terminator
        while (current != NULL) {
            if (current->symbol_ptr->type == TYPE_UNKNOWN) {
                yyerror_name("Variable not declared.", "Undeclared");
            }
            if (current->array_pointer.dimensions > 0) { // array access
                symbol *offset = get_array_offset(current->symbol_ptr->array_info, current->array_pointer);
                switch (current->symbol_ptr->type) {
                    case TYPE_INT: {
                        generate("CALL read_i %s[%s]\n", current->symbol_ptr->name, offset->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        generate("CALL read_f %s[%s]\n", current->symbol_ptr->name, offset->name);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    }
                    case TYPE_BOOL: {
                        generate("CALL read_b %s[%s]\n", current->symbol_ptr->name, offset->name);
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
                switch (current->symbol_ptr->type) {
                    case TYPE_INT: {
                        generate("CALL read_i %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        generate("CALL read_f %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
                        break;
                    }
                    case TYPE_BOOL: {
                        generate("CALL read_b %s\n", current->symbol_ptr->name);
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
            if (current->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->array_pointer);
                if (!realloc_char(&ids_name, ids_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(ids_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        logging("> read_statement -> read left_parent id_list right_parent semicolon (read_statement -> read(%s);)\n", ids_name.str);
        free(ids_name.str);
        free_id_list();
        
        generate("\n");
    }
    ;
// write statement
write_statement:
    WRITE_MICROEX LEFT_PARENT_MICROEX expression_list RIGHT_PARENT_MICROEX SEMICOLON_MICROEX {
        node *current = expression_list.head;
        size_t expressions_name_len = 1; // 1 for null terminator
        while (current != NULL) {
            if (current->symbol_ptr->type == TYPE_UNKNOWN) {
                yyerror_name("Variable not declared.", "Undeclared");
            }
            if(current->symbol_ptr->array_info.dimensions > 0 && current->array_pointer.dimensions == 0) {
                yyerror_name("Access non-array symbol with array symbol.", "Type");
            }
            if (current->array_pointer.dimensions > 0) {
                symbol *offset = get_array_offset(current->symbol_ptr->array_info, current->array_pointer);
                switch (current->symbol_ptr->type) {
                    case TYPE_BOOL:
                    case TYPE_INT: {
                        generate("CALL write_i %s[%s]\n", current->symbol_ptr->name, offset->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        generate("CALL write_f %s[%s]\n", current->symbol_ptr->name, offset->name);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
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
            }
            else {
                switch (current->symbol_ptr->type) {
                    case TYPE_BOOL:
                    case TYPE_INT: {
                        generate("CALL write_i %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_DOUBLE: {
                        generate("CALL write_f %s\n", current->symbol_ptr->name);
                        break;
                    }
                    case TYPE_STRING: {
                        yyerror_warning_test_mode("STRING type is not supported yet and won't generate code for it.", "Feature", true, true);
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
            if (current->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->array_pointer);
                if (!realloc_char(&expressions_name, expressions_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(expressions_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        logging("> write_statement -> write left_parent expression_list right_parent semicolon (write_statement -> write(%s);)\n", expressions_name.str);
        free(expressions_name.str);
        free_expression_list();
        
        generate("\n");
    }
    ;
expression_list:
    expression {
        $$ = $1;
        $1.symbol_ptr->array_pointer = $1.array_pointer;
        add_expression_node($1.symbol_ptr);
        $1.symbol_ptr->array_pointer = empty_array_info();

        if ($1.symbol_ptr->array_pointer.dimensions > 0) {
            dimensions = array_dimensions_to_string($1.symbol_ptr->array_pointer);
            logging("> expression_list -> expression (expression_list -> %s%s)\n", $1.symbol_ptr->name, dimensions);
            free(dimensions);
        }
        else {
            logging("> expression_list -> expression (expression_list -> %s)\n", $1.symbol_ptr->name);
        }
    }
    | expression_list COMMA_MICROEX expression {
        $$ = $1;

        $3.symbol_ptr->array_pointer = $3.array_pointer;
        add_expression_node($3.symbol_ptr);
        $3.symbol_ptr->array_pointer = empty_array_info();

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
            if (current->array_pointer.dimensions > 0) {
                dimensions = array_dimensions_to_string(current->array_pointer);
                if (!realloc_char(&expressions_name, expressions_name.capacity + strlen(dimensions) + 1)) {
                    // +1 for null terminator
                    yyerror_name("Out of memory when realloc.", "Parsing");
                }
                strcat(expressions_name.str, dimensions);
                free(dimensions);
            }
            current = current->next;
        }
        logging("> expression_list -> expression_list COMMA expression (expression_list -> %s)\n", expressions_name.str);
        free(expressions_name.str);
    }
    ;
// if statement
if_statement:
    if_prefix if_suffix {
        generate("%s:\n", $1.false_label->name); // false label for if condition isn't true
        generate("%s:\n", $1.end_label->name); // endif label for if statement going done
        logging("> if_statement -> if_prefix if_suffix\n");
        
        generate("\n");
    }
    | if_else_prefix if_suffix {
        generate("%s:\n", $1.end_label->name); // endif label for if statement going done
        logging("> if_statement -> if_else_prefix if_suffix\n");
        
        generate("\n");
    }
    ;
if_prefix:
    IF_MICROEX LEFT_PARENT_MICROEX expression RIGHT_PARENT_MICROEX THEN_MICROEX {
        if($3.symbol_ptr->array_info.dimensions > 0 && $3.array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }

        $3.symbol_ptr = extract_array_symbol($3.symbol_ptr);

        label *true_label = add_label();
        label *false_label = add_label();
        label *end_label = add_label();

        $$.true_label = true_label;
        $$.false_label = false_label;
        $$.end_label = end_label;

        switch ($3.symbol_ptr->type) {
            case TYPE_INT:
            case TYPE_BOOL: {
                generate("I_CMP 0 %s\n", $3.symbol_ptr->name);
                generate("JNE %s\n", true_label->name);
                generate("J %s\n", false_label->name);
                generate("%s:\n", true_label->name);
                if ($3.symbol_ptr->type == TYPE_INT) {
                    logging("> if_prefix -> if left_parent expression right_parent then (if_prefix -> if (%lld) then)\n", $3.symbol_ptr->value.int_val);
                } else {
                    logging("> if_prefix -> if left_parent expression right_parent then (if_prefix -> if (%s) then)\n", $3.symbol_ptr->value.bool_val ? "true" : "false");
                }
                break;
            }
            case TYPE_DOUBLE: {
                generate("F_CMP 0.0 %s\n", $3.symbol_ptr->name);
                generate("JNE %s\n", true_label->name);
                generate("J %s\n", false_label->name);
                generate("%s:\n", true_label->name);
                logging("> if_prefix -> if left_parent expression right_parent then (if_prefix -> if (%g) then)\n", $3.symbol_ptr->value.double_val);
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
        $$ = $1;

        generate("J %s\n", $1.end_label->name); // jump to `endif` if condition is true
        generate("%s:\n", $1.false_label->name); // false label for if condition isn't true
        logging("> if_statement -> if_prefix statement_list else if_suffix\n");
    }
    ;
if_suffix:
    statement_list ENDIF_MICROEX {
        logging("> if_suffix -> statement_list endif\n");
    }
    ;

// for statement
for_statement:
    for_prefix statement_list ENDFOR_MICROEX {
        // increment/decrement the for variable
        if ($1.for_node.array_pointer.dimensions > 0) {
            symbol *offset = get_array_offset($1.for_node.symbol_ptr->array_info, $1.for_node.array_pointer);
            switch ($1.for_node.symbol_ptr->type) {
                case TYPE_INT: {
                    if ($1.for_direction == DIRECTION_TO) {
                        if ($1.for_node.array_pointer.is_static_checkable) {
                            $1.for_node.symbol_ptr->value.int_array[offset->value.int_val]++;
                        }
                        generate("INC %s[%s]\n", $1.for_node.symbol_ptr->name, offset->name);
                    }
                    else {
                        if ($1.for_node.array_pointer.is_static_checkable) {
                            $1.for_node.symbol_ptr->value.int_array[offset->value.int_val]--;
                        }
                        generate("DEC %s[%s]\n", $1.for_node.symbol_ptr->name, offset->name);
                    }
                    break;
                }
                case TYPE_DOUBLE: {
                    symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                    if ($1.for_direction == DIRECTION_TO) {
                        if ($1.for_node.array_pointer.is_static_checkable) {
                            $1.for_node.symbol_ptr->value.double_array[offset->value.int_val]++;
                        }
                        generate("F_ADD %s[%s] 1.0 %s\n", $1.for_node.symbol_ptr->name, offset->name, temp_symbol->name);
                    } else {
                        if ($1.for_node.array_pointer.is_static_checkable) {
                            $1.for_node.symbol_ptr->value.double_array[offset->value.int_val]--;
                        }
                        generate("F_SUB %s[%s] 1.0 %s\n", $1.for_node.symbol_ptr->name, offset->name, temp_symbol->name);
                    }
                    generate("F_STORE %s %s[%s]\n", temp_symbol->name, $1.for_node.symbol_ptr->name, offset->name);
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
            switch ($1.for_node.symbol_ptr->type) {
                case TYPE_INT: {
                    if ($1.for_direction == DIRECTION_TO) {
                        $1.for_node.symbol_ptr->value.int_val++;
                        generate("INC %s\n", $1.for_node.symbol_ptr->name);
                    }
                    else {
                        $1.for_node.symbol_ptr->value.int_val--;
                        generate("DEC %s\n", $1.for_node.symbol_ptr->name);
                    }
                    break;
                }
                case TYPE_DOUBLE: {
                    symbol *temp_symbol = add_temp_symbol(TYPE_DOUBLE);
                    if ($1.for_direction == DIRECTION_TO) {
                        $1.for_node.symbol_ptr->value.double_val++;
                        generate("F_ADD %s 1.0 %s\n", $1.for_node.symbol_ptr->name, temp_symbol->name);
                    } else {
                        $1.for_node.symbol_ptr->value.double_val--;
                        generate("F_SUB %s 1.0 %s\n", $1.for_node.symbol_ptr->name, temp_symbol->name);
                    }
                    generate("F_STORE %s %s\n", temp_symbol->name, $1.for_node.symbol_ptr->name);
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

        condition_info info = condition_process(&$1.for_node, (($1.for_direction == DIRECTION_TO) ? LESS_MICROEX : GREAT_MICROEX), &$1.for_end_node);
        generate("I_CMP 0 %s\n", info.result_node.symbol_ptr->name);
        generate("JNE %s\n", $1.for_start_label->name);
        generate("%s\n", $1.for_end_label->name); // end label for for loop
        logging("> for_statement -> for_prefix statement_list endfor\n");
        
        generate("\n");
    }
for_prefix:
    FOR_MICROEX LEFT_PARENT_MICROEX id ASSIGN_MICROEX expression direction expression RIGHT_PARENT_MICROEX {
        if ($3->type == TYPE_UNKNOWN) {
            yyerror_name("Variable not declared.", "Undeclared");
        }
        if ($3->type != TYPE_INT && $3->type != TYPE_DOUBLE) {
            yyerror_name("Loop variable must be of type int or double.", "Type");
        }
        if ($5.symbol_ptr->type != TYPE_INT && $5.symbol_ptr->type != TYPE_DOUBLE && $5.symbol_ptr->type != TYPE_BOOL) {
            yyerror_name("Loop start expression must be of type int, double or bool.", "Type");
        }
        if ($7.symbol_ptr->type != TYPE_INT && $7.symbol_ptr->type != TYPE_DOUBLE && $7.symbol_ptr->type != TYPE_BOOL) {
            yyerror_name("Loop end expression must be of type int, double or bool.", "Type");
        }
        if($3->array_info.dimensions > 0 && $3->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        if($5.symbol_ptr->array_info.dimensions > 0 && $5.array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        if($7.symbol_ptr->array_info.dimensions > 0 && $7.symbol_ptr->array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }
        $5.symbol_ptr = extract_array_symbol($5.symbol_ptr);
        $7.symbol_ptr = extract_array_symbol($7.symbol_ptr);

        // loop variable initialization
        if ($3->array_pointer.dimensions > 0) {
            if ($3->array_info.dimensions == 0) {
                yyerror_name("Array access with non-array variable.", "Type");
            }
            if ($3->array_info.dimensions != $3->array_pointer.dimensions) {
                yyerror_name("Array access with wrong number of dimensions.", "Index");
            }
            symbol *offset = get_array_offset($3->array_info, $3->array_pointer);
            switch ($3->type) {
                case TYPE_INT: {
                    switch ($5.symbol_ptr->type) {
                        case TYPE_BOOL: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %s))\n", $3->name, offset->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %lld))\n", $3->name, offset->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %g))\n", $3->name, offset->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            if ($3->array_pointer.is_static_checkable) {
                                $3->value.int_array[offset->value.int_val] = $5.symbol_ptr->value.bool_val;
                            }
                            generate("I_STORE %s %s[%s]\n", $5.symbol_ptr->name, $3->name, offset->name);
                            break;
                        }
                        case TYPE_INT: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %s))\n", $3->name, offset->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %lld))\n", $3->name, offset->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %g))\n", $3->name, offset->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            if ($3->array_pointer.is_static_checkable) {
                                $3->value.int_array[offset->value.int_val] = $5.symbol_ptr->value.int_val;
                            }
                            generate("I_STORE %s %s[%s]\n", $5.symbol_ptr->name, $3->name, offset->name);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %s))\n", $3->name, offset->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %lld))\n", $3->name, offset->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %g))\n", $3->name, offset->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            if ($3->array_pointer.is_static_checkable) {
                                $3->value.int_array[offset->value.int_val] = $5.symbol_ptr->value.double_val;
                            }
                            generate("F_TO_I %s %s[%s]\n", $5.symbol_ptr->name, $3->name, offset->name);
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
                    switch ($5.symbol_ptr->type) {
                        case TYPE_BOOL: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %s))\n", $3->name, offset->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %lld))\n", $3->name, offset->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %s %s %g))\n", $3->name, offset->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            if ($3->array_pointer.is_static_checkable) {
                                $3->value.double_array[offset->value.int_val] = $5.symbol_ptr->value.bool_val;
                            }
                            generate("I_TO_F %s %s[%s]\n", $5.symbol_ptr->name, $3->name, offset->name);
                            break;
                        }
                        case TYPE_INT: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %s))\n", $3->name, offset->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %lld))\n", $3->name, offset->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %lld %s %g))\n", $3->name, offset->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            if ($3->array_pointer.is_static_checkable) {
                                $3->value.double_array[offset->value.int_val] = $5.symbol_ptr->value.int_val;
                            }
                            generate("I_TO_F %s %s[%s]\n", $5.symbol_ptr->name, $3->name, offset->name);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %s))\n", $3->name, offset->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %lld))\n", $3->name, offset->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s[%s] := %g %s %g))\n", $3->name, offset->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            if ($3->array_pointer.is_static_checkable) {
                                $3->value.double_array[offset->value.int_val] = $5.symbol_ptr->value.double_val;
                            }
                            generate("F_STORE %s %s[%s]\n", $5.symbol_ptr->name, $3->name, offset->name);
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
            switch ($3->type) {
                case TYPE_INT: {
                    switch ($5.symbol_ptr->type) {
                        case TYPE_INT: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %s))\n", $3->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %lld))\n", $3->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %g))\n", $3->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            generate("I_STORE %s %s\n", $5.symbol_ptr->name, $3->name);
                            break;
                        }
                        case TYPE_BOOL: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %s))\n", $3->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %lld))\n", $3->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %g))\n", $3->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            generate("I_STORE %s %s\n", $5.symbol_ptr->name, $3->name);
                            break;
                        }
                        case TYPE_DOUBLE: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %g %s %s))\n", $3->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %g %s %lld))\n", $3->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %g %s %g))\n", $3->name, $5.symbol_ptr->value.double_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            generate("F_TO_I %s %s\n", $5.symbol_ptr->name, $3->name);
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
                    switch ($5.symbol_ptr->type) {
                        case TYPE_INT: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %s))\n", $3->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %lld))\n", $3->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %lld %s %g))\n", $3->name, $5.symbol_ptr->value.int_val, ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            generate("I_TO_F %s %s\n", $5.symbol_ptr->name, $3->name);
                            break;
                        }
                        case TYPE_BOOL: {
                            switch ($7.symbol_ptr->type) {
                                case TYPE_BOOL: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %s))\n", $3->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.bool_val ? "true" : "false");
                                    break;
                                }
                                case TYPE_INT: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %lld))\n", $3->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.int_val);
                                    break;
                                }
                                case TYPE_DOUBLE: {
                                    logging("> for_prefix -> for left_parent id assign expression direction expression right_parent (for_prefix -> for (%s := %s %s %g))\n", $3->name, $5.symbol_ptr->value.bool_val ? "true" : "false", ($6 == DIRECTION_TO) ? "to" : "downto", $7.symbol_ptr->value.double_val);
                                    break;
                                }
                                case TYPE_STRING:
                                case TYPE_PROGRAM_NAME:
                                default: {
                                    yyerror_name("Impossible data type when parsing.", "Parsing");
                                    break;
                                }
                            }
                            generate("I_TO_F %s %s\n", $5.symbol_ptr->name, $3->name);
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
        if (!$5.symbol_ptr->is_static_checkable) {
            switch ($5.symbol_ptr->type) {
                case TYPE_INT: {
                    logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $5.symbol_ptr->name, $5.symbol_ptr->value.int_val);
                    break;
                }
                case TYPE_DOUBLE: {
                    logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $5.symbol_ptr->name, $5.symbol_ptr->value.double_val);
                    break;
                }
                case TYPE_BOOL: {
                    logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $5.symbol_ptr->name, $5.symbol_ptr->value.bool_val ? "true" : "false");
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
        if (!$7.symbol_ptr->is_static_checkable) {
            switch ($7.symbol_ptr->type) {
                case TYPE_INT: {
                    logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $7.symbol_ptr->name, $7.symbol_ptr->value.int_val);
                    break;
                }
                case TYPE_DOUBLE: {
                    logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $7.symbol_ptr->name, $7.symbol_ptr->value.double_val);
                    break;
                }
                case TYPE_BOOL: {
                    logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $7.symbol_ptr->name, $7.symbol_ptr->value.bool_val ? "true" : "false");
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
        node id_node = {
            .symbol_ptr = $3,
            .next = NULL,
            .array_pointer = $3->array_pointer
        };
        condition_info info = condition_process(&id_node, (($6 == DIRECTION_TO)? LESS_MICROEX : GREAT_MICROEX), &$7);
        generate("I_CMP 0 %s\n", info.result_node.symbol_ptr->name);
        generate("JNE %s\n", for_start_label->name);
        generate("J %s\n", for_end_label->name);
        generate("%s:\n", for_start_label->name);

        $$.for_start_label = for_start_label;
        $$.for_end_label = for_end_label;
        $$.for_node = id_node;
        $$.for_direction = $6;
        $$.for_end_node = $7;

        $3->is_static_checkable = $5.symbol_ptr->is_static_checkable && $7.symbol_ptr->is_static_checkable; // propagate static checkability
    }
    ;
direction:
    TO_MICROEX {
        $$ = DIRECTION_TO;
        logging("> direction -> to\n");
    }
    | DOWNTO_MICROEX {
        $$ = DIRECTION_DOWNTO;
        logging("> direction -> downto\n");
    }
    ;

// while statement
while_statement:
    while_prefix statement_list ENDWHILE_MICROEX {
        if ($1.while_condition.array_pointer.dimensions > 0) {
            symbol *offset = get_array_offset($1.while_condition.symbol_ptr->array_info, $1.while_condition.array_pointer);
            switch ($1.while_condition.symbol_ptr->type) {
                case TYPE_INT: {
                    generate("I_CMP 0 %s[%s]\n", $1.while_condition.symbol_ptr->name, offset->name);
                    generate("JNE %s\n", $1.while_start_label->name);

                    logging("> while_statement -> while_prefix statement_list endwhile\n");
                    break;
                }
                case TYPE_DOUBLE: {
                    generate("F_CMP 0.0 %s[%s]\n", $1.while_condition.symbol_ptr->name, offset->name);
                    generate("JNE %s\n", $1.while_start_label->name);

                    logging("> while_statement -> while_prefix statement_list endwhile\n");
                    break;
                }
                case TYPE_BOOL: {
                    generate("I_CMP 0 %s[%s]\n", $1.while_condition.symbol_ptr->name, offset->name);
                    generate("JNE %s\n", $1.while_start_label->name);

                    logging("> while_statement -> while_prefix statement_list endwhile\n");
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
            switch ($1.while_condition.symbol_ptr->type) {
                case TYPE_BOOL: {
                    generate("I_CMP 0 %s\n", $1.while_condition.symbol_ptr->name);
                    generate("JNE %s\n", $1.while_start_label->name);

                    logging("> while_statement -> while_prefix statement_list endwhile\n");
                    break;
                }
                case TYPE_INT: {
                    generate("I_CMP 0 %s\n", $1.while_condition.symbol_ptr->name);
                    generate("JNE %s\n", $1.while_start_label->name);

                    logging("> while_statement -> while_prefix statement_list endwhile\n");
                    break;
                }
                case TYPE_DOUBLE: {
                    generate("F_CMP 0.0 %s\n", $1.while_condition.symbol_ptr->name);
                    generate("JNE %s\n", $1.while_start_label->name);

                    logging("> while_statement -> while_prefix statement_list endwhile\n");
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

        generate("%s:\n", $1.while_end_label->name);
        
        generate("\n");
    }
    ;
while_prefix:
    WHILE_MICROEX LEFT_PARENT_MICROEX expression RIGHT_PARENT_MICROEX {
        if ($3.symbol_ptr->type != TYPE_BOOL && $3.symbol_ptr->type != TYPE_INT && $3.symbol_ptr->type != TYPE_DOUBLE) {
            yyerror("Condition in while statement must be of type bool, int or double.");
        }
        if($3.symbol_ptr->array_info.dimensions > 0 && $3.array_pointer.dimensions == 0) {
            yyerror_name("Access non-array symbol with array symbol.", "Type");
        }

        label *while_start_label = add_label();
        label *while_end_label = add_label();

        if ($3.symbol_ptr->array_pointer.dimensions > 0) {
            symbol *offset = get_array_offset($3.symbol_ptr->array_info, $3.symbol_ptr->array_pointer);
            dimensions = array_dimensions_to_string($3.symbol_ptr->array_pointer);
            switch ($3.symbol_ptr->type) {
                case TYPE_INT: {
                    generate("I_CMP 0 %s[%s]\n", $3.symbol_ptr->name, offset->name);
                    generate("JNE %s\n", while_start_label->name);

                    logging("> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s%s))\n", $3.symbol_ptr->name, dimensions);
                    break;
                }
                case TYPE_DOUBLE: {
                    generate("F_CMP 0.0 %s[%s]\n", $3.symbol_ptr->name, offset->name);
                    generate("JNE %s\n", while_start_label->name);

                    logging("> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s%s))\n", $3.symbol_ptr->name, dimensions);
                    break;
                }
                case TYPE_BOOL: {
                    generate("I_CMP 0 %s[%s]\n", $3.symbol_ptr->name, offset->name);
                    generate("JNE %s\n", while_start_label->name);

                    logging("> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s%s))\n", $3.symbol_ptr->name, dimensions);
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
            switch ($3.symbol_ptr->type) {
                case TYPE_BOOL: {
                    generate("I_CMP 0 %s\n", $3.symbol_ptr->name);
                    generate("JNE %s\n", while_start_label->name);

                    logging("> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%s))\n", $3.symbol_ptr->value.bool_val ? "true" : "false");
                    if (!$3.symbol_ptr->is_static_checkable) {
                        logging("\t> %s = %s is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.bool_val ? "true" : "false");
                    }
                    break;
                }
                case TYPE_INT: {
                    generate("I_CMP 0 %s\n", $3.symbol_ptr->name);
                    generate("JNE %s\n", while_start_label->name);

                    logging("> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%lld))\n", $3.symbol_ptr->value.int_val);
                    if (!$3.symbol_ptr->is_static_checkable) {
                        logging("\t> %s = %lld is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.int_val);
                    }
                    break;
                }
                case TYPE_DOUBLE: {
                    generate("F_CMP 0.0 %s\n", $3.symbol_ptr->name);
                    generate("JNE %s\n", while_start_label->name);

                    logging("> while_prefix -> while left_parent expression right_parent (while_prefix -> while (%g))\n", $3.symbol_ptr->value.double_val);
                    if (!$3.symbol_ptr->is_static_checkable) {
                        logging("\t> %s = %g is not static checkable, so parsing log may not be accurate.\n", $3.symbol_ptr->name, $3.symbol_ptr->value.double_val);
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

        generate("J %s\n", while_end_label->name);
        generate("%s:\n", while_start_label->name);
    }
    ;
%%
