#!/bin/bash -i

#====================================================================================================================

# Name: 		Do_segment_predic.sh

# Author:   	shervin Abdollahi
# Date:     	10/20/2020
# Updated:      

# Syntax:       ./Do_segment_predic.sh -p SUBJ
# Arguments:    SUBJ: subject ID
# Description:  Creates JEM original features and uses the classification model to segment the brain into GM, WM and CSF.
# Requirements: 1) AFNI
#				2) Python - jem environment 
# Notes:     

#====================================================================================================================

# INPUT

#set usage
function display_usage {
    echo -e "\033[0;35m++ usage: $0 [-h|--help] [-p|--postop] SUBJ ++\033[0m"
    exit 1
}
# set defaults
postop=false;  

#parse option
while [ -n "$1" ];do 
    case "$1" in
        -h|--help)   display_usage ;;   #display help
        -p|--postop) postop=true ;;     #post-op
        *)           break ;;               
    esac
    shift       #shift to next argument
done

subj="$1"
   
#----------------------------------------------------
#Define Paths
scripts_dir=`pwd`
proj_dir=${scripts_dir%/*}
data_dir=${proj_dir}/data
segment_dir=${data_dir}/
reg_dir=${segment_dir}/${subj}/reg

#------------------------------------------------------
#postop flag		
if [[ ${postop} == 'true' ]]; then
	
	postop_subdir='/postop'
	my_t1='t1_postop.nii'
else
	postop_subdir=''
	my_t1='t1.nii'
fi

feat_dir="${segment_dir}/${subj}/features${postop_subdir}"
clf_dir="${segment_dir}/${subj}/clf${postop_subdir}"
#--------------------------------------------------------
# DATA CHECK

if [ -f "${reg_dir}/${my_t1}" ]; then

	if [ ! -d "$feat_dir" ] && [ ! -d "$clf_dir" ] ; then
		mkdir -p ${feat_dir}
		mkdir -p ${clf_dir}
	fi
else
	echo -e "\033[0;35m++ Subject $subj has not been registered. Please run ./Do_axialize_anat.sh. Exiting... ++\033[0m"
	exit 1
fi

if [ -f "${data_dir}/classifier/clf_info" ]; then
	subjects=`cat ${data_dir}/classifier/subjects`
else
	echo -e "\033[0;35m++ No clf_info file found in ${data_dir}/classifier Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================
#	 BEGIN SCRIPT
#====================================================================================================================

# STEP 1: Generate features

source activate base

cd ${feat_dir}

my_out="t1_features.nii"
if [[ ${postop} == "true" ]]; then
	my_inp="t1_postop.nii"
else
	my_inp="t1.nii"
fi
if [ -f "${reg_dir}/$my_inp" ] && [ ! -f "$my_out" ]; then
	echo -e "\033[0;35m++ Calculating original features for $img... ++\033[0m"
	compute_features --num_scales 3  --output $my_out $reg_dir/$my_inp 			
fi

#====================================================================================================================
# STEP 2: Predict Brain Classes

#Make sure subject was not part of training subjects
for (( i=1; i<6; i++ )); do
	train_subj=${subjects%%' '*} #hv1
	subjects=${subjects#*' '} #hv2 hv3 hv5 hv6
	if [ *$train_subj* == *$subj* ]; then
		echo -e "\033[0;35m++ Subject $subj was used to train classifier so cannot predict. Exiting... ++\033[0m"
		exit 1
	fi
done


#copy over the T1
cd ${clf_dir}
if [ ! -f "t1.nii" ]; then
	cp -r ${reg_dir}/$my_t1 t1.nii
fi

# run the classifier
if [ ! -f "y_class.nii" ] || [ ! -f "y_proba.nii" ]; then
	echo -e "\033[0;35m++ Predicting tissue classes... ++\033[0m"
	python ${scripts_dir}/__files/python/doVol_predict_rsxn.py ${data_dir}
fi

#refit output
for dset in 'y_class.nii' 'y_proba.nii'; do
	my_space=`3dinfo -space $dset`
	my_view=`3dinfo -av_space $dset`
	if [ "${my_space}" != 'ORIG' ] || [ "${my_view}" != '+orig' ]; then
		3drefit -space ORIG -view orig $dset
	fi
done

conda deactivate