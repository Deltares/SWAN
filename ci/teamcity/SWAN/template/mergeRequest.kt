package SWAN.template

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.*
import SWAN.step.*

object TemplateMergeRequest : Template({

    name = "Pull Request"
    description = "Support running pipeline on pull requests."

    steps {
        mergeTargetBranch {}
        cleanupTemporaryRemote {}
    }

    features {
        pullRequests {
            provider = github {
                authType = token {
                    token = "%github_deltares-service-account_access_token%"
                }
                filterAuthorRole = PullRequests.GitHubRoleFilter.MEMBER
                filterSourceBranch = "+:*"
                ignoreDrafts = true
            }
        }
    }
})
