package SWAN.windows.containers

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.*
import SWAN.template.*

object WindowsBuildTools : BuildType({
    name = "Windows Buildtools"
    description = "Container image used to build/test SWAN on Windows in TeamCity (adds subversion to delft3d-buildtools-windows)."
    buildNumberPattern = "%build.vcs.number%"

    templates(
        TemplateDockerRegistry
    )

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
    }

    params {
        param("base_image", "containers.deltares.nl/swan-dev/delft3d-buildtools-windows:vs2022-intel2024-ltsc2025")
        param("harbor_repo", "containers.deltares.nl/swan-dev/swan-buildtools-windows")
        param("image_tag", "vs2022-intel2024-ltsc2025")
    }

    steps {
        dockerCommand {
            name = "Build"
            commandType = build {
                source = file {
                    path = "ci/dockerfiles/windows/buildtools.Dockerfile"
                }
                platform = DockerCommandStep.ImagePlatform.Windows
                contextDir = "ci/dockerfiles/windows"
                namesAndTags = "%harbor_repo%:%image_tag%"
                commandArgs = """
                    --pull
                    --build-arg BASE_IMAGE_URL=%base_image%
                """.trimIndent()
            }
        }
        dockerCommand {
            name = "Push"
            commandType = push {
                namesAndTags = "%harbor_repo%:%image_tag%"
                removeImageAfterPush = true
            }
        }
    }
})
