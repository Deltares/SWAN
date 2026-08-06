import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script

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

version = "2026.1"

project {

    description = "contact: BlackOps (black-ops@deltares.nl)"

    params {
        param("delft3d-user", DslContext.getParameter("delft3d-user"))
        password("delft3d-secret", DslContext.getParameter("delft3d-secret"))

        param("s3_dsctestbench_accesskey", DslContext.getParameter("s3_dsctestbench_accesskey"))
        password("s3_dsctestbench_secret", "credentialsJSON:7e8a3aa7-76e9-4211-a72e-a3825ad1a160")

        param("dvc_testbench_accesskey", DslContext.getParameter("dvc_testbench_accesskey"))
        password("dvc_testbench_secret", DslContext.getParameter("dvc_testbench_secret"))

        param("nexus_username", DslContext.getParameter("nexus_username"))
        password("nexus_password", DslContext.getParameter("nexus_password"))
        password("nexus_nuget_apikey", DslContext.getParameter("nexus_nuget_apikey"))
        param("nexus_iq_username", DslContext.getParameter("nexus_iq_username"))
        password("nexus_iq_password", DslContext.getParameter("nexus_iq_password"))
        param("env.UV_INDEX_URL", "https://%nexus_username%:%nexus_password%@internal-artifacts.deltares.nl/repository/python-internal/simple/")
        param("product", "dummy_value")

    }


    buildType(Build)


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
    name = "Build"

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Build"
            id = "DockerCommand"
            scriptContent = """
                python run_conan.py initialize deltares
                python build.py --build
            """.trimIndent()
            dockerImage = "containers.deltares.nl/delft3d-dev/delft3d-buildtools-windows:vs2022-intel2024-ltsc2025"
        }
    }
})
