import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.projectFeatures.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script

import SWAN.*
import SWAN.linux.*
import SWAN.linux.containers.*
import SWAN.linux.container_smoketest.*
import SWAN.windows.*
import SWAN.template.*

import SWAN.ciUtilities.*
import SWAN.verschilanalyse.*
version = "2026.1"

project {

    description = "contact: BlackOps (black-ops@deltares.nl)"

    params {
        param("delft3d-user", DslContext.getParameter("delft3d-user"))
        password("delft3d-secret", DslContext.getParameter("delft3d-secret"))

        param("s3_dsctestbench_accesskey", DslContext.getParameter("s3_dsctestbench_accesskey"))
        password("s3_dsctestbench_secret", DslContext.getParameter("s3_dsctestbench_secret"))

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

    template(TemplateLinuxAgent)
    template(TemplateLinuxAgentFips)
    template(TemplateLinuxAgentNoFips)
    template(TemplateMergeRequest)
    template(TemplateDetermineProduct)
    template(TemplatePublishStatus)
    template(TemplateMonitorPerformance)
    template(TemplateFailureCondition)
    template(TemplateValidationDocumentation)
    template(TemplateFunctionalityDocumentation)
    template(TemplateDownloadFromS3)
    template(TemplateDockerRegistry)
    template(TemplateBuildConcurrency)

    subProject {
        id("Linux")
        name = "Linux"
        buildType(LinuxBuild)
        buildType(LinuxCollect)
        buildType(LinuxTest)
        buildTypesOrder = arrayListOf(
            LinuxBuild,
            LinuxCollect,
            LinuxTest
        )
    }

    subProject {
        id("Windows")
        name = "Windows"

        buildType(WindowsBuildEnvironment)
        buildType(WindowsCollectEnvironment)
        buildType(WindowsBuild)
        buildType(WindowsCollect)
        buildType(WindowsTest)
        buildTypesOrder = arrayListOf(
            WindowsBuildEnvironment,
            WindowsTestEnvironment,
            WindowsCollectEnvironment,
            WindowsBuild,
            WindowsCollect,
            WindowsTest,
        )
    }

    subProjectsOrder = arrayListOf(
        RelativeId("Linux"),
        RelativeId("Windows")
    )

    buildType(Trigger)
    buildTypesOrder = arrayListOf(
        Trigger
    )
        
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
