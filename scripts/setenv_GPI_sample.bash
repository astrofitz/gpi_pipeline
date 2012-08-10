#  Set up environment variables for GPI IFS Software
#	bash version
# HISTORY:
#       2010-01-25  Created. M. Perrin
#       2010-02-01  Added IDL_DIR, enclosing quotes - M. Perrin
#       2012-08-10  Rewrite to conform to latest DRP setup - ds

# *** NOTE** This is the sample file for what the GPI environment
# variables should be. You should copy this file to some different
# filename, e.g.  setenv_GPI_mycomputername.csh, in your home dir 
# and edit it there. 
# Do NOT edit this file itself to customize it for your computer, 
# since this is under version control and thus your edits would just
# conflict with other users changing this same file too.
# Source this file from your .bashrc or .bash_profile


#----- Required paths (editing required) --------------------
#GPI_DATA_ROOT is a helper path only.  If desired you can set 
#all paths independently.  
#NOTE: If you are pulling all data from the vospace, do NOT 
#put your queue and Reduced directories on the same path as 
#the raw data.  Make these local.
export GPI_DATA_ROOT="~/GPI/data/"           	        # base dir for all data
export GPI_DRP_QUEUE_DIR="$GPI_DATA_ROOT/queue/"        # where is the DRP Queue directory?
export GPI_RAW_DATA_DIR="$GPI_DATA_ROOT/Detector/"      # where is raw data?
export GPI_REDUCED_DATA_DIR="$GPI_DATA_ROOT/Reduced/"   # where should we put reduced data?

#---- Optional paths (no editing genererally needed) -------
# these variables are optional - you may omit them if your 
# drp setup is standard
#GPI_CODE_ROOT is a helper path only.  If desired you can set 
#all paths independently.  
export GPI_CODE_ROOT="~/GPI/"                               # location of all GPI code (pipeline, gpitv, etc.)
export GPI_DRP_DIR="$GPI_CODE_ROOT/pipeline/"	            # pipeline code location
export GPI_DRP_CONFIG_DIR="$GPI_DRP_DIR/config/"            # default config settings 
export GPI_DRP_TEMPLATES_DIR="$GPI_DRP_DIR/drf_templates"	# pipeline DRF template location

export GPI_DRP_CALIBRATIONS_DIR="$GPI_REDUCDED_DATA_DIR/calibrations/"	# pipeline calibration location
export GPI_DRP_LOG_DIR="$GPI_REDUCDED_DATA_DIR/logs/"	                # default log dir

#---- DST install only (optional) -----
export GPI_DST_DIR="$GPI_CODE_ROOT/dst/"	 

#--- Update paths -------------------------
export PATH="${PATH}:${GPI_DRP_DIR}/scripts"
export IDL_PATH="${IDL_PATH}:+${GPI_CODE_ROOT}"
