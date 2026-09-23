package SWAN.windows

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.*
import jetbrains.buildServer.configs.kotlin.buildSteps.*
import jetbrains.buildServer.configs.kotlin.failureConditions.*
import SWAN.template.*

object WindowsBuild : BuildType({

    description = "CMake build."

    templates(TemplateDockerRegistry)

    name = "Build"
    buildNumberPattern = "SWAN: %build.vcs.number%"

    allowExternalStatus = true
    artifactRules = """
        #teamcity:symbolicLinks=as-is
        artifacts/** => swan_artifacts_x64_%build.vcs.number%.zip!x64
        test_results/** => test_logs
    """.trimIndent()

    failureConditions {
        testFailure = false
        executionTimeoutMin = 480
    }

    params {
        param("container.tag", "vs2022-intel2024-ltsc2025")
        param("env.CONAN_HOME", "C:/conan-cache")
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
        checkoutDir = "swanbuild-win"
    }

    steps {
        script {
            name = "Build All"
            enabled = true
            scriptContent = """
                call C:\set-env.cmd
                
                call ci\teamcity\SWAN\windows\scripts\build_all_local.bat %build_type% "%teamcity.build.branch%"
                if %%errorlevel%% neq 0 exit /b %%errorlevel%%
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/delft3d-buildtools-windows:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Windows
            dockerPull = true
            dockerRunParameters = "--memory %teamcity.agent.hardware.memorySizeMb%m --cpus %teamcity.agent.hardware.cpuCount% --mount type=volume,source=swan-conan-cache,target=C:/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
        }
        script {
            name = "Test ALL"
            enabled = true
            scriptContent = """
                call C:\set-env.cmd

                powershell -NoProfile -ExecutionPolicy Bypass -File ci\teamcity\SWAN\windows\scripts\run_tests_local.ps1 C:\workspace "%teamcity.build.branch%" "41.51.9CONAN"
                if %%errorlevel%% neq 0 exit /b %%errorlevel%%
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/swan-buildtools-windows:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Windows
            dockerPull = true
            dockerRunParameters = "--memory %teamcity.agent.hardware.memorySizeMb%m " + 
                                    "--cpus %teamcity.agent.hardware.cpuCount% " + 
                                    "--mount type=volume,source=swan-test-cache,target=C:/workspace " + 
                                    "-e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password% -e " +
                                    "SVN_USER_NAME=%svn_username% -e SVN_PASSWORD=%svn_password% " +
                                    "-e UV_INDEX_URL"
        }
    }

    requirements {
        doesNotEqual("teamcity.agent.jvm.os.name", "Windows Server 2022")
    }
})
