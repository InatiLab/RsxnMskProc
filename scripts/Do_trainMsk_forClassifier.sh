#!/bin/bash

#====================================================================================================================

# Name: 		Do_trainMsk_forClassifier.sh

# Author:   	Katie Snyder
# Date:     	5/1/19
# Updated:      5/27/19

# Syntax:       ./Do_trainMsk_forClassifier.sh SUBJ
# Arguments:    SUBJ: subject ID
# Description:  Creates training mask for tissue classification training.
# Requirements: 1) AFNI
#				2) Python
# Notes:     	--

#====================================================================================================================

#set usage
function display_usage {
    echo -e "\033[0;35m++ usage: $0 [-h|--help] SUBJ ++\033[0m"
    exit 1
}

#parse option
while [ -n "$1" ];do
    case "$1" in
        -h|--help)   display_usage ;; 
        *)           break ;;       
    esac
    shift      
done
subj="$1"

#---------------------------------------------------------------------------------------------------------------------
#Define Paths
scripts_dir=`pwd`
proj_dir=${scripts_dir%/*}
data_dir=${proj_dir}/data
derivative_dir=${data_dir}/Training/derivatives/smriprep/${subj}/anat
fs_subj_dir=${data_dir}/Training/derivatives/freesurfer/${subj}
wdir=${data_dir}/Training/derivatives/smriprep/${subj}/trainMsk


#---------------------------------------------------------------------------------------------------------------------

# DATA CHECK

if [ -f "${derivative_dir}/t1.nii" ]; then
	
	if [ -f "${derivative_dir}/aseg_rank_Alnd_Exp.rs.nii" ] && [ -f "${derivative_dir}/aseg_rank.niml.lt" ]; then
		if [ -f "${derivative_dir}/t1_features.nii" ]; then
			echo -e "\033[0;35m++ Creating training mask for subject $subj... ++\033[0m"
				if [ ! -f "$wdir" ]; then
					mkdir -p ${wdir}
				fi
				cd ${wdir}
				3dcopy ${derivative_dir}/t1.nii ./t1.nii
		else
			echo -e "\033[0;35m++ Subject $subj does not have features data. Please run MRI_do_bandpass.sh. Exiting... ++\033[0m"
			exit 1
		fi
	else
		echo -e "\033[0;35m++ Subject $subj does not have aligned aseg_rank/labeltable. Please run Do_FS_to_SUMA.sh and check registration. Exiting... ++\033[0m"
		exit 1
	fi
else
	echo -e "\033[0;35m++ Subject $subj does not have t1.nii in `pwd`. Please run Do_smriprep_singlesubj.sh Exiting... ++\033[0m"
	exit 1
fi

#---------------------------------------------------------------------------------------------------------------------

# SET DEFAULTS

LGM=`@MakeLabelTable -labeltable ${derivative_dir}/aseg_rank.niml.lt -lkeys "Left-Cerebral-Cortex"`
RGM=`@MakeLabelTable -labeltable ${derivative_dir}/aseg_rank.niml.lt -lkeys "Right-Cerebral-Cortex"`
LWM=`@MakeLabelTable -labeltable ${derivative_dir}/aseg_rank.niml.lt -lkeys "Left-Cerebral-White-Matter"`
RWM=`@MakeLabelTable -labeltable ${derivative_dir}/aseg_rank.niml.lt -lkeys "Right-Cerebral-White-Matter"`

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: get GM, WM, CSF, and other mask

#if [ ! -f "gm.msk.nii" ]; then
#	3dcalc \
#		-a ${derivative_dir}/aseg_rank_Alnd_Exp.rs.nii \
#		-prefix gm.msk.nii \
#		-expr "amongst(a, $LGM, $RGM)"
#fi

#--------------------

#if [ ! -f "wm.msk.nii" ]; then
#	3dcalc \
#		-a ${derivative_dir}/aseg_rank_Alnd_Exp.rs.nii \
#		-prefix wm.msk.nii \
#		-expr "amongst(a, $LWM, $RWM)"
#fi

#--------------------

#if [ ! -f "csf.msk.nii" ]; then
#	3dcalc \
#		-a ${derivative_dir}/*label-CSF_probseg.nii \
#		-prefix csf.msk.nii \
#		-expr 'step(a-0.5)'
#fi

#====================================================================================================================

# STEP 2: calculate labels

if [ ! -f "labels_v1.msk.nii" ]; then
	3dcalc \
		-a csf.msk.nii \
		-b gm.msk.nii \
		-c wm.msk.nii\
		-prefix labels_v1.msk.nii \
		-expr "2*a+3*b+4*c"
fi

#====================================================================================================================

# STEP 8: mask labels

if [ ! -f "all.labels.msk.nii" ]; then
	3dcalc \
		-a labels_v1.msk.nii \
		-prefix all.labels.msk.nii \
		-expr '(within(a,2,4)*a)'
fi

#====================================================================================================================
# STEP 3: calculate skull stripped labels

if [ ! -f "labels.msk.nii" ]; then
	3dcalc \
		-a all.labels.msk.nii \
		-b ${derivative_dir}/*desc-brain_mask.nii.gz \
		-prefix labels.msk.nii \
		-datum float \
		-expr 'a*step(b)'

	@MakeLabelTable -labeltable labels.msk.niml.lt \
					-lab_v Other 1 -lab_v CSF 2 -lab_v GM 3 -lab_v WM 4 \
					-dset labels.msk.nii
fi

#---------------------------------------------------------------------------
#STEP 4: generate a brain mask
if [ ! -f "all.msk.nii" ]; then
	3dAutomask \
		-prefix all.msk.nii \
		labels.msk.nii
fi
#====================================================================================================================

# STEP 9: generate training features

if [ ! -f "t1_features" ]; then
	3dmaskdump \
		-mask all.msk.nii \
		-noijk \
		-o  t1_features \
		${derivative_dir}/t1_features.nii
fi

#---------------------------------------------

if [ ! -f "labels" ]; then
	3dmaskdump \
		-mask all.msk.nii  \
		-noijk \
		-o labels \
		labels.msk.nii
fi

#====================================================================================================================

# STEP 10: dump out X and y

if [ ! -f "X" ] || [ ! -f "y" ]; then
	python3 ${scripts_dir}/__files/python/doVol_dumpLabels_rsxn.py 
fi

#====================================================================================================================
