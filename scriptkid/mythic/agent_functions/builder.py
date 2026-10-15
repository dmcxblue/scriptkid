from mythic_container.PayloadBuilder import *
from mythic_container.MythicCommandBase import *
from mythic_container.MythicRPC import *

import pathlib
import json


class Scriptkid(PayloadType):
    name = "scriptkid"
    file_extension = "js"
    author = "@dmcxblue"
    supported_os = [SupportedOS.Windows]
    wrapper = False
    wrapped_payloads = []
    mythic_encrypts = True
    note = (
        "Minimal Windows-only Mythic agent in JScript or VBScript "
        "(COM-only; no in-process native-code loading). Scope is tracked in "
        "docs/minimal-agent-feature-set.md."
    )
    supports_dynamic_loading = False

    c2_profiles = ["http", "httpx"]

    build_parameters = [
        BuildParameter(
            name="language",
            parameter_type=BuildParameterType.ChooseOne,
            description="Script dialect to emit",
            choices=["jscript", "vbscript"],
            default_value="jscript",
        ),
        BuildParameter(
            name="callback_jitter",
            parameter_type=BuildParameterType.String,
            description="Jitter percentage for callback interval (0-100)",
            default_value="20",
        ),
    ]

    agent_path = pathlib.Path(".") / "scriptkid" / "mythic"
    agent_icon_path = agent_path / "scriptkid.svg"
    agent_code_path = pathlib.Path(".") / "scriptkid" / "agent_code"

    build_steps = [
        BuildStep(
            step_name="Selecting template",
            step_description="Pick JScript or VBScript source template",
        ),
        BuildStep(
            step_name="Rendering",
            step_description="Substitute UUID / callback / profile values",
        ),
    ]

    translation_container = None

    async def build(self) -> BuildResponse:
        resp = BuildResponse(status=BuildStatus.Error)
        try:
            language = self.get_parameter("language")
            template_name = (
                "scriptkid.js" if language == "jscript" else "scriptkid.vbs"
            )
            template_path = self.agent_code_path / template_name
            await SendMythicRPCPayloadUpdatebuildStep(
                MythicRPCPayloadUpdateBuildStepMessage(
                    PayloadUUID=self.uuid,
                    StepName="Selecting template",
                    StepStdout=f"template: {template_path}",
                    StepSuccess=True,
                )
            )

            with open(template_path, "r") as f:
                source = f.read()

            profile_cfg = {}
            for p in self.c2info:
                profile_cfg = p.get_parameters_dict()
                break

            substitutions = {
                "__UUID__": self.uuid,
                "__CALLBACK_HOST__": profile_cfg.get("callback_host", ""),
                "__CALLBACK_PORT__": str(profile_cfg.get("callback_port", "")),
                "__POST_URI__": profile_cfg.get("post_uri", ""),
                "__GET_URI__": profile_cfg.get("get_uri", ""),
                "__CALLBACK_INTERVAL__": str(
                    profile_cfg.get("callback_interval", "10")
                ),
                "__CALLBACK_JITTER__": self.get_parameter("callback_jitter"),
                "__PROFILE_HEADERS__": json.dumps(
                    profile_cfg.get("headers", {})
                ),
            }
            for key, value in substitutions.items():
                source = source.replace(key, value)

            await SendMythicRPCPayloadUpdatebuildStep(
                MythicRPCPayloadUpdateBuildStepMessage(
                    PayloadUUID=self.uuid,
                    StepName="Rendering",
                    StepStdout="substitutions applied",
                    StepSuccess=True,
                )
            )

            resp.payload = source.encode()
            resp.build_message = f"scriptkid built as {language}"
            resp.status = BuildStatus.Success
        except Exception as exc:
            resp.build_stderr = f"build failed: {exc}"
        return resp
