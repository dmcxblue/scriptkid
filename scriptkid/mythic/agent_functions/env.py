from mythic_container.MythicCommandBase import *


class EnvArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class EnvCommand(CommandBase):
    cmd = "env"
    needs_admin = False
    help_cmd = "env"
    description = "Dump environment variables for the agent process."
    version = 1
    author = "@dmcxblue"
    argument_class = EnvArguments
    attackmapping = ["T1082"]
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
