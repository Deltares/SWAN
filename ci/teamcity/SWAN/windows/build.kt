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
        **/*.log => logging
        artifacts/** => swan_artifacts_x64_%build.vcs.number%.zip!x64
    """.trimIndent()

    params {
        param("container.tag", "vs2022-intel2024-ltsc2025")
        param("env.CONAN_HOME", "C:/conan-cache")
        param("build_type", "Release")
        param("nexus_conan_username", DslContext.getParameter("nexus_conan_username"))
        password("nexus_conan_password", DslContext.getParameter("nexus_conan_password"))
        param("svn_username", DslContext.getParameter("svn_username"))
        password("svn_password", DslContext.getParameter("svn_password"))
        password("env.SVN_PASSWORD", DslContext.getParameter("svn_password"))
    }

    vcs {
        root(DslContext.settingsRoot)
        cleanCheckout = true
        checkoutDir = "swanbuild-win"
    }

    steps {
        script {
            name = "Build All"
            enabled = false
            scriptContent = """
                call C:\set-env.cmd
                
                call ci\teamcity\SWAN\windows\scripts\build_all_local.bat %build_type% "%teamcity.build.branch%"
                if %%errorlevel%% neq 0 exit /b %%errorlevel%%
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/delft3d-buildtools-windows:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Windows
            dockerPull = true
            dockerRunParameters = "--memory %teamcity.agent.hardware.memorySizeMb%m --cpus %teamcity.agent.hardware.cpuCount% --mount type=volume,source=delft3d-conan-cache,target=C:/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
        }
        script {
            name = "Test OMP"
            enabled = true
            scriptContent = """
                call C:\set-env.cmd

                powershell -NoProfile -ExecutionPolicy Bypass -File ci\teamcity\SWAN\windows\scripts\test_all_local.ps1 C:\workspace "%teamcity.build.branch%" "41.51.9CONAN"
                if %%errorlevel%% neq 0 exit /b %%errorlevel%%
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/delft3d-buildtools-windows:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Windows
            dockerPull = true
            dockerRunParameters = "--memory %teamcity.agent.hardware.memorySizeMb%m --cpus %teamcity.agent.hardware.cpuCount% --mount type=volume,source=delft3d-conan-cache,target=C:/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password% -e SVN_USER_NAME=%svn_username% -e SVN_PASSWORD"
        }
    }

    features {
        xmlReport {
            reportType = XmlReport.XmlReportType.JUNIT
            rules = "+:unit-test-report-windows.xml"
        }
    }

    failureConditions {
        executionTimeoutMin = 120
    }

    requirements {
        doesNotEqual("teamcity.agent.jvm.os.name", "Windows Server 2022")
    }
})
