## directory to save results

study_name <- "test3" # must be different from the names in results

dir.create("results", showWarnings = FALSE)
resname <- paste0("results/", study_name,".rds")

# use older study setting? --> provide path to study results of previous study
old_study_name <- "other_methods" # Use simulation settings like in..
oldresdf <- paste0("results/", old_study_name, ".rds")# NULL



## parameters for batchtools
CORES <- 4L # 30L
registry_name <- "reg_normal"

## forest settings
# number of trees
NumTrees <- 6L # 500L

## customization of study
# number of repetitions of each study setting x N x P
REPL <- 1L # 100L
# only use subset of methods? --> remove/add method names from/to following vector
# e.g. "cf","cfhonest", "mob","mobhonest", "hybrid", "hybridhonest", "equalized", "equalizedhonest", "mobcf", "mobcfhonest"
methods <- c("doubleml")  # c("cf","cfhonest", "mob","mobhonest", "hybrid", "hybridhonest", "equalized", "equalizedhonest", "mobcf", "mobcfhonest")

# only run subset of studies? --> provide study IDs (based on DGP.R)
StudyIDs <- c(1,2,3,4) # e.g. c(1, 2)

