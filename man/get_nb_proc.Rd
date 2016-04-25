\name{get_nb_proc}
\alias{get_nb_proc}
\title{# Empirical function to find the number of core of the current computing node.}
\description{This function uses \emph{/proc/cpuinfo} file for Debian and \emph{sysctl} for macosx. This fucntion could be extended or overrided by the user to adapt it to his own system.}
\usage{get_nb_proc()}

\value{The number of core that the current computing node owns.}

\author{Florent Chuffart}





