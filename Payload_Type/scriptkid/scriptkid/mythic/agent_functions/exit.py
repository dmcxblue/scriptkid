from mythic_container.MythicCommandBase import *


class ExitArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        if len(self.command_line) > 0:
            raise Exception("exit takes no arguments")


class ExitCommand(CommandBase):
    cmd = "exit"
    needs_admin = False
    help_cmd = "exit"
    description = "Instruct the agent to clean up and terminate its callback."
    version = 1
    author = "@dmcxblue"
    argument_class = ExitArguments
    attackmapping = []
    supported_ui_features = ["callback_table:exit"]
    attributes = CommandAttributes(
        builtin=True,
        suggested_command=True,
        supported_os=[SupportedOS.Windows],
    )

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
