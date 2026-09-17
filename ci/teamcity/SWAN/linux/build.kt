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
        test_results/** => test_logs
    """.trimIndent()
    
    failureConditions {
        testFailure = false
        executionTimeoutMin = 240
    }
    
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
        param("svn_username", DslContext.getParameter("svn_username"))
        password("svn_password", DslContext.getParameter("svn_password"))
        password("env.SVN_PASSWORD", DslContext.getParameter("svn_password"))
        
        param("env.UV_INDEX_URL", "https://%nexus_conan_username%:%nexus_conan_password%@internal-artifacts.deltares.nl/repository/python-internal/simple/")
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
            name = "Build ALL"
            enabled = false
            scriptContent = """
                #!/usr/bin/env bash
                source /etc/bashrc
                ./ci/teamcity/SWAN/linux/containers/scripts/build_all_local.sh Release "%teamcity.build.branch%"
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/swan-buildtools-linux:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
            dockerRunParameters = "--rm --ulimit stack=-1:-1 --mount type=volume,source=swan-conan-cache,target=/conan-cache " +
                "-e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% " +
                "-e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
            dockerPull = true
        }
        script {
            name = "Test All"
            scriptContent = """
                #!/usr/bin/env bash
                source /etc/bashrc
                echo "Number of processors:"
                nproc
                ./ci/teamcity/SWAN/linux/containers/scripts/run_tests_local.sh "/workspace" "%teamcity.build.branch%" "41.51.9CONAN"
                
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/swan-buildtools-linux:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
            // Intel MPI's shared-memory transport needs more than Docker's default 64m /dev/shm
            dockerRunParameters = "--rm --ulimit stack=-1:-1 --shm-size=2g --mount type=volume,source=swan-test-cache,target=/workspace " +
                "-e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% " +
                "-e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password% " +
                "-e SVN_USER_NAME=%svn_username% " +
                "-e SVN_PASSWORD " +
                "-e UV_INDEX_URL"
            dockerPull = true
        }
    }

})
