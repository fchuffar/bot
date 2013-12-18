\name{botapply}
\alias{botapply}
\title{# A function to use bot features in an apply fashion.}
\description{With bot apply you could write your independant loop in an apply fashion, results will be collected ans returned when all tasks will be done.}
\usage{botapply(tasks, task_processor, bot_cache_dir = "cache", ...)}
\arguments{
  \item{tasks}{A list of tasks, each task is a list of key values that will be passed as arguments to the task_processor. Note that task$out_filename is a mandatory parameter.}
  \item{task_processor}{A function that will be called for each task in the task list \emph{tasks}.}
  \item{bot_cache_dir}{the directory where task results are cached}
  \item{\dots}{Other arguments that will be passed to \emph{run_engine}.}
}



\author{Florent Chuffart}




\examples{
botapply(
  list(
    list(a=1, b=10, out_filename="task1"), 
    list(a=2, b=20, out_filename="task2"), 
    list(a=3, b=30, out_filename="task3"), 
    list(a=4, b=40, out_filename="task4")),  
  function(task) {
    return(task$a + task$b)})

# botapply(list(list(a=1, b=10, out_filename="task1")),function(task) {return(task$a + task$b)})
    
}
