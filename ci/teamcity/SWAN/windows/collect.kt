package SWAN.windows

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.*
import jetbrains.buildServer.configs.kotlin.buildSteps.*
import jetbrains.buildServer.configs.kotlin.failureConditions.*
import SWAN.template.*
import SWAN.step.*

object WindowsCollect : BuildType({

    description = "Prepping the binaries for testing/release and verify the signing and directory structure."

    templates(
        TemplateMergeRequest,
        TemplatePublishStatus,
        TemplateMonitorPerformance,
        TemplateDockerRegistry,
        TemplateBuildConcurrency
    )

    name = "Collect"
    buildNumberPattern = "%dep.${WindowsBuild.id}.product%: %build.vcs.number%"

    allowExternalStatus = true
    artifactRules = """
        x64 => dimrset_x64_%build.vcs.number%.zip!x64
        dimrset_version_x64.txt => dimrset_x64_%build.vcs.number%.zip!x64
        dimrset_version*txt => version
    """.trimIndent()

    params {
        param("file_path", "dimrset_windows_%dep.${WindowsBuild.id}.product%_%build.vcs.number%.zip")
        param("container.tag", "collect-environment-ltsc2025")
    }

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
    }

    steps {
        script {
            name = "Prepare artifact to upload"
            dockerImage = "containers.deltares.nl/mcr-proxy/windows/server:ltsc2025"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Windows
            dockerPull = true
            scriptContent = """
                powershell -ExecutionPolicy Bypass -Command ^
                    "${'$'}ErrorActionPreference = 'Stop';" ^
                    "Write-Host 'Creating %file_path% ...';" ^
                    "Compress-Archive -Path 'x64', 'swan_version_x64.txt' -DestinationPath %file_path% -Force;" ^
                    "Write-Host 'ZIP created: %file_path%'"
            """.trimIndent()
        }
        step {
            name = "Upload artifact to Nexus"
            type = "RawUploadNexusWindows2"
            executionMode = BuildStep.ExecutionMode.DEFAULT
            param("file_path", "%file_path%")
            param("nexus_username", "%nexus_username%")
            param("nexus_password", "%nexus_password%")
            param("nexus_repo", "/swan-dev")
            param("retention_period", "07_day_retention")
            param("target_path", "/swan/%file_path%")
            enabled = false
        }
    }

    failureConditions {
        executionTimeoutMin = 180
        errorMessage = true
        failOnText {
            conditionType = BuildFailureOnText.ConditionType.REGEXP
            pattern = "Artifacts path .* not found"
            failureMessage = "Artifacts are missing"
            reverse = false
        }
        failOnText {
            conditionType = BuildFailureOnText.ConditionType.CONTAINS
            pattern = "Failed to resolve artifact dependency"
            failureMessage = "Unable to collect all dependencies"
            reverse = false
            stopBuildOnFailure = true
        }
    }

    dependencies {
        dependency(AbsoluteId("${DslContext.getParameter("delft3d_signing_project_root")}_Sign")) {
            snapshot {
                onDependencyFailure = FailureAction.FAIL_TO_START
                onDependencyCancel = FailureAction.CANCEL
            }
            artifacts {
                artifactRules = """
                    swan_artifacts_x64_*.zip!/x64/bin/** => x64/bin
                    ?:swan_artifacts_x64_*.zip!/x64/share/** => x64/share
                """.trimIndent()
            }
        }
    }
    requirements {
        equals("docker.server.osType", "windows")
    }
})
