class Simulator:
    def __init__(self):
        self.instruction: dict[int: list[str]] = dict()
        self.label: dict[str, int] = dict()
        self.instruction_ptr: int = -1
        self.call_stack: list = list()