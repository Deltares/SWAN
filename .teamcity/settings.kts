import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.XmlReport
import jetbrains.buildServer.configs.kotlin.buildFeatures.dockerRegistryConnections
import jetbrains.buildServer.configs.kotlin.buildFeatures.xmlReport
import jetbrains.buildServer.configs.kotlin.buildSteps.DockerCommandStep
import jetbrains.buildServer.configs.kotlin.buildSteps.ScriptBuildStep
import jetbrains.buildServer.configs.kotlin.buildSteps.dockerCommand
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.projectFeatures.dockerRegistry

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

version = "2026.2"

project {
    description = "contact: BlackOps (black-ops@deltares.nl)"

    template(TemplateDockerRegistry)

    params {
        param("env.UV_INDEX_URL", "https://%nexus_username%:%nexus_password%@internal-artifacts.deltares.nl/repository/python-internal/simple/")
        password("nexus_iq_password", "credentialsJSON:808b00c0-15d8-48f2-a294-18b8aac9f7f4")
        param("product", "SWAN")
        param("nexus_username", "%keeper:uozag68rlbIVRpZzb8KldQ/custom_field/nexususertoken%")
        password("swan-harbor-secret", "credentialsJSON:39b20fad-c7a8-4700-9e57-8d19618bbdae")
        param("swan-harbor-user", "credentialsJSON:180f2190-54ab-4401-8fb3-7a2a01d28781")
        param("nexus_iq_username", "%keeper:lJDXCDFDkxPrpn9IXtqFYw/field/login%")
        password("nexus_password", "credentialsJSON:add9508e-d5b7-454d-be3a-7003ae88d4a6")
    }

    features {
        dockerRegistry {
            id = "DOCKER_REGISTRY_SWAN"
            name = "Docker Registry SWAN"
            url = "https://containers.deltares.nl/"
            userName = "%swan-harbor-user%"
            password = "credentialsJSON:056271d8-8e12-46c8-be7d-c47cf07ccde6"
        }
        feature {
            id = "PROJECT_EXT_1"
            type = "OAuthProvider"
            param("displayName", "Keeper Vault Swan")
            param("secure:client-secret", "credentialsJSON:0a926562-e58f-4dce-a897-94e624f3ae79")
            param("providerType", "teamcity-ksm")
        }
    }

    subProject(Windows)
    subProject(Linux)
}

object TemplateDockerRegistry : Template({
    name = "Docker Registry"
    description = "Login to Docker Registry."

    features {
        dockerRegistryConnections {
            id = "TEMPLATE_BUILD_EXT_1"
            loginToRegistry = on {
                dockerRegistryId = "DOCKER_REGISTRY_SWAN"
            }
        }
    }
})


object Linux : Project({
    name = "Linux"

    buildType(LinuxBuild)
})

object LinuxBuild : BuildType({
    templates(TemplateDockerRegistry)
    name = "Build"
    description = "CMake build."

    allowExternalStatus = true
    artifactRules = """
        #teamcity:symbolicLinks=as-is
        **/*.log => logging
        artifacts/** => swan_artifacts_lnx64_%build.vcs.number%.zip!lnx64
        test_results/** => test_logs
    """.trimIndent()
    buildNumberPattern = "SWAN: %build.vcs.number%"

    params {
        param("env.UV_INDEX_URL", "https://%nexus_conan_username%:%nexus_conan_password%@internal-artifacts.deltares.nl/repository/python-internal/simple/")
        password("nexus_conan_password", "credentialsJSON:add9508e-d5b7-454d-be3a-7003ae88d4a6")
        param("env.CONAN_HOME", "/conan-cache")
        param("container.tag", "oneapi-2024")
        param("generator", """"Unix Makefiles"""")
        password("svn_password", "credentialsJSON:4f619531-bb8c-46c5-ac37-ff622d199fbd")
        password("env.SVN_PASSWORD", "credentialsJSON:4f619531-bb8c-46c5-ac37-ff622d199fbd")
        param("build_type", "Release")
        param("nexus_conan_username", "%keeper:uozag68rlbIVRpZzb8KldQ/custom_field/nexususertoken%")
        param("svn_username", "%keeper:xF5LvtV2OQNmbyyiEcdLQg/field/login%")
    }

    outputParams {
        exposeAllParameters = false
        param("build_type", "%build_type%")
        param("commit_id", "%build.revisions.revision%")
        param("commit_id_short", "%build.revisions.short%")
        param("product", "SWAN")
    }

    vcs {
        root(DslContext.settingsRoot)

        cleanCheckout = true
        checkoutDir = "swanbuild-lnx"
    }

    steps {
        script {
            name = "Add version attributes"
            id = "RUNNER_1"
            workingDir = "./src/version_includes"
            scriptContent = """
                #!/usr/bin/env bash
                echo '#define BUILD_NR "%build.vcs.number%"' > checkout_info.h
                echo '#define BRANCH "%teamcity.build.branch%"' >> checkout_info.h
            """.trimIndent()
        }
        script {
            name = "Build ALL"
            id = "RUNNER_2"
            scriptContent = """
                #!/usr/bin/env bash
                source /etc/bashrc
                ./ci/teamcity/SWAN/linux/containers/scripts/build_all_local.sh Release "%teamcity.build.branch%"
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/swan-buildtools-linux:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
            dockerPull = true
            dockerRunParameters = "--rm --ulimit stack=-1:-1 --mount type=volume,source=swan-conan-cache,target=/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
        }
        script {
            name = "Test All"
            id = "RUNNER_3"
            scriptContent = """
                #!/usr/bin/env bash
                source /etc/bashrc
                ./ci/teamcity/SWAN/linux/containers/scripts/run_tests_local.sh "/workspace" "%teamcity.build.branch%" "41.51.9CONAN"
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/swan-buildtools-linux:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Linux
            dockerPull = true
            dockerRunParameters = "--rm --ulimit stack=-1:-1 --shm-size=2g --mount type=volume,source=swan-test-cache,target=/workspace -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password% -e SVN_USER_NAME=%svn_username% -e SVN_PASSWORD -e UV_INDEX_URL"
        }
    }

    failureConditions {
        executionTimeoutMin = 240
        testFailure = false
    }
})


object Windows : Project({
    name = "Windows"

    buildType(WindowsBuildTools)
    buildType(WindowsBuild)
})

object WindowsBuild : BuildType({
    templates(TemplateDockerRegistry)
    name = "Build"
    description = "CMake build."

    allowExternalStatus = true
    artifactRules = """
        #teamcity:symbolicLinks=as-is
        **/*.log => logging
        artifacts/** => swan_artifacts_x64_%build.vcs.number%.zip!x64
    """.trimIndent()
    buildNumberPattern = "SWAN: %build.vcs.number%"

    params {
        password("nexus_conan_password", "credentialsJSON:add9508e-d5b7-454d-be3a-7003ae88d4a6")
        param("build_type", "Release")
        param("env.CONAN_HOME", "C:/conan-cache")
        param("container.tag", "vs2022-intel2024-ltsc2025")
        param("nexus_conan_username", "%keeper:uozag68rlbIVRpZzb8KldQ/custom_field/nexususertoken%")
    }

    vcs {
        root(DslContext.settingsRoot)

        cleanCheckout = true
        checkoutDir = "swanbuild-win"
    }

    steps {
        script {
            name = "Build All"
            id = "RUNNER_1"
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
            id = "RUNNER_2"
            scriptContent = """
                call C:\set-env.cmd
                
                echo === Test tooling diagnostics ===
                where svn.exe 2>nul || echo [not found] svn.exe
                svn --version --quiet 2>nul || echo [not available] svn --version
                where uv.exe 2>nul || echo [not found] uv.exe
                uv pip --version 2>nul || echo [not available] uv pip --version
                echo === End test tooling diagnostics ===
            """.trimIndent()
            dockerImage = "containers.deltares.nl/swan-dev/delft3d-buildtools-windows:%container.tag%"
            dockerImagePlatform = ScriptBuildStep.ImagePlatform.Windows
            dockerPull = true
            dockerRunParameters = "--memory %teamcity.agent.hardware.memorySizeMb%m --cpus %teamcity.agent.hardware.cpuCount% --mount type=volume,source=delft3d-conan-cache,target=C:/conan-cache -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=%nexus_conan_username% -e CONAN_PASSWORD_DELFT3D_CONAN_DEV=%nexus_conan_password%"
        }
    }

    failureConditions {
        executionTimeoutMin = 120
    }

    features {
        xmlReport {
            id = "BUILD_EXT_1"
            reportType = XmlReport.XmlReportType.JUNIT
            rules = "+:unit-test-report-windows.xml"
        }
    }

    requirements {
        doesNotEqual("teamcity.agent.jvm.os.name", "Windows Server 2022", "RQ_1")
    }
})

object WindowsBuildTools : BuildType({
    templates(TemplateDockerRegistry)
    name = "Windows Buildtools"
    description = "Container image used to build/test SWAN on Windows in TeamCity (adds subversion to delft3d-buildtools-windows)."

    buildNumberPattern = "%build.vcs.number%"

    params {
        param("harbor_repo", "containers.deltares.nl/swan-dev/swan-buildtools-windows")
        param("base_image", "containers.deltares.nl/swan-dev/delft3d-buildtools-windows:vs2022-intel2024-ltsc2025")
        param("image_tag", "vs2022-intel2024-ltsc2025")
    }

    vcs {
        root(DslContext.settingsRoot)

        cleanCheckout = true
    }

    steps {
        dockerCommand {
            name = "Build"
            id = "RUNNER_1"
            commandType = build {
                source = file {
                    path = "ci/dockerfiles/windows/buildtools.Dockerfile"
                }
                contextDir = "ci/dockerfiles/windows"
                platform = DockerCommandStep.ImagePlatform.Windows
                namesAndTags = "%harbor_repo%:%image_tag%"
                commandArgs = """
                    --pull
                    --build-arg BASE_IMAGE_URL=%base_image%
                """.trimIndent()
            }
        }
        dockerCommand {
            name = "Push"
            id = "RUNNER_2"
            commandType = push {
                namesAndTags = "%harbor_repo%:%image_tag%"
            }
        }
    }
})
