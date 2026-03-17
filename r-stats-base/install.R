# ==============================================================================
# STANDARD CRAN R PACKAGE INSTALLER (Source Compilation)
# ==============================================================================
options(repos = c(CRAN = "https://cloud.r-project.org/"))

# Load packages from text file
pkg_file <- "/tmp/r-packages.txt"
if (file.exists(pkg_file)) {
  pkgs <- readLines(pkg_file)
  pkgs <- sub("#.*", "", pkgs)       # Strip comments
  pkgs <- trimws(pkgs)               # Strip whitespace
  pkgs <- pkgs[pkgs != ""]           # Remove empty lines
} else {
  stop("CRITICAL ERROR: r-packages.txt not found in /tmp/")
}

# 1. Identify missing packages
installed <- installed.packages()[,"Package"]
new_pkgs <- pkgs[!(pkgs %in% installed)]

if(length(new_pkgs)) {
  message("Installing packages from CRAN: ", paste(new_pkgs, collapse=", "))
  install.packages(new_pkgs, dependencies=NA)
} else {
  message("All packages already installed.")
}

# 2. Verification
missing_final <- pkgs[!(pkgs %in% installed.packages()[,"Package"])]
if(length(missing_final)) {
  stop("CRITICAL ERROR: The following packages failed to install: ", paste(missing_final, collapse=", "))
} else {
  message("R Environment verification successful!")
}
