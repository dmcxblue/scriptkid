from mythic_container.MythicCommandBase import *


class DownloadArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="path",
                type=ParameterType.String,
                description="Remote file to retrieve",
                parameter_group_info=[ParameterGroupInfo(required=True)],
            ),
        ]

    async def parse_arguments(self):
        self.add_arg("path", self.command_line.strip())


class DownloadCommand(CommandBase):
    cmd = "download"
    needs_admin = False
    help_cmd = "download <path>"
    description = "Retrieve a file from the agent host to Mythic."
    version = 1
    author = "@dmcxblue"
    argument_class = DownloadArguments
    attackmapping = []
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
