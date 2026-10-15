from mythic_container.MythicCommandBase import *


class MvArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="source",
                type=ParameterType.String,
                description="Source path",
                parameter_group_info=[ParameterGroupInfo(required=True)],
            ),
            CommandParameter(
                name="dest",
                type=ParameterType.String,
                description="Destination path",
                parameter_group_info=[ParameterGroupInfo(required=True)],
            ),
        ]

    async def parse_arguments(self):
        parts = self.command_line.strip().split(maxsplit=1)
        if len(parts) != 2:
            raise Exception("mv requires exactly two arguments: <source> <dest>")
        self.add_arg("source", parts[0])
        self.add_arg("dest", parts[1])


class MvCommand(CommandBase):
    cmd = "mv"
    needs_admin = False
    help_cmd = "mv <source> <dest>"
    description = "Move or rename a file."
    version = 1
    author = "@dmcxblue"
    argument_class = MvArguments
    attackmapping = []
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
