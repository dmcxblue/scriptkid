from mythic_container.MythicCommandBase import *


class JobkillArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="job_id",
                type=ParameterType.String,
                description="Job ID returned by `jobs`",
                parameter_group_info=[ParameterGroupInfo(required=True)],
            ),
        ]

    async def parse_arguments(self):
        self.add_arg("job_id", self.command_line.strip())


class JobkillCommand(CommandBase):
    cmd = "jobkill"
    needs_admin = False
    help_cmd = "jobkill <job_id>"
    description = "Cancel a background job tracked by `jobs`."
    version = 1
    author = "@dmcxblue"
    argument_class = JobkillArguments
    attackmapping = []
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
