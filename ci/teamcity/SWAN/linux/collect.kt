package SWAN.linux

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.*
import jetbrains.buildServer.configs.kotlin.buildSteps.*
import jetbrains.buildServer.configs.kotlin.failureConditions.*
import SWAN.template.*

object LinuxCollect : BuildType({

    description = "Prepping the binaries for testing/release."

    templates(
        TemplateLinuxAgent,
        TemplatePublishStatus,
        TemplateMonitorPerformance,
        TemplateBuildConcurrency
    )

    name = "Collect"
    buildNumberPattern = "%dep.${LinuxBuild.id}.product%: %build.vcs.number%"

    allowExternalStatus = true
    artifactRules = """
        #teamcity:symbolicLinks=as-is
        lnx64 => swan_lnx64_%build.vcs.number%.tar.gz!lnx64
    """.trimIndent()

    params {
        param("file_path", "dimrset_linux_%dep.${LinuxBuild.id}.product%_%build.vcs.number%.tar.gz")
    }

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
    }

    steps {
        exec {
            name = "Remove system libraries"
            workingDir = "lnx64/lib"
            path = "ci/teamcity/SWAN/linux/scripts/removeSysLibs.sh"
        }
        script {
            name = "Set execute rights"
            scriptContent = """
                chmod a+x lnx64/bin/*
            """.trimIndent()
        }
        script {
            name = "Prepare artifact to upload"
            scriptContent = """
                echo "Creating %file_path%..."
                tar -czf %file_path% lnx64
            """.trimIndent()
        }
        step {
            name = "Upload artifact to Nexus"
            type = "RawUploadNexusLinux2"
            executionMode = BuildStep.ExecutionMode.DEFAULT
            param("file_path", "%file_path%")
            param("nexus_username", "%nexus_username%")
            param("nexus_password", "%nexus_password%")
            param("nexus_repo", "/swan-dev")
            param("retention_period", "07_day_retention")
            param("target_path", "/swan/%file_path%")
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
        dependency(LinuxBuild) {
            snapshot {
                onDependencyFailure = FailureAction.FAIL_TO_START
                onDependencyCancel = FailureAction.CANCEL
            }

            artifacts {
                artifactRules = "swan_artifacts_lnx64_*.tar.gz!lnx64/** => lnx64"
            }
        }
    }
})
