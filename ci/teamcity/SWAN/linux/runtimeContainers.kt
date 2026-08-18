package SWAN.linux

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.*
import jetbrains.buildServer.configs.kotlin.buildSteps.*
import SWAN.template.*
import SWAN.step.*
import SWAN.linux.containers.*

object LinuxRuntimeContainers : BuildType({

    description = ""
    description = """
        Build two separate container images: one for running the SWAN software and the other for executing its tests.
        The runtime container is the Docker image 'end-product' for releases that is published in Harbor.
    """.trimIndent()

    templates(
        TemplateLinuxAgent,
        TemplateMergeRequest,
        TemplatePublishStatus,
        TemplateMonitorPerformance,
        TemplateDockerRegistry
    )

    name = "Runtime Containers"
    buildNumberPattern = "%dep.${LinuxBuild.id}.product%: %build.vcs.number%"

    params {
        param("runtime_container_image", "containers.deltares.nl/swan-dev/swan-runtime-container:alma%almalinux_version%-%dep.${LinuxBuild.id}.product%-%build.vcs.number%")
        param("testbench_container_image", "containers.deltares.nl/swan-dev/test/swan-test-container:alma%almalinux_version%-%dep.${LinuxBuild.id}.product%-%build.vcs.number%")
    }

    features {
        matrix {
           param("almalinux_version", listOf(
              value("8", label = "AlmaLinux 8"),
              value("9", label = "AlmaLinux 9"),
              value("10", label = "AlmaLinux 10")
           ))
        }
    }

    params {
        param("file_path", "dimrset_linux_%dep.${LinuxBuild.id}.product%_%build.vcs.number%.tar.gz")
    }

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
    }

    steps {
        step {
            name = "Download artifact from Nexus"
            type = "RawDownloadNexusLinux2"
            executionMode = BuildStep.ExecutionMode.DEFAULT
            param("artifact_path", "/07_day_retention/dimrset/%file_path%")
            param("nexus_repo", "/delft3d-dev")
            param("nexus_username", "%nexus_username%")
            param("download_to", "/downloads")
            param("nexus_password", "%nexus_password%")
        }
        script {
            name = "Extract artifact"
            enabled = false
            scriptContent = """
                echo "Extracting %file_path%..."

                tar -xzf %file_path%

                mkdir dimrset

                cp -r lnx64/bin dimrset/bin

                cp -r lnx64/lib dimrset/lib

                cp -r lnx64/share dimrset/share
            """.trimIndent()
        }
        exec {
            name = "Copy example and readme.txt"
            path = "ci/teamcity/SWAN/linux/scripts/copyExampleAndReadMe.sh"
        }
        dockerCommand {
            name = "Docker build SWAN runtime image"
            commandType = build {
                source = file {
                    path = "ci/teamcity/SWAN/linux/docker/runtimeContainer.Dockerfile"
                }
                contextDir = "."
                platform = DockerCommandStep.ImagePlatform.Linux
                namesAndTags = """
                    runtime-container
                    %runtime_container_image%
                """.trimIndent()
                commandArgs = """
                    --provenance=false
                    --pull
                    --no-cache
                    --build-arg BASE_IMAGE=containers.deltares.nl/docker-proxy/library/almalinux:%almalinux_version%
                    --build-arg GIT_COMMIT=%build.vcs.number%
                    --build-arg GIT_BRANCH=%teamcity.build.branch%
                    --build-arg BUILDTOOLS_IMAGE_TAG=%dep.${LinuxBuild.id}.build_tools_image_tag%
                """.trimIndent()
                // --provenance=false is to prevent metadata to be pushed as unknown/unknown os/arch https://docs.docker.com/build/metadata/attestations/attestation-storage/
            }
        }
    }
    dependencies {
        dependency(LinuxCollect) {
            snapshot {
                onDependencyFailure = FailureAction.FAIL_TO_START
                onDependencyCancel = FailureAction.CANCEL
            }

            artifacts {
                artifactRules = """
                    swan_lnx64_*.tar.gz!lnx64/bin/** => swan/bin
                    swan_lnx64_*.tar.gz!lnx64/lib/** => swan/lib
                    ?:swan_lnx64_*.tar.gz!lnx64/share/** => swan/share
                """.trimIndent()
            }
        }
    }
})
