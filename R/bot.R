######################################
# DISTRIBUTED COMPUTING TASKS ENGINE #
######################################

get_nb_proc = function ## Empirical function to find the number of core of the current computing node.
### This function uses \emph{/proc/cpuinfo} file for Debian and \emph{sysctl} for macosx. This fucntion could be extended or overrided by the user to adapt it to his own system.
() {
  if (Sys.info()[["nodename"]] == "cremone") {
    return(12)
  }
  dyn_nb_proc = as.integer(system("cat /proc/cpuinfo | grep 'core id' | wc -l",intern=TRUE))
  if (dyn_nb_proc == 0) {
    dyn_nb_proc = as.integer(system("cat /proc/cpuinfo | grep 'cpuid level' | wc -l",intern=TRUE))
    if (dyn_nb_proc == 0) {
      dyn_nb_proc = as.integer(system("sysctl -a | grep machdep.cpu.core_count | cut -d ' ' -f 2",intern=TRUE))
      if (dyn_nb_proc == 0) {
        return(1)
      }
    }
  }
  return(dyn_nb_proc)
### The number of core that the current computing node owns.
}

#' @importFrom fork fork
#' @importFrom fork wait
#' @export
run_engine = structure(function (## Execute bag of tasks parallely, on as many cores as the current computing node owns.
### This bag of tasks engine forks processes on as many cores as the current computing node owns. Each sub-process takes a task randomly in the list of tasks. For each task, it starts by taking a lock on this task (creating a file named out_filename.lock). Next, it executes the task_processor (a function) using the corresponding set of parameters (task). When this execution is completed, it dumps task_processor results into a results file (named out_filename.RData).
tasks,  ##<< A list of tasks, each task is a list of key values that will be passed as arguments to the task_processor. Note that task$out_filename is a mandatory parameter.
task_processor, ##<< A function that will be called for each task in the task list \emph{tasks}.
DEBUG=FALSE, ##<< If \emph{TRUE} no process will be forked, the list of tasks will be executed in the current process.
starter_name="~/.start_best_effort_jobs", ##<< Path to file that will be deleted after the execution of all tasks if \emph{rm_starter} is set to \emph{TRUE}.
rm_starter=FALSE, ##<< If \emph{TRUE} the file \emph{starter_name} will be deleted after the execution of all tasks.
log_dir="log", ##<< Path to the \emph{log} directory.
bot_cache_dir = "cache",   ##<< the directory where task results are cached
nb_proc=NULL, ##<< If not NULL fix the number of core on which tasks must be computed.
nb_loop = 0, ##<< the number of the first loop (experimental).
... ##<< Other arguments that will be passed to \emph{task_processor}.
){  
  if (!file.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE)
  }
  if (!file.exists(bot_cache_dir)) {
    dir.create(bot_cache_dir, recursive = TRUE)    
  }
  print(paste("#tasks: ", length(tasks)))
  compute_task_out_filename = function(task_processor, task) {
    task_processor_name = as.character(substitute(task_processor))
    ret = paste(task_processor_name, paste(task, collapse="_"), sep="_")    
    return(ret)
  }
  forked_part = function(){
    stats = list()
    stats$proc_id = proc_id
    stats$UID = UID
    set.seed(proc_id + UID)
    if (!DEBUG) {
      Sys.sleep(floor(runif(1,1,30)))
    }
    hostname = system("hostname", intern=TRUE)
    stats$hostname = hostname
    sink(paste(log_dir, "/proc_id_hostname_", proc_id, "_", hostname, ".log", sep=""), type =c("output", "message"), split = TRUE)    
    need_rerun = TRUE
    while (need_rerun){
      need_rerun = FALSE
      for (task in tasks) {
        # Check mandatory task attribute
        if (is.null(task$out_filename)) {
          task$out_filename = compute_task_out_filename(task_processor, task)
          # stop("Attribute task$out_filename is mandatory.")
        }
        # Check if task is already done or currently processed        
        lock_filename = paste(bot_cache_dir, "/", task$out_filename, ".lock", sep="")
        save_filename = task$save_filename
        lock_filename_bis = paste(bot_cache_dir, "/", task$out_filename, "_", (proc_id + UID) ,".lock4no", sep="")
        for_nothing_filename = paste(bot_cache_dir, "/", task$out_filename, "_", (proc_id + UID) , ".RData4no", sep="")
        stats$start_date = as.integer(format(Sys.time(), "%s"))
        if (nb_loop==0 & file.exists(lock_filename)) {
          print(paste("[proc_", proc_id , "] ", date(), " ", save_filename, " is locked... skipping.", sep=""))
          need_rerun = TRUE
        } else if (file.exists(save_filename)) {
          if (file.info(save_filename)$size == 0) {
            need_rerun = TRUE
            file.rename(save_filename, paste(save_filename, ".size0", sep="")) 
            print(paste("[proc_", proc_id , "] ", date(), " ", save_filename, " is empty... renaming file.", sep=""))                      
          } else {
            print(paste("[proc_", proc_id , "] ", date(), " ", save_filename, " exists... skipping.", sep=""))                      
          }
        } else {
          need_rerun = TRUE
          print(paste("[proc_", proc_id , "] ", date(), " taking lock on ", lock_filename, " and computing...", sep=""))
          save(stats, file=lock_filename)
          save(stats, file=lock_filename_bis)
          task_result = task_processor(task, ...)          
          stats$stop_date = as.integer(format(Sys.time(), "%s"))
          if (!file.exists(save_filename)) {
            save(task_result, stats, file=save_filename)
            file.remove(lock_filename) 
            file.remove(lock_filename_bis) 
          } else {
            print(paste("[proc_", proc_id , "] ", stats$stop_date, " ", save_filename, " already exists... So it have been computed for nothing.", sep=""))              
            save(task_result, stats, file=for_nothing_filename)
            file.remove(lock_filename) 
            file.remove(lock_filename_bis) 
          }
        }
      }
      nb_loop = nb_loop + 1
    }
    print("all tasks have been processed." )
    if (rm_starter) {
      print(paste("Removing ", starter_name, "...", sep=""))
      file.remove(starter_name)
    }
    sink()
  }
  tasks = lapply(tasks, function(task) {
    # Check mandatory task attribute
    if (is.null(task$out_filename)) {
      task$out_filename = compute_task_out_filename(task_processor, task)
    }
    task$save_filename = paste(bot_cache_dir, "/", task$out_filename, ".RData", sep="")
    return(task)    
  })
  orig_tasks = tasks
  UID = round(runif(1,1,1000000))
  if (DEBUG) {
    nb_proc = 1
    proc_id = 0
    print("running engine witout forking (DEBUG MODE)...")
    forked_part()
  } else {
    if (is.null(nb_proc)) {
      nb_proc = get_nb_proc()      
    }
    print(paste("running engine over ", nb_proc, " proc(s)...", sep=""))
    pids = c()
    for (proc_id in 1:nb_proc) {
      # Here we fork!
      tasks = sample(tasks)
      pids = c(pids,fork(forked_part))
    }
    # wait until each childs finishe, then display their exit status
    for (pid in pids) {
      wait(pid) 
    }
  } 
  # Returns task'$ output file names
  return(orig_tasks)
}, ex=function(){
  
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

})  


botapply = structure(function(## A function to use bot features in an apply fashion.
### With bot apply you could write your independant loop in an apply fashion, results will be collected ans returned when all tasks will be done.
tasks,  ##<< A list of tasks, each task is a list of key values that will be passed as arguments to the task_processor. Note that task$out_filename is a mandatory parameter.
task_processor, ##<< A function that will be called for each task in the task list \emph{tasks}.
bot_cache_dir = "cache",   ##<< the directory where task results are cached
... ##<< Other arguments that will be passed to \emph{run_engine}.
) {
  print(bot_cache_dir)
  run_engine(tasks, task_processor, bot_cache_dir=bot_cache_dir, ...)
  ret = apply(t(tasks), 2, function(task) {
    out_filename = task[[1]]$out_filename
    out_filename = paste(bot_cache_dir, "/", out_filename, ".RData", sep="")
    task_result = NULL
    load(out_filename)
    return(task_result) 
  })
  return(ret)
# It returns the list of compurted tasks
}, ex=function(){
  botapply(
    list(
      list(a=1, b=10, out_filename="task1"), 
      list(a=2, b=20, out_filename="task2"), 
      list(a=3, b=30, out_filename="task3"), 
      list(a=4, b=40, out_filename="task4")),  
    function(task) {
      return(task$a + task$b)})

  # botapply(list(list(a=1, b=10, out_filename="task1")),function(task) {return(task$a + task$b)})
      
})

bot_stats = function(## It compute and display statistique about a campain.
### This function browses bot_cache_dir directory and collects information about tasks. Next, it display gantt chart, tasks chart and how computing element are used. Finally it prints on outpout some stats about the campain.
bot_cache_dir = "cache",   ##<< the directory where task results are cached
WHITH4NO = FALSE  ##<< TRUE if you want to include redundante submission in the stats.
) {
  foo = apply(t(list.files(bot_cache_dir, "*RData")), 2, function(file) {
    load(paste(bot_cache_dir, "/", file, sep=""))  
    stats
    })
  stats = data.frame(t(matrix(unlist(foo), length(foo[[1]]))), stringsAsFactors=FALSE)
  names(stats) = names(foo[[1]])
  stats$efficient = 1

  if (WHITH4NO) {
    foo2 = apply(t(list.files(bot_cache_dir, "*4no")), 2, function(file) {
    load(paste(bot_cache_dir, "/", file, sep=""))  
    stats
    })
    stats2 = data.frame(t(matrix(unlist(foo2), length(foo2[[1]]))), stringsAsFactors=FALSE)
    names(stats2) = names(foo2[[1]])
    stats2$efficient = 2
    stats = rbind(stats, stats2)
  }

  stats$start_date = as.integer(stats$start_date)/60
  stats$stop_date = as.integer(stats$stop_date)/60
  zero = min(stats$start_date)
  stats$start_date = stats$start_date - zero
  stats$stop_date = stats$stop_date - zero
  stats$duration = stats$stop_date - stats$start_date

  stats$core = paste(stats$hostname, stats$proc_id, sep="_")
  cores = sort(unique(stats$core))

  x11(width=16, height=9)
  layout(matrix(1:3, nrow=1), respect=TRUE)

  stats = stats[ order(stats$start_date), ]
  plot(0,0,col=0, xlim=c(0, max(stats$stop_date)), ylim=c(0, length(stats[,1])), main=paste("Gantt Chart for", bot_cache_dir), xlab="Time (min)", ylab= "Task")
  arrows( stats$start_date, 1:length(stats[,1]), stats$stop_date, 1:length(stats[,1]), 0, 0, col=stats$efficient)

  stats = stats[ order(stats$duration, decreasing=TRUE),]
  plot(0,0,col=0, xlim=c(0, max(stats$duration)), ylim=c(0, length(stats[,1])), main=paste("Task duration for", bot_cache_dir), xlab="Time (min)", ylab= "Task")
  arrows( rep(0, length(stats[,1])), 1:length(stats[,1]), stats$duration, 1:length(stats[,1]), 0, 0, , col=stats$efficient)

  plot(0,0,col=0, xlim=c(0, max(stats$stop_date)), ylim=c(0, length(cores)), main=paste("Task repartition over computing elements for", bot_cache_dir), xlab="Time (min)", ylab= "Computing Element")
  ys = apply(t(stats$core), 2, function(core){which(cores == core)})
  arrows( stats$start_date, ys, stats$stop_date, ys, 0, 0, col=stats$efficient)

  format.timediff <- function(diff) {
      hr <- diff%/%60
      min <- floor(diff - hr * 60)
      sec <- round(diff%%1 * 60,digits=2)
      return(paste(hr,min,sec,sep=':'))
  }

  cat("#cores....................", length(cores), "\n", sep="")
  cat("#tasks....................", length(stats[stats$efficient==1, 1]), "\n", sep="")
  cat("cpu.time..................", format.timediff(sum(stats[stats$efficient==1, ]$duration)), "\n", sep="")
  cat("time......................", format.timediff(max(stats[stats$efficient==1, ]$stop_date)), "\n", sep="")
  cat("speedup...................", sum(stats[stats$efficient==1, ]$duration)/max(stats[stats$efficient==1, ]$stop_date), "\n", sep="")
  cat("efficiency................", sum(stats[stats$efficient==1, ]$duration)/max(stats[stats$efficient==1, ]$stop_date)/length(cores), "\n", sep="")
  return(stats)
  # It returns the data.frame of collected informations.
}
