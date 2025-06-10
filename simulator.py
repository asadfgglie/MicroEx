import argparse
import logging
import enum

FN_NAME_LABEL_PREFIX = "fn_name&"
FN_RETURN_SYMBOL_PREFIX = "fn&{}&ret"

buffer: list[str] = list()
def get_input() -> str:
    if len(buffer) > 0:
        return buffer.pop(0)
    else:
        buffer.extend(input().split())
        return get_input()

def isnumeric(s: str):
    try:
        _ = int(s)
        return True
    except:
        try:
            _ = float(s)
            return True
        except:
            pass
    return False

class VarType(enum.Enum):
    INTEGER = 'integer'
    INTEGER_ARRAY = 'integer_array'
    REAL = 'real'
    REAL_ARRAY = 'real_array'
    FUNCTION = 'function'

class Variable:
    def __init__(self, name: str, var_type: VarType, len: int = 0):
        self.name: str = name
        self.type: VarType = var_type
        self.value: list[int | float] | int | float = 0 if len == 0 else [0] * len
        self.len: int = len

        if not self.type.value.endswith('array') and len > 0:
            raise ValueError(f"{name} is not array with array len `{len}`")
        elif self.type.value.endswith('array') and len <= 0:
            raise ValueError(f"{name} is array with array len `{len}`")
    
    def __int__(self) -> int:
        if isinstance(self.value, int):
            return self.value
        else:
            raise ValueError(f"{self.name} isn't integer.")

class Simulator:
    def __init__(self):
        self.instruction: dict[int, tuple[list[str], int]] = dict()
        self.label: dict[str, int] = dict()
        self.function: dict[str, int] = dict()
        self.instruction_ptr: int | None = None
        self.call_stack: list[int] = list()
        self.is_loaded: bool = False

        self.variables: dict[str, Variable] = dict()

        self.cmp_cmds: list[str] = list()

        self.declaring_func: str = None
    
    def arg_arr(self, index: int, args: list[str]):
        try:
            int(int(args[index].split('[')[-1].removesuffix(']')))
            return f"self.variables[args[{index}].split('[')[0]].value[int(args[{index}].split('[')[-1].removesuffix(']'))]"
        except:
            return f"self.variables[args[{index}].split('[')[0]].value[int(self.variables[args[{index}].split('[')[-1].removesuffix(']')])]"
    
    def arg_var(self, index: int):
        return f"self.variables[args[{index}].split('[')[0]].value"

    def arg_literal(self, index: int, type: VarType):
        return f'int(args[{index}])' if type.name.startswith(VarType.INTEGER.name) else f'float(args[{index}])'
    
    
    def load(self, path: str):
        try:
            with open(path, 'r', encoding='utf8') as f:
                i = 1
                for ins in f.readlines():
                    if ins != '\n':
                        op = ins.split()[0]
                        if op.startswith("START"):
                            self.instruction_ptr = len(self.instruction)
                        elif op[-1] == ':':
                            self.label[op[:-1]] = len(self.instruction)
                        else:
                            self.instruction[len(self.instruction)] = (ins.split(), i)
                    i += 1
            if self.instruction_ptr is None:
                raise ValueError("Can't fine start point in code.")
        except Exception as e:
            logging.error("Can't load asm code.", e)
            exit(1)

        self.is_loaded = True
    
    def load_ins(self):
        return self.instruction[self.instruction_ptr][0][0], self.instruction[self.instruction_ptr][0][1:]
    
    def execute(self, path: str = None):
        if not self.is_loaded:
            self.load(path)
        
        while True:
            op, args = self.load_ins()
            try:
                if op == "DECLARE":
                    if VarType._value2member_map_[args[1]] == VarType.FUNCTION:
                        if self.declaring_func is not None:
                            raise ValueError(f"Declare nested function in function: `{args[0]}`.")
                        if args[0] not in self.variables:
                            self.declaring_func = args[0]
                        self.function[args[0]] = self.instruction_ptr
                    self.variables[args[0]] = Variable(args[0], 
                                                    VarType._value2member_map_[args[1]], 
                                                    int(args[2]) if len(args) == 3 else 0)
                elif op.endswith('SUB'):
                    self.execute_operator('-', args, VarType.INTEGER if op[0] == 'I' else VarType.REAL)
                elif op.endswith('ADD'):
                    self.execute_operator('+', args, VarType.INTEGER if op[0] == 'I' else VarType.REAL)
                elif op.endswith('DIV'):
                    self.execute_operator('/', args, VarType.INTEGER if op[0] == 'I' else VarType.REAL)
                elif op.endswith('MUL'):
                    self.execute_operator('*', args, VarType.INTEGER if op[0] == 'I' else VarType.REAL)
                elif op.endswith('UMINUS'):
                    for arg in args:
                        if not isnumeric(arg.split('[')[0]):
                            if arg.split('[')[0] not in self.variables:
                                raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                            elif not self.variables[arg.split('[')[0]].type.name.startswith(VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name):
                                raise TypeError(f"{arg.split('[')[0]} isn't `{VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name}`!")
                    
                    cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)
                    cmd += ' = -'
                    if len(args[0].split('[')) > 1:
                        cmd += self.arg_arr(0, args)
                    elif isnumeric(args[0]):
                        cmd += self.arg_literal(0, VarType.INTEGER if op[0] == 'I' else VarType.REAL)
                    else:
                        cmd += self.arg_var(0)
                    exec(cmd)
                elif op == 'INC' or op == 'DEC':
                    for arg in args:
                        if not isnumeric(arg.split('[')[0]):
                            if arg.split('[')[0] not in self.variables:
                                raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                            elif not self.variables[arg.split('[')[0]].type.name.startswith(VarType.INTEGER.name):
                                raise TypeError(f"{arg.split('[')[0]} isn't `{VarType.INTEGER.name}`!")
                    cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)
                    cmd += ' += 1' if op == 'INC' else ' -= 1'
                    exec(cmd)
                elif op.endswith('STORE'):
                    for arg in args:
                        if not isnumeric(arg.split('[')[0]):
                            if arg.split('[')[0] not in self.variables:
                                raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                            elif not self.variables[arg.split('[')[0]].type.name.startswith(VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name):
                                raise TypeError(f"{arg.split('[')[0]} isn't `{VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name}`!")
                    cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)
                    cmd += ' = '
                    if len(args[0].split('[')) > 1:
                        cmd += self.arg_arr(0, args)
                    elif isnumeric(args[0]):
                        cmd += self.arg_literal(0, VarType.INTEGER if op[0] == 'I' else VarType.REAL)
                    else:
                        cmd += self.arg_var(0)
                    exec(cmd)
                elif op.endswith("CMP"):
                    for arg in args:
                        if not isnumeric(arg.split('[')[0]):
                            if arg.split('[')[0] not in self.variables:
                                raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                            elif not self.variables[arg.split('[')[0]].type.name.startswith(VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name):
                                raise TypeError(f"{arg.split('[')[0]} isn't `{VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name}`!")
                    cmds = ['', '']
                    if len(args[0].split('[')) > 1:
                        cmds[0] = str(eval(self.arg_arr(0, args)))
                    elif isnumeric(args[0]):
                        cmds[0] = str(eval(self.arg_literal(0, VarType.INTEGER if op[0] == 'I' else VarType.REAL)))
                    else:
                        cmds[0] = str(eval(self.arg_var(0)))

                    if len(args[1].split('[')) > 1:
                        cmds[1] = str(eval(self.arg_arr(1, args)))
                    elif isnumeric(args[1]):
                        cmds[1] = str(eval(self.arg_literal(1, VarType.INTEGER if op[0] == 'I' else VarType.REAL)))
                    else:
                        cmds[1] = str(eval(self.arg_var(1)))
                    
                    self.cmp_cmds = cmds
                elif op == 'J':
                    if args[0] not in self.label:
                        raise ValueError(f"label `{args[0]}` not exist.")
                    self.instruction_ptr = self.label[args[0]]
                    continue
                elif op == 'JE':
                    if args[0] not in self.label:
                        raise ValueError(f"label `{args[0]}` not exist.")
                    if eval(self.cmp_cmds[0] + ' == ' + self.cmp_cmds[1]):
                        self.instruction_ptr = self.label[args[0]]
                        continue
                elif op == 'JG':
                    if args[0] not in self.label:
                        raise ValueError(f"label `{args[0]}` not exist.")
                    if eval(self.cmp_cmds[0] + ' > ' + self.cmp_cmds[1]):
                        self.instruction_ptr = self.label[args[0]]
                        continue
                elif op == 'JGE':
                    if args[0] not in self.label:
                        raise ValueError(f"label `{args[0]}` not exist.")
                    if eval(self.cmp_cmds[0] + ' >= ' + self.cmp_cmds[1]):
                        self.instruction_ptr = self.label[args[0]]
                        continue
                elif op == 'JL':
                    if args[0] not in self.label:
                        raise ValueError(f"label `{args[0]}` not exist.")
                    if eval(self.cmp_cmds[0] + ' < ' + self.cmp_cmds[1]):
                        self.instruction_ptr = self.label[args[0]]
                        continue
                elif op == 'JLE':
                    if args[0] not in self.label:
                        raise ValueError(f"label `{args[0]}` not exist.")
                    if eval(self.cmp_cmds[0] + ' <= ' + self.cmp_cmds[1]):
                        self.instruction_ptr = self.label[args[0]]
                        continue
                elif op == 'JNE':
                    if args[0] not in self.label:
                        raise ValueError(f"label `{args[0]}` not exist.")
                    if eval(self.cmp_cmds[0] + ' != ' + self.cmp_cmds[1]):
                        self.instruction_ptr = self.label[args[0]]
                        continue
                elif op == 'CALL':
                    if args[0].startswith('read') or args[0].startswith('write'):
                        if args[0].startswith('read'):
                            cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)

                            if args[0].endswith('i'):
                                cmd += ' = int(get_input())'
                            elif args[0].endswith('f'):
                                cmd += ' = float(get_input())'
                            elif args[0].endswith('b'):
                                cmd += ' = int(bool(get_input()))'
                        else:
                            if len(args[-1].split('[')) > 1:
                                cmd = self.arg_arr(-1, args)
                            elif isnumeric(args[-1]):
                                cmd = self.arg_literal(-1, VarType.INTEGER if args[-1] in ['i', 'b'] else VarType.REAL)
                            else:
                                cmd = self.arg_var(-1)

                            if args[0].endswith('i'):
                                cmd = f"print(int({cmd}))"
                            elif args[0].endswith('f'):
                                cmd = f"print(float({cmd}))"
                            elif args[0].endswith('b'):
                                cmd = f"print(bool({cmd}))"
                        exec(cmd)
                    else:
                        if args[-1].split('[')[0] not in self.variables:
                            raise ValueError(f"{args[-1].split('[')[0]} isn't declare!")
                        if args[0] not in self.function:
                            raise ValueError(f"Can't find function: `{arg[0]}`")
                        self.call_stack.append(self.instruction_ptr)
                        self.instruction_ptr = self.function[args[0]]
                        continue
                elif op == 'RETURN':
                    if args[-1].startswith(FN_RETURN_SYMBOL_PREFIX.format(self.declaring_func)):
                        self.declaring_func = None
                    else:
                        ret = str(eval(self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)))

                        try:
                            self.instruction_ptr = self.call_stack.pop()
                        except:
                            raise ValueError("RETURN without CALL function")
                        op , args = self.load_ins()

                        if args[-1] not in self.variables:
                            raise ValueError(f"{args[-1].split('[')[0]} isn't declare!")
                        if not self.variables[args[-1].split('[')[0]].type.name.startswith(self.variables[args[-1].split('[')[0]].type.name):
                            raise TypeError(f"{args[-1].split('[')[0]} isn't `{self.variables[args[-1].split('[')[0]].type.name}`!")

                        cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)

                        cmd += ' = '
                        
                        cmd += ret
                        exec(cmd)
                elif op == 'AND':
                    self.execute_operator('and', args, VarType.INTEGER)
                elif op == 'OR':
                    self.execute_operator('or', args, VarType.INTEGER)
                elif op == 'NOT':
                    for arg in args:
                        if not isnumeric(arg):
                            if arg not in self.variables:
                                raise ValueError(f"{arg} isn't declare!")
                            elif not self.variables[arg].type.name.startswith(VarType.INTEGER.name):
                                raise TypeError(f"{arg} isn't `{VarType.INTEGER.name}`!")
                            
                    cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)

                    cmd += ' = not '

                    if len(args[0].split('[')) > 1:
                        cmd += self.arg_arr(0, args)
                    elif isnumeric(args[0]):
                        cmd += self.arg_literal(0, VarType.INTEGER)
                    else:
                        cmd += self.arg_var(0)

                    exec(cmd)
                elif op == 'HALT':
                    break
                elif op == 'I_TO_F':
                    if not isnumeric(args[0].split('[')[0]):
                        if args[0].split('[')[0] not in self.variables:
                            raise ValueError(f"{args[0].split('[')[0]} isn't declare!")
                        elif not self.variables[args[0].split('[')[0]].type.name.startswith(VarType.INTEGER.name):
                            raise TypeError(f"{args[0].split('[')[0]} isn't `{VarType.INTEGER.name}`!")
                    if not isnumeric(args[-1].split('[')[0]):
                        if args[-1].split('[')[0] not in self.variables:
                            raise ValueError(f"{args[-1].split('[')[0]} isn't declare!")
                        elif not self.variables[args[-1].split('[')[0]].type.name.startswith(VarType.REAL.name):
                            raise TypeError(f"{args[-1].split('[')[0]} isn't `{VarType.REAL.name}`!")
                    
                    cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)
                    
                    cmd += ' = '

                    if len(args[0].split('[')) > 1:
                        cmd += f"float({self.arg_arr(0, args)})"
                    elif isnumeric(args[0]):
                        cmd += self.arg_literal(0, VarType.REAL)
                    else:
                        cmd += f"float({self.arg_var(0)})"        
                elif op == 'F_TO_I':
                    if not isnumeric(args[0].split('[')[0]):
                        if args[0].split('[')[0] not in self.variables:
                            raise ValueError(f"{args[0].split('[')[0]} isn't declare!")
                        elif not self.variables[args[0].split('[')[0]].type.name.startswith(VarType.REAL.name):
                            raise TypeError(f"{args[0].split('[')[0]} isn't `{VarType.REAL.name}`!")
                    if not isnumeric(args[-1].split('[')[0]):
                        if args[-1].split('[')[0] not in self.variables:
                            raise ValueError(f"{args[-1].split('[')[0]} isn't declare!")
                        elif not self.variables[args[-1].split('[')[0]].type.name.startswith(VarType.INTEGER.name):
                            raise TypeError(f"{args[-1].split('[')[0]} isn't `{VarType.INTEGER.name}`!")
                    
                    cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)
                    
                    cmd += ' = '

                    if len(args[0].split('[')) > 1:
                        cmd += f"int({self.arg_arr(0, args)})"
                    elif isnumeric(args[0]):
                        cmd += self.arg_literal(0, VarType.INTEGER)
                    else:
                        cmd += f"int({self.arg_var(0)})"
                else:
                    raise ValueError(f"Undefine Operation `{op}`")
            except Exception as e:
                print(f"Error when execute line: {self.instruction[self.instruction_ptr][1]}")
                print(f"\t`{' '.join(self.instruction[self.instruction_ptr][0])}`")
                print(f"\t{e}")
                exit(1)

            self.instruction_ptr += 1

    def execute_operator(self, oper: str, args: list[str], type: VarType):
        for arg in args:
            if not isnumeric(arg.split('[')[0]):
                if arg.split('[')[0] not in self.variables:
                    raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                elif not self.variables[arg.split('[')[0]].type.name.startswith(type.name):
                    raise TypeError(f"{arg.split('[')[0]} isn't `{type.name}`!")
        cmd = self.arg_arr(-1, args) if len(args[-1].split('[')) > 1 else self.arg_var(-1)

        cmd += ' = '

        if len(args[0].split('[')) > 1:
            cmd += self.arg_arr(0, args)
        elif isnumeric(args[0]):
            cmd += self.arg_literal(0, type)
        else:
            cmd += self.arg_var(0)

        cmd += f" {oper} "

        if len(args[1].split('[')) > 1:
            cmd += self.arg_arr(1, args)
        elif isnumeric(args[1]):
            cmd += self.arg_literal(1, type)
        else:
            cmd += self.arg_var(1)
        exec(cmd)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--file', action='store')
    parser = parser.parse_args()
    cpu = Simulator()
    cpu.execute(parser.file)