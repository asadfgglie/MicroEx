import argparse
import logging
import enum

FN_NAME_LABEL_PREFIX = "fn_name&"

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

class Simulator:
    def __init__(self):
        self.instruction: dict[int, list[str]] = dict()
        self.label: dict[str, int] = dict()
        self.instruction_ptr: int | None = None
        self.call_stack: list[int] = list()
        self.is_loaded: bool = False

        self.variables: dict[str, Variable] = dict()

        self.cmp_cmds: list[str] = list()
    
    def load(self, path: str):
        try:
            with open(path, 'r', encoding='utf8') as f:
                for ins in f.readlines():
                    if ins != '\n':
                        op = ins.split()[0]
                        if op.startswith("START"):
                            self.instruction_ptr = len(self.instruction)
                        elif op[-1] == ':':
                            self.label[op[:-1]] = len(self.instruction)
                        else:
                            self.instruction[len(self.instruction)] = ins.split()
            if self.instruction_ptr is None:
                raise ValueError("Can't fine start point in code.")
        except Exception as e:
            logging.error("Can't load asm code.", e)
            exit(1)

        self.is_loaded = True
    
    def execute(self, path: str = None):
        if not self.is_loaded:
            self.load(path)
        
        while True:
            op = self.instruction[self.instruction_ptr][0]
            args = self.instruction[self.instruction_ptr][1:]

            if op == "DECLARE":
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
                if len(args[-1].split('[')) > 1:
                    cmd = "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
                else:
                    cmd = "self.variables[args[-1].split('[')[0]].value"
                cmd += ' = -'
                if len(args[0].split('[')) > 1:
                    cmd += "self.variables[args[0].split('[')[0]].value[int(args[0].split('[')[-1].removesuffix(']'))]"
                elif isnumeric(args[0]):
                    cmd += 'int(args[0])' if op[0] == 'I' else 'float(args[0])'
                else:
                    cmd += "self.variables[args[0].split('[')[0]].value"
                exec(cmd)
            elif op == 'INC':
                for arg in args:
                    if not isnumeric(arg.split('[')[0]):
                        if arg.split('[')[0] not in self.variables:
                            raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                        elif not self.variables[arg.split('[')[0]].type.name.startswith(VarType.INTEGER.name):
                            raise TypeError(f"{arg.split('[')[0]} isn't `{VarType.INTEGER.name}`!")
                if len(args[-1].split('[')) > 1:
                    cmd = "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
                else:
                    cmd = "self.variables[args[-1].split('[')[0]].value"
                cmd += ' += 1'
                exec(cmd)
            elif op == 'DEC':
                for arg in args:
                    if not isnumeric(arg.split('[')[0]):
                        if arg.split('[')[0] not in self.variables:
                            raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                        elif not self.variables[arg.split('[')[0]].type.name.startswith(VarType.INTEGER.name):
                            raise TypeError(f"{arg.split('[')[0]} isn't `{VarType.INTEGER.name}`!")
                if len(args[-1].split('[')) > 1:
                    cmd = "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
                else:
                    cmd = "self.variables[args[-1].split('[')[0]].value"
                cmd += ' -= 1'
                exec(cmd)
            elif op.endswith('STORE'):
                for arg in args:
                    if not isnumeric(arg.split('[')[0]):
                        if arg.split('[')[0] not in self.variables:
                            raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                        elif not self.variables[arg.split('[')[0]].type.name.startswith(VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name):
                            raise TypeError(f"{arg.split('[')[0]} isn't `{VarType.INTEGER.name if op[0] == 'I' else VarType.REAL.name}`!")
                if len(args[-1].split('[')) > 1:
                    cmd = "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
                else:
                    cmd = "self.variables[args[-1].split('[')[0]].value"
                cmd += ' = '
                if len(args[0].split('[')) > 1:
                    cmd += "self.variables[args[0].split('[')[0]].value[int(args[0].split('[')[-1].removesuffix(']'))]"
                elif isnumeric(args[0]):
                    cmd += 'int(args[0])' if op[0] == 'I' else 'float(args[0])'
                else:
                    cmd += "self.variables[args[0].split('[')[0]].value"
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
                    cmds[0] += "self.variables[args[0].split('[')[0]].value[int(args[0].split('[')[-1].removesuffix(']'))]"
                elif isnumeric(args[0]):
                    cmd += 'int(args[0])' if op[0] == 'I' else 'float(args[0])'
                else:
                    cmds[0] += "self.variables[args[0].split('[')[0]].value"

                if len(args[1].split('[')) > 1:
                    cmds[1] += "self.variables[args[1].split('[')[0]].value[int(args[1].split('[')[-1].removesuffix(']'))]"
                elif isnumeric(args[1]):
                    cmd += 'int(args[1])' if op[0] == 'I' else 'float(args[1])'
                else:
                    cmds[1] += "self.variables[args[1].split('[')[0]].value"
                
                self.cmp_cmds = cmds
            elif op == 'J':
                self.instruction_ptr = self.label[args[0]]
                continue
            elif op == 'JE':
                if exec(self.cmp_cmds[0] + '==' + self.cmp_cmds[1]):
                    self.instruction_ptr = self.label[args[0]]
                    continue
            elif op == 'JG':
                if exec(self.cmp_cmds[0] + '>' + self.cmp_cmds[1]):
                    self.instruction_ptr = self.label[args[0]]
                    continue
            elif op == 'JGE':
                if exec(self.cmp_cmds[0] + '>=' + self.cmp_cmds[1]):
                    self.instruction_ptr = self.label[args[0]]
                    continue
            elif op == 'JL':
                if exec(self.cmp_cmds[0] + '<' + self.cmp_cmds[1]):
                    self.instruction_ptr = self.label[args[0]]
                    continue
            elif op == 'JLE':
                if exec(self.cmp_cmds[0] + '<=' + self.cmp_cmds[1]):
                    self.instruction_ptr = self.label[args[0]]
                    continue
            elif op == 'JNE':
                if exec(self.cmp_cmds[0] + '!=' + self.cmp_cmds[1]):
                    self.instruction_ptr = self.label[args[0]]
                    continue
            elif op == 'CALL':
                if args[0].startswith('read') or args[0].startswith('write'):
                    if len(args[1].split('[')) > 1:
                        cmd += "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
                    elif isnumeric(args[1]):
                        cmd += 'args[1]'
                    else:
                        cmd += "self.variables[args[-1].split('[')[0]].value"

                    if args[0].startswith('read'):
                        if args[0].endswith('i'):
                            cmd += ' = int(input())'
                        elif args[1].endswith('f'):
                            cmd += ' = float(input())'
                        elif args[1].endswith('b'):
                            cmd += ' = int(bool(input()))'
                    else:
                        if args[0].endswith('i'):
                            cmd = f"print(int({cmd}))"
                        elif args[1].endswith('f'):
                            cmd = f"print(float({cmd}))"
                        elif args[1].endswith('b'):
                            cmd = f"print(bool({cmd}))"
                else:
                    if args[-1].split('[')[0] not in self.variables:
                        raise ValueError(f"{args[-1].split('[')[0]} isn't declare!")

                    self.call_stack.append(self.instruction_ptr)
                    self.instruction_ptr = self.label[f"{FN_NAME_LABEL_PREFIX}{args[0]}"]
                    continue
            elif op == 'RETURN':
                self.instruction_ptr = self.call_stack.pop()
                tmp_arg = self.instruction[self.instruction_ptr][-1]

                if args[-1] not in self.variables:
                    raise ValueError(f"{tmp_arg.split('[')[0]} isn't declare!")
                if not self.variables[args[-1].split('[')[0]].type.name.startswith(self.variables[tmp_arg.split('[')[0]].type.name):
                    raise TypeError(f"{tmp_arg.split('[')[0]} isn't `{self.variables[args[-1].split('[')[0]].type.name}`!")

                if len(tmp_arg.split('[')) > 1:
                    cmd += "self.variables[tmp_arg.split('[')[0]].value[int(tmp_arg.split('[')[-1].removesuffix(']'))]"
                else:
                    cmd += "self.variables[tmp_arg.split('[')[0]].value"

                cmd += '='
                
                if len(args[-1].split('[')) > 1:
                    cmd = "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
                else:
                    cmd = "self.variables[args[-1].split('[')[0]].value"
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
                if len(args[-1].split('[')) > 1:
                    cmd = "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
                else:
                    cmd = "self.variables[args[-1].split('[')[0]].value"

                cmd += ' = not '

                if len(args[0].split('[')) > 1:
                    cmd += "self.variables[args[0].split('[')[0]].value[int(args[0].split('[')[-1].removesuffix(']'))]"
                elif isnumeric(args[0]):
                    cmd += 'int(args[0])' if type.name.startswith(VarType.INTEGER.name) else 'float(args[0])'
                else:
                    cmd += "self.variables[args[0].split('[')[0]].value"

                exec(cmd)
            elif op == 'HALT':
                break
            else:
                raise ValueError(f"Undefine Operation `{op}`")

            self.instruction_ptr += 1

    def execute_operator(self, oper: str, args: list[str], type: VarType):
        for arg in args:
            if not isnumeric(arg.split('[')[0]):
                if arg.split('[')[0] not in self.variables:
                    raise ValueError(f"{arg.split('[')[0]} isn't declare!")
                elif not self.variables[arg.split('[')[0]].type.name.startswith(type.name):
                    raise TypeError(f"{arg.split('[')[0]} isn't `{type.name}`!")
        if len(args[-1].split('[')) > 1:
            cmd = "self.variables[args[-1].split('[')[0]].value[int(args[-1].split('[')[-1].removesuffix(']'))]"
        else:
            cmd = "self.variables[args[-1].split('[')[0]].value"

        cmd += f' {oper} '

        if len(args[0].split('[')) > 1:
            cmd += "self.variables[args[0].split('[')[0]].value[int(args[0].split('[')[-1].removesuffix(']'))]"
        elif isnumeric(args[0]):
            cmd += 'int(args[0])' if type.name.startswith(VarType.INTEGER.name) else 'float(args[0])'
        else:
            cmd += "self.variables[args[0].split('[')[0]].value"

        cmd += oper

        if len(args[1].split('[')) > 1:
            cmd += "self.variables[args[1].split('[')[0]].value[int(args[1].split('[')[-1].removesuffix(']'))]"
        elif isnumeric(args[1]):
            cmd += 'int(args[1])' if type.name.startswith(VarType.INTEGER.name) else 'float(args[1])'
        else:
            cmd += "self.variables[args[1].split('[')[0]].value"
        exec(cmd)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-f', '--file', action='store')
    parser = parser.parse_args()
    cpu = Simulator()
    cpu.execute(parser.file)