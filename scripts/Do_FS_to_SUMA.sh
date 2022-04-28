#!/bin/bash -i

#====================================================================================================================

# Name: 		FS_to_SUMA.sh

# Author:   	Shervin Abdollahi
# Date:     	02/25/2022
# Updated:      --

# Syntax:       FS_to_SUMA.sh SUBJ
# Arguments:    SUBJ: subject ID
# Description:  Asks you to check FreeSurfer output. If correct, it converts FreeSurfer data to AFNI/SUMA format
# 				and aligns the surface volume back to the registered T1.
# Requirements: 1) FreeSurfer
#				2) AFNI
# Notes:     	This script is interactive
# Update log:
#	-

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

#---------------------------------------------------------------------------------------------------------------------

# REQUIREMENTS CHECK

cmd_path=$(which freeview)
if [ "${cmd_path}" == '' ]; then
	echo -e "\033[0;35m++ recon-all not found. Please make sure Freesurfer is installed and setup. Exiting... ++\033[0m"
	exit 1
fi

#---------------------------------------------------------------------------------------------------------------------

# DATA CHECK

if [ -d "$fs_subj_dir" ]; then
	echo -e "\033[0;35m++ Check Freesurfer for subject $subj... ++\033[0m"
	cd $fs_subj_dir || exit
else
	echo -e "\033[0;35m++ Freesurfer not run for subject $subj using version stable-v6.0.0 on a Linux system. Please run MRI_do_02.sh. Exiting...++\033[0m"
	exit 1
fi

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: check Freesurfer output

freeview -v mri/T1.mgz mri/brainmask.mgz \
-f surf/lh.white:edgecolor=blue \
surf/lh.pial:edgecolor=red \
surf/rh.white:edgecolor=blue \
surf/rh.pial:edgecolor=red \
surf/rh.inflated:visible=0 \
surf/lh.inflated:visible=0

echo -e "\033[0;35m++ Is Freesurfer correct? Enter Y if correct and N if not. ++\033[0m"
read ynresponse

if [ "$ynresponse" == "Y" ]; then
	echo -e "\033[0;35m++ Freesurfer correct. Continuing... ++\033[0m"
else
	echo -e "\033[0;35m++ Freesurfer not correct. Exiting... ++\033[0m"
	exit 1
fi

#====================================================================================================================

# STEP 2: create SUMA folder

if [ -d "SUMA" ]; then
	echo -e "\033[0;35m++ @SUMA_Make_Spec_FS has already been run. Please delete to rerun. ++\033[0m"
else
	@SUMA_Make_Spec_FS \
		-NIFTI \
		-sid $subj \
		-fspath $fs_subj_dir \
		-make_rank_dsets \
		-extra_fs_dsets \
		-no_ld
fi

#====================================================================================================================

# STEP 3: copy SUMA results to derivative folder
cd ${derivative_dir}
if [ ! -f "t1+orig" ] && [ ! -f "t1.nii" ] ; then 
	3dcopy *_desc-preproc_T1w.nii.gz ./t1
	3dcopy *_desc-preproc_T1w.nii.gz ./t1.nii
fi

if [ ! -f "SurfVol.nii" ]; then
	cp -r ${fs_subj_dir}/SUMA/*_SurfVol.nii ./SurfVol.nii
fi

if [ ! -f "aseg_rank.nii" ]; then
	3dcopy ${fs_subj_dir}/SUMA/aseg_rank.nii.gz ./aseg_rank.nii
fi

if [ ! -f "aseg_rank.niml.lt" ]; then
	cp -r ${fs_subj_dir}/SUMA/aseg_rank.niml.lt ./aseg_rank.niml.lt
fi
#====================================================================================================================

# STEP 4: Align surface volume
if [ ! -f "SurfVol_Alnd_Exp+orig.HEAD" ]; then
	@SUMA_AlignToExperiment \
		-exp_anat t1+orig \
		-surf_anat SurfVol.nii \
		-wd \
		-align_centers 
fi
#====================================================================================================================

# STEP 5:  Align and resample the aseg segmentation to registered t1
my_out="aseg_rank_Alnd_Exp.nii"
if [ ! -f "${my_out}" ]; then
	3dAllineate \
		-master SurfVol_Alnd_Exp+orig \
		-1Dmatrix_apply SurfVol_Alnd_Exp.A2E.1D \
		-input aseg_rank.nii \
		-prefix $my_out \
		-final NN
fi

my_rs="aseg_rank_Alnd_Exp.rs.nii"
if [ ! -f "${my_rs}" ]; then
	3dresample \
		-master t1.nii \
		-input $my_out \
		-prefix $my_rs
	3drefit -copytables $my_out $my_rs
fi

#====================================================================================================================
#STEP 6: Generate original features fro T1w 
if [ -f "t1.nii" ] && [ ! -f "t1_features.nii" ]; then
	echo -e "\033[0;35m++ Calculating original features for t1... ++\033[0m"
	compute_features --num_scales 3 --output t1_features.nii  t1.nii 			
fi