from mythic_container.MythicCommandBase import *


class ProcessSpawnArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="command_line",
                type=ParameterType.String,
                description="Command line to spawn",
                parameter_group_info=[ParameterGroupInfo(required=True)],
            ),
        ]

    async def parse_arguments(self):
        self.add_arg("command_line", self.command_line.strip())


class ProcessSpawnCommand(CommandBase):
    cmd = "process_spawn"
    needs_admin = False
    help_cmd = "process_spawn <command_line>"
    description = "Spawn a new process on the agent host."
    version = 1
    author = "@dmcxblue"
    argument_class = ProcessSpawnArguments
    attackmapping = []
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
