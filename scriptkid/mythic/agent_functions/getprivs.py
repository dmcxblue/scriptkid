from mythic_container.MythicCommandBase import *


class GetprivsArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = []

    async def parse_arguments(self):
        pass


class GetprivsCommand(CommandBase):
    cmd = "getprivs"
    needs_admin = False
    help_cmd = "getprivs"
    description = (
        "Enumerate token privileges available to the agent process "
        "(out-of-process; COM-only). See minimal-agent-feature-set.md."
    )
    version = 1
    author = "@dmcxblue"
    argument_class = GetprivsArguments
    attackmapping = ["T1033"]
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
