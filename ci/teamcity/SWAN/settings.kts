import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.projectFeatures.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script

import SWAN.template.*

/*
The settings script is an entry point for defining a TeamCity
project hierarchy. The script should contain a single call to the
project() function with a Project instance or an init function as
an argument.

VcsRoots, BuildTypes, Templates, and subprojects can be
registered inside the project using the vcsRoot(), buildType(),
template(), and subProject() methods respectively.

To debug settings scripts in command-line, run the

    mvnDebug org.jetbrains.teamcity:teamcity-configs-maven-plugin:generate

command and attach your debugger to the port 8000.

To debug in IntelliJ Idea, open the 'Maven Projects' tool window (View
-> Tool Windows -> Maven Projects), find the generate task node
(Plugins -> teamcity-configs -> teamcity-configs:generate), the
'Debug' option is available in the context menu for the task.
*/


project {

    description = "contact: BlackOps (black-ops@deltares.nl)"

    params {
        param("delft3d-user", DslContext.getParameter("delft3d-user"))
        password("delft3d-secret", DslContext.getParameter("delft3d-secret"))

        param("nexus_username", DslContext.getParameter("nexus_username"))
        password("nexus_password", DslContext.getParameter("nexus_password"))
        param("nexus_iq_username", DslContext.getParameter("nexus_iq_username"))
        password("nexus_iq_password", DslContext.getParameter("nexus_iq_password"))
        param("env.UV_INDEX_URL", "https://%nexus_username%:%nexus_password%@internal-artifacts.deltares.nl/repository/python-internal/simple/")
        param("product", "dummy_value")
    }

    template(TemplateDockerRegistry)

    subProject {
        id("Linux")
        name = "Linux"
        buildType(LinuxBuild)
    }


    subProject {
        id("Windows")
        name = "Windows"
        buildType(WindowsBuild)
    }


    features {
        dockerRegistry {
            id = "DOCKER_REGISTRY_DELFT3D"
            name = "Docker Registry Delft3d"
            url = "https://containers.deltares.nl/"
            userName = "%delft3d-user%"
            password = "%delft3d-secret%"
        }
        feature {
            type = "OAuthProvider"
            param("displayName", "Keeper Vault Delft3d")
            param("secure:client-secret", "credentialsJSON:bcf00886-4ae4-4c0a-9701-4e37efab8504")
            param("providerType", "teamcity-ksm")
        }
    }

}

object Build : BuildType({
    name = "WindowsBuild"

    // Windows only:
    param("container.tag", "vs2022-intel2024-ltsc2025")
    param("nexus_conan_username", DslContext.getParameter("nexus_conan_username"))
    password("nexus_conan_password", DslContext.getParameter("nexus_conan_password"))
    param("conan_build_option", "--build-missing")
    param("env.CONAN_HOME", "C:/conan-cache")

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
        checkoutDir = "swanbuild-win64"
    }

    steps {
        script {
            name = "Build"
            id = "DockerCommand"
            scriptContent = """
                call C:\set-env.cmd
                python run_conan.py initialize deltares --ci
                python build.py --build
            """.trimIndent()
            dockerImage = "containers.deltares.nl/delft3d-dev/delft3d-buildtools-windows:%container.tag%"
            dockerPull = true
            dockerRunParameters = "--memory %teamcity.agent.hardware.memorySizeMb%m --cpus %teamcity.agent.hardware.cpuCount% --mount type=volume,source=delft3d-conan-cache,target=C:/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
        }
    }
})

object Build : BuildType({
    name = "LinuxBuild"

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
        checkoutDir = "swanbuild-lnx64"
    }

    steps {
        script {
            name = "Build"
            id = "DockerCommand"
            scriptContent = """
                #!/usr/bin/env bash
                source /etc/bashrc
                set -eo pipefail
                export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:${'$'}PKG_CONFIG_PATH
                export LD_LIBRARY_PATH=/usr/local/lib:${'$'}LD_LIBRARY_PATH
                export CMAKE_PREFIX_PATH=/usr/local:${'$'}CMAKE_PREFIX_PATH
                export CMAKE_INCLUDE_PATH=/usr/local/include:${'$'}CMAKE_INCLUDE_PATH
                export CMAKE_LIBRARY_PATH=/usr/local/lib:${'$'}CMAKE_LIBRARY_PATH

                # Initialize Conan and install pre-built dependencies from Nexus
                python run_conan.py initialize deltares --ci
                python build.py --build --ci
            """.trimIndent()
            dockerImage = "containers.deltares.nl/delft3d-dev/delft3d-third-party-libs:%dep.${LinuxThirdPartyLibs.id}.env.IMAGE_TAG%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
            dockerRunParameters = "--rm --mount type=volume,source=delft3d-conan-cache,target=/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
            dockerPull = true
        }
    }
})
