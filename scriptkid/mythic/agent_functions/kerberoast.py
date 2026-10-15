from mythic_container.MythicCommandBase import *


class KerberoastArguments(TaskArguments):
    def __init__(self, command_line, **kwargs):
        super().__init__(command_line, **kwargs)
        self.args = [
            CommandParameter(
                name="spn",
                type=ParameterType.String,
                description="SPN to request (optional; blank enumerates and requests)",
                default_value="",
                parameter_group_info=[ParameterGroupInfo(required=False)],
            ),
        ]

    async def parse_arguments(self):
        self.add_arg("spn", self.command_line.strip())


class KerberoastCommand(CommandBase):
    cmd = "kerberoast"
    needs_admin = False
    help_cmd = "kerberoast [spn]"
    description = (
        "Partial coverage (per minimal-agent-feature-set.md): "
        "out-of-process SPN enumeration/request only; parsing/cracking is out of scope."
    )
    version = 1
    author = "@dmcxblue"
    argument_class = KerberoastArguments
    attackmapping = ["T1558.003"]
    attributes = CommandAttributes(supported_os=[SupportedOS.Windows])

    async def create_tasking(self, task: MythicTask) -> MythicTask:
        return task
