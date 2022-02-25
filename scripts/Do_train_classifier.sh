
#!/bin/bash

#====================================================================================================================

# Name: 		Do_train_classifier.sh

# Author:   	Katie Snyder, shervin Abdollahi
# Date:     	5/1/19
# Updated:      10/20/2020

# Syntax:       ./Do_train_classifier.sh [-h|--help] [-l|--list SUBJ_LIST] [SUBJ [SUBJ ...]] 
# Arguments:    SUBJ1-5: subject ID
# Description:  Trains a classifier on tissue classes (Other, CSF, GM, WM)
# Requirements: 1) Python
# Notes:     	--

#====================================================================================================================
# INPUT


# INPUT

# set usage
function display_usage {
	echo -e "\033[0;35m++ usage: $0 [-h|--help] [-l|--list SUBJ_LIST] [SUBJ [SUBJ ...]] ++\033[0m"
	exit 1
}

# set defaults
subj_list=false

# parse options
while [ -n "$1" ]; do
    case "$1" in
    	-h|--help) 		display_usage ;; 		# display help
		-l|--list) 		subj_list=$2; shift ;; 	# subject list
	    *)  			break ;; 				# prevent any further shifting by breaking
    esac
    shift 	# shift to next argument
done

# check if subj_list argument was given; if not, get positional arguments
if [[ ${subj_list} != "false" ]]; then
	# check that subj_list exists
	if [ ! -f ${subj_list} ]; then
		echo -e "\033[0;35m++ ${subj_list} subject list does not exist. Please enter a valid subject list filepath. Exiting... ++\033[0m"
		exit 1
	else
		subj_arr=($(cat ${subj_list}))
	fi
else
	subj_arr=("$@")
fi

# check that length of subject list is greater than zero
if [[ ! ${#subj_arr} -gt 0 ]]; then
	echo -e "\033[0;35m++ Subject list length is zero; please specify at least one subject to perform batch processing on ++\033[0m"
	display_usage
fi


#---------------------------------------------------------------------------------------------------------------------
#Define Paths
scripts_dir=`pwd`
proj_dir=${scripts_dir%/*}
data_dir=${proj_dir}/data
rsxn_dir=${data_dir}/Training/derivatives/smriprep/

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: run training script (no correction)

if [ ! -f "${data_dir}/classifier/clf" ]; then
	python3 ${scripts_dir}/__files/python/doVol_train_rsxn.py ${rsxn_dir} ${subj_arr[@]}
fi
#====================================================================================================================

# STEP 2: write out subjects file

if [ -f "${data_dir}/classifier/clf_info" ]; then
	if [ ! -f "${data_dir}/classifier/subjects" ]; then
			echo -e "${subj_arr[@]}" > ${data_dir}/classifier/subjects
	fi
fi
	#====================================================================================================================
