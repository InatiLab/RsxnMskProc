#!/bin/bash

#====================================================================================================================

# Name: 		Do_axialize_anat.sh

# Author:   	shervin Abdollahi
# Date:     	10/06/2020
# Updated:      

# Syntax:       ./Do_axialize_anat.sh  SUBJ
# Arguments:    SUBJ: subject ID 
# Description:  Axialize preoperative T1 with respect to TT_N27 template. 

# Requirements: 1) You will need python installed and an environemnt set up to run python3 called p3.7
#				2) AFNI
# Notes:        
#====================================================================================================================
# INPUT

#set usage
function display_usage {
    echo -e "\033[0;35m++ usage: $0 [-h|--help] SUBJ ++\033[0m"
    exit 1
}
# set defaults
alt=false; 

#parse option
while [ -n "$1" ];do
    #check case, if valid option found, toggle its respective variable on 
    case "$1" in
        -h|--help)   display_usage ;;   #display help
		*)           break ;;        #prevent any further shifting by breaking
    esac
    shift      
done
subj="$1"

#Define Paths
scripts_dir=`pwd`
proj_dir=${scripts_dir%/*}
data_dir=${proj_dir}/data
orig_dir=${data_dir}/${subj}/orig
wdir=${data_dir}/${subj}/reg

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

conda_dir=`conda info --base`
if [ ! -d "${conda_dir}/envs/p3.7" ]; then
	if [ ! -d "$HOME/.conda/envs/p3.7" ]; then
		echo -e "\033[0;35m++ Conda environment p2.7 does not exist. Please run 'conda create -n p3.7 python=3.7'. Exiting... ++\033[0m"
		exit 1
	fi
fi

#---------------------------------------------------------------------------------------------------------------------

#DATA CHECK 
if [ -a "${orig_dir}/mprage.nii" ]; then
	
    echo -e "\033[0;35m++ Axializing subject $subj to TT_N27 template... ++\033[0m"
	
    if [ ! -d "${wdir}/t1w_align" ]; then
		mkdir -p ${wdir}/t1w_align
	fi
else
	echo -e "\033[0;35m++ Subject $subj does not have mprage in ${orig_dir}.Please import the data to correct folder. Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: Preop T1 Axialization

cd ${wdir}/t1w_align

if [ -a "${wdir}/t1w_align/t1w_FINAL.nii.gz" ]; then\

    echo -e "\033[0;35m++ Axialized T1 already exists. ++\033[0m"
else
    fat_proc_axialize_anat                            \
        -inset   ${orig_dir}/mprage.nii  \
        -refset  ${scripts_dir}/__files/TT_N27+tlrc    \
        -prefix  t1w_FINAL                            \
        -mode_t1w         			   			      \
		-extra_al_inps "-nomask"		              \
		-extra_al_opts "-newgrid 1.0"				  \
		-focus_by_ss				                  \
                            
fi

if [ ! -f "${wdir}/t1.nii" ]; then
	3dcalc \
		-a t1w_FINAL.nii.gz \
		-prefix ${wdir}/t1.nii \
		-datum short \
		-expr 'a'
fi


#====================================================================================================================

# STEP 2: Copying over postop mprage if it exists

if [ ! -f "${wdir}/t1_postop.nii" ] && [ -f "${orig_dir}/mprage_postop.nii" ]; then

    3dcopy ${orig_dir}/mprage_postop.nii ${wdir}/t1_postop.nii
fi
