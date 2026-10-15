from mythic_container.MythicCommandBase import *


class LsArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="path",
                type=ParameterType.String,
                description="Directory to list (default: current directory)",
                default_value=".",
                parameter_group_info=[ParameterGroupInfo(required=False)],
            ),
        ]

    async def parse_arguments(self):
        if self.command_line and self.command_line[0] == "{":
            self.load_args_from_json_string(self.command_line)
        elif self.command_line.strip():
            self.add_arg("path", self.command_line.strip())


class LsCommand(CommandBase):
    cmd = "ls"
    needs_admin = False
    help_cmd = "ls [path]"
    description = "List contents of a directory."
    version = 1
    author = "@dmcxblue"
    argument_class = LsArguments
    attackmapping = ["T1083"]
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
