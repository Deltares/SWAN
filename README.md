# Introduction

SWAN is a software package owned by [Delft University of Technology (TUD)](https://fluidmechanics.tudelft.nl).

The source code is available on [TU Delft GitLab](https://gitlab.tudelft.nl/citg/wavemodels/swan)
and is distributed under [GNU GPL v3 license](https://gitlab.tudelft.nl/citg/wavemodels/swan/-/blob/main/LICENSE).

For further information, please refer to the [official SWAN website](https://swanmodel.sourceforge.io/) and the [official SWAN documentation](https://delftwaves.github.io/swan-docs/).

Repository https://github.com/Deltares-research/SWAN_TUD contains copies of SWAN created by TUD.

Repository https://github.com/Deltares/swan is a fork of https://github.com/Deltares-research/SWAN_TUD and contains a SWAN version modified by Deltares.
The TUD is not responsible for this modified version of SWAN.

# Merging TUD updates
In https://github.com/Deltares-research/SWAN_TUD.git:
1. Commit updates to main

In https://github.com/Deltares/SWAN.git:
1. (Only once:) git remote add upstream https://github.com/Deltares-research/SWAN_TUD/.git
1. Create and checkout a merge-branch
1. git fetch upstream
1. git merge upstream/main --strategy-option theirs
1. Resolve conflicts
1. Create PullRequest to merge into "Deltares/SWAN"-main, **NOT INTO "Deltares-research/SWAN_TUD"-main (which is the default)**
