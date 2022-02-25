#!/bin/bash -i

set -e 
#====================================================================================================================

# Name:         Do_reg_lin_nonlin.sh

# Author:       shervin Abdollahi
# Date:         10/1/2020
# Updated:      

# Syntax:       ./Do_reg_lin_nonlin.sh $SUBJ
# Arguments:    SUBJ: subject p-number

# Description:  this script will perform linear and nonlinear registration between postop T1 and preop T1
# Requirements: AFNI
# Notes:		Only required for running subjects when trying to preprocess with physio data


#====================================================================================================================
# INPUT

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

#Define Paths
scripts_dir=`pwd`
proj_dir=${scripts_dir%/*}
data_dir=${proj_dir}/data
reg_dir=${data_dir}/${subj}/reg
clf_dir=${data_dir}/${subj}/clf

#--------------------------------------------------------------------------------------------------------------------

# REQUIREMENT CHECK

conda_dir=`conda info --base`
if [ ! -d "${conda_dir}/envs/p3.7" ]; then
	if [ ! -d "$HOME/.conda/envs/p3.7" ]; then
		echo -e "\033[0;35m++ Conda environment p3.7 does not exist. Please run 'conda create -n p3.7 python=3.7'. Exiting... ++\033[0m"
		exit 1
	fi
fi
#----------------------------------------------------------------------------------------------------
echo -e "\033[0;35m++ Working on subject ${subj}. ++\033[0m"
#----------------------------------------------------------------------------------------------------

cd ${reg_dir}

if [ ! -f "t1_postop.rs.nii" ]; then

    source activate p3.7
    align_epi_anat.py \
        -dset1 t1_postop.nii \
        -dset2 t1.nii   \
        -master_dset1 BASE \
        -deoblique on \
        -align_centers yes \
        -dset1_strip None \
        -dset2_strip None \
        -giant_move \
        -cost nmi \
        -suffix _lin_al  
    conda deactivate

    3dAllineate  \
        -master t1.nii \
        -1Dmatrix_apply t1_postop_lin_al_mat.aff12.1D \
        -input  t1_postop.nii \
        -prefix t1_postop.rs.nii \
    
else 
    echo -e "\033[0;35m++ Linear alignment has been already performed for subject ${subj}. ++\033[0m"
fi

echo -e "\033[0;35m++ Lets perform non-linear alignment. ++\033[0m"

3dQwarp \
    -base t1.nii \
    -source t1_postop.rs.nii \
    -prefix t1_postop_nonlin_al.nii \
    -blur 0 3 \
    -maxlev 5 

echo -e "\033[0;35m++ lets check the alignment on AFNI ++\033[0m"
afni 
sleep 10
echo -e "\033[0;35m++ Are the registration correct? (Y/N) ++\033[0m"
read ynresponse

ynresponse=$(echo $ynresponse | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Continuing to apply the transformation to the postop y_class.nii ++\033[0m"
else
    echo -e "\033[0;35m++ Registration incorrect, Exiting.... ++\033[0m"
    exit 1
fi

3dNwarpApply \
    -nwarp 't1_postop_nonlin_al_WARP.nii t1_postop_lin_al_mat.aff12.1D' \
    -master t1.nii \
    -source ${clf_dir}/postop/y_class.nii \
    -prefix ${clf_dir}/postop/y_class_al.nii \
    -interp NN \
    -overwrite

3dcopy ${clf_dir}/postop/y_class_al.nii ${reg_dir}/y_class_al.nii
3dcopy ${clf_dir}/y_class.nii  ${reg_dir}/y_class.nii


afni 
sleep 10
echo -e "\033[0;35m++ Do segmentations look good? (Y/N) ++\033[0m"
read ynresponse

ynresponse=$(echo $ynresponse | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Successfully aligned postop y_class to preop y_class ++\033[0m"
else
    echo -e "\033[0;35m++ segmentation bad, Exiting.... ++\033[0m"
    exit 1
fi  

