package SWAN.linux

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.*
import jetbrains.buildServer.configs.kotlin.buildSteps.*
import jetbrains.buildServer.configs.kotlin.failureConditions.*
import SWAN.template.*
import SWAN.linux.containers.*

object LinuxBuild : BuildType({

    description = "CMake build."

    templates(TemplateDockerRegistry)

    name = "Build"
    buildNumberPattern = "SWAN: %build.vcs.number%"

    allowExternalStatus = true
    artifactRules = """
        #teamcity:symbolicLinks=as-is
        **/*.log => logging
        artifacts/** => swan_artifacts_lnx64_%build.vcs.number%.zip!lnx64
    """.trimIndent()

    outputParams {
        exposeAllParameters = false
        param("product", "SWAN")
        param("build_type", "%build_type%")
        param("commit_id", "%build.revisions.revision%")
        param("commit_id_short", "%build.revisions.short%")
    }

    params {
        param("container.tag", "oneapi-2024")
        param("env.CONAN_HOME", "/conan-cache")
        param("generator", """"Unix Makefiles"""")
        param("build_type", "Release")
        param("nexus_conan_username", DslContext.getParameter("nexus_conan_username"))
        password("nexus_conan_password", DslContext.getParameter("nexus_conan_password"))
    }

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
        checkoutDir = "swanbuild-lnx"
    }

    steps {
        script {
            name = "Add version attributes"
            workingDir = "./src/version_includes"
            scriptContent = """
                #!/usr/bin/env bash
                echo '#define BUILD_NR "%build.vcs.number%"' > checkout_info.h
                echo '#define BRANCH "%teamcity.build.branch%"' >> checkout_info.h
            """.trimIndent()
        }
        script {
            name = "Build OMP"
            scriptContent = """
                #!/usr/bin/env bash
                source /etc/bashrc
                ./ci/teamcity/SWAN/linux/containers/scripts/build_all_local.sh
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/swan-buildtools-linux:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
            dockerRunParameters = "--rm --mount type=volume,source=swan-conan-cache,target=/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
            dockerPull = true
        }
    }

})
