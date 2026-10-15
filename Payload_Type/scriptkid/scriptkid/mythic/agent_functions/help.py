from mythic_container.MythicCommandBase import *


class HelpArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class HelpCommand(CommandBase):
    cmd = "help"
    needs_admin = False
    help_cmd = "help"
    description = "List commands supported by this scriptkid build."
    version = 1
    author = "@dmcxblue"
    argument_class = HelpArguments
    attackmapping = []
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
