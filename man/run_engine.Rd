\name{run_engine}
\alias{run_engine}
\title{# Execute bag of tasks parallely, on as many cores as the current computing node owns.}
\description{This bag of tasks engine forks processes on as many cores as the current computing node owns. Each sub-process takes a task randomly in the list of tasks. For each task, it starts by taking a lock on this task (creating a file named out_filename.lock). Next, it executes the task_processor (a function) using the corresponding set of parameters (task). When this execution is completed, it dumps task_processor results into a results file (named out_filename.RData).}
\usage{run_engine(tasks, task_processor, debug = FALSE, starter_name = "~/.start_best_effort_jobs", 
    rm_starter = TRUE, log_dir = "log", bot_cache_dir = "cache", 
    nb_proc = NULL, ...)}
\arguments{
  \item{tasks}{A list of tasks, each task is a list of key values that will be passed as arguments to the task_processor. Note that task$out_filename is a mandatory parameter.}
  \item{task_processor}{A function that will be called for each task in the task list \emph{tasks}.}
  \item{debug}{If \emph{TRUE} no process will be forked, the list of tasks will be executed in the current process.}
  \item{starter_name}{Path to file that will be deleted after the execution of all tasks if \emph{rm_starter} is set to \emph{TRUE}.}
  \item{rm_starter}{If \emph{TRUE} the file \emph{starter_name} will be deleted after the execution of all tasks.}
  \item{log_dir}{Path to the \emph{log} directory.}
  \item{bot_cache_dir}{the directory where task results are cached}
  \item{nb_proc}{If not NULL fix the number of core on which tasks must be computed.}
  \item{\dots}{Other arguments that will be passed to \emph{task_processor}.}
}



\author{Florent Chuffart}




\examples{

# We define a basic task_processor
sum_a_b = function(task) {
  return(task$a + task$b)
}

# We define 9 tasks
tasks = list()
for (a in 1:3) {
  for (b in 4:6) {
    tasks[[length(tasks) + 1]] = list(a=a, b=b, out_filename=paste("sum_a_b", a, b, sep="_")) 
  }
}

# We execute the 3 tasks
run_engine(tasks, sum_a_b)    

# We collect 9 task results
for (a in 1:3) {
  for (b in 4:6) {
    out_filename = paste("sum_a_b", a, b, sep="_")
    out_filename = paste("cache/", out_filename, ".RData", sep="")
    load(out_filename)
    print(task_result) 
  }
}

# Better way to do that
apply(t(tasks), 2, function(task) {
  out_filename = task[[1]]$out_filename
  out_filename = paste("cache/", out_filename, ".RData", sep="")
  load(out_filename)
  print(task_result) 
})

# Viewing statistics about the campain.
bot_stats()

}
