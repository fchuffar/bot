# BoT

BoT (stands for Bag of Tasks) is an R package allowing to distribute independent tasks over many cores and many computing nodes. The simple fact that BoT is based on the process forking feature and task locking over file system makes BoT compatible with most of computing infrastructures (multicore, clusters, grids, clouds). Using BoT, each task is a set of parameters associated with a user-defined function built on an R process. Next step consists in forking this R process for each core of the computing node. Finally, the forked set of tasks is randomized and executed in a parallel way.  When a task starts a distributed lock is taken. This avoids redundant task execution. When a task is ended, result is dumped into a file. BoT is used to compute NGS data in the SiGHT project context (ERC-StG2011-281359). BoT has been tested on two infrastructures: Grid'5000 experimental testbed (https://www.grid5000.fr) and PSMN computing center of ENS de Lyon (http://www.ens-lyon.fr/PSMN). For more information on how to use bot, have a look on the examples of the help ?bot::run_engine and ?bot::botapply.

## Installation

To get the current development version from github:

```R
install.packages("devtools")
devtools::install_github("fchuffar/bot")
```
