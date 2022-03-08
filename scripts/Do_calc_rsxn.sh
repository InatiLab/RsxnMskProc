#!/bin/bash -i

set -e 

#====================================================================================================================

# Name:         Do_calc_rsxn.sh

# Author:       Kate Dembny 
# Date:         12/19/19
# Updated:      10/01/2020 SA

# Syntax:       ./Do_calc_rsxn.sh $SUBJ
# Arguments:    SUBJ: subject p-number

# Description:  Create resection mask computationally & allows for manual refinement
# Requirements: AFNI
# Notes:		Only required for running subjects when trying to preprocess with physio data


#====================================================================================================================

#INPUT

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
reg_dir=${data_dir}/${subj}/reg
clf_dir=${data_dir}/${subj}/clf
wdir=${data_dir}/${subj}/rsxn_msk/prep

echo -e "\033[0;35m++ Working on subject ${subj}. ++\033[0m"

#--------------------------------------------------------------------------------------------------------------------
# DATA CHECK

if [[ -f "${reg_dir}/y_class.nii" ]] && [[ -f "${reg_dir}/y_class_al.nii" ]] ; then
	echo -e "\033[0;35m++ classification data for both preop & postop exists. Continuing ... ++\033[0m"
	if [[ ! -d $wdir ]]; then
		mkdir -p $wdir; 
	fi
else
	echo -e "\033[0;35m++ $subj is missing clf classifiers for preop or postop scan. Please run Do_reg_lin_nonlin.sh. Exiting...  ++\033[0m"
	exit 1
fi


#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: # copy t1s for reference

cd "$wdir"
if [[ ! -f t1.nii ]]; then 
	echo -e "\033[0;35m++ Copying preop T1. ++\033[0m"
	cp ${reg_dir}/t1.nii .
fi

if [[ ! -f t1_postop.nii ]]; then
	echo -e "\033[0;35m++ Copying postop T1. ++\033[0m"
	cp ${reg_dir}/t1_postop_nonlin_al.nii t1_postop.nii
fi

#--------------------------------------------------------------------------------------------------------------------
 
# STEP 2: use AFNI skull strip algorithm to create brain mask

if [ ! -f t1.msk.d1.nii ]; then
	if [ ! -f t1.afni.ss.nii ]; then
		echo -e "\033[0;35m++ Skull stripping preop scan via afni ++\033[0m"
		3dSkullStrip -overwrite \
				-prefix t1.ss.nii \
				-ld 33 \
				-niter 777 \
				-shrink_fac_bot_lim 0.777 \
				-exp_frac 0.0666 \
				-input t1.nii
	fi

	3dAutomask -overwrite \
			-prefix t1.msk.nii \
			t1.ss.nii

	3dmask_tool \
			-input t1.msk.nii \
			-prefix t1.msk.d1.nii \
			-dilate_input 1
else
	echo -e "\033[0;35m++ Preop skull strip afni mask has already been created ++\033[0m"
fi

#--------------------------------------------------------------------------------------------------------------------

# STEP 3: skull strip y_class files

if [ ! -f brain.msk.nii ]; then
	echo -e "\033[0;35m++ Creating preop brain mask ++\033[0m"
	3dcalc \
			-a ${clf_dir}/y_class.nii \
			-b t1.msk.d1.nii \
			-exp 'amongst(a,3,4)*b' \
			-prefix brain.msk.nii
else
	echo -e "\033[0;35m++ Skull stripped preop brain mask already exists ++\033[0m"
fi

if [ ! -f brain_postop.msk.nii ]; then
	echo -e "\033[0;35m++ Creating postop brain mask ++\033[0m"
	3dcalc \
			-a ${clf_dir}/postop/y_class_al.nii \
			-b t1.msk.d1.nii \
			-exp 'amongst(a,3,4)*b' \
			-prefix brain_postop.msk.nii
else
	echo -e "\033[0;35m++ Skull stripped postop brain mask already exists ++\033[0m"
fi


#--------------------------------------------------------------------------------------------------------------------

# STEP 4: create first resection mask by subtracting the preop csf mask from the postop csf mask

if [ ! -f rsxn-v1-all.msk.nii ]; then
	echo  -e "\033[0;35m++ Subtracting preop from postop brain to create first resection mask. ++\033[0m"
	3dcalc \
			-a brain.msk.nii \
			-b brain_postop.msk.nii \
			-expr 'a-b' \
			-prefix rsxn-v1-all.msk.nii
fi
#optional step within brain mask
if [[ ! -f rsxn-v1.msk.nii ]]; then
	3dcalc \
			-a rsxn-v1-all.msk.nii \
			-expr 'step(a)' \
			-prefix rsxn-v1.msk.nii
else
	echo  -e "\033[0;35m++ First resection mask already exists. ++\033[0m"
fi

#--------------------------------------------------------------------------------------------------------------------

# STEP 7: run clustering and select largest cluster to edit 

if [ ! -f rsxn-v3.msk.nii ]; then
	echo -e "\033[0;35m++ Breaking Loose connection & selecting largest cluster for editing. ++\033[0m"
	3dLocalstat \
		-stat 'mode' \
		-nbhd 'SPHERE(-1.8)' \
		-prefix rxsn-v1.mode.msk.nii \
		rsxn-v1.msk.nii 

	3dclust \
			-1Dformat \
			-overwrite \
			-nosum \
			-1dindex 0 \
			-1tindex 1 \
			-dxyz=1 \
			-savemask rsxn-v2.msk.nii \
			1.01 1000 \
			rxsn-v1.mode.msk.nii
else
	echo -e "\033[0;35m++ Eroded cluster selection mask already exists ++\033[0m"
fi

#--------------------------------------------------------------------------------------------------------------------

# STEP 8: Checking out the computationally driven resection mask, and manually refined if it needs it
afni 
sleep 10
echo -e "\033[0;35m++ Does the computationally driven resection mask suffice your requirement? (Y/N) ++\033[0m"
read ynresponse

ynresponse=$(echo $ynresponse | tr '[:upper:]' '[:lower:]')

if [ "$ynresponse" == "y" ]; then
    echo -e "\033[0;35m++ Successfully drived the resection mask, Exiting....++\033[0m"
	if [ ! -f rsxn.msk.nii ]; then
		3dcalc \
		-a brain.msk.nii \
		-b rsxn-v2.msk.nii \
		-exp 'iszero(a-b)*b' \
		-prefix ../rsxn.msk.nii
	else
		echo -e "\033[0;35m++ Final resection mask already exists. ++\033[0m"
	fi

	exit 1
else
    echo -e "\033[0;35m++ Seems like we need some manual refinements, please follow the insturctions ++\033[0m" 
fi  
#-------------------------------------------------------------------------------------------------------------------------

# STEP 9: Dilate and erode around 1 resection mask to remove misalignment errors, and then check resection mask for erroneously included ventricles, etc edit if incorrect with Draw Dataset plugin

if [ ! -f resection-v5.msk.nii ]; then
	echo -e "\033[0;35mYou are about to have the chance to edit the mask for any errors that"
	echo -e "cannot be fixed computationally. In this session, afni will use the plugin Draw"
	echo -e "Dataset. The draw dataset plugin will open when afni opens."
	echo -e "To correctly alter the dataset, follow the following instructions:"
	echo ""
	echo -e "	1. Uncheck the box in the plugin window that reads 'Copy Dataset.'"
	echo -e "	2. Where it says 'Choose dataset to change directly' select"
	echo -e "	   rsxn-v2.msk.nii+orig."
	echo -e "	3. Change the number next to the box that reads 'Value' to 1"
	echo -e "	4. Set t1_postop.nii as the underlay and rsxn-v2.msk.nii as the overlay."
	echo -e "	5. Use the middle button on the mouse to draw cuts in the resection mask"
	echo -e "	   where it should not be connected and close large holes. Remember to think"
	echo -e "	   about what this looks like in 3D to ensure the masks now separate masks are"
	echo -e "	   not touching across slices. Making U-shaped cuts usually helps with this."
	echo -e "	6. IMPORTANT: When you are finished cutting, YOU MUST CLICK SAVE IN THE"
	echo -e "	   PLUGIN WINDOW! If you do not, the altered mask will not be saved."
	echo -e "	7. Double-click done in the afni main window, and type Y or N in response to"
	echo -e "	   whether or not the resection is connect in the command line. \033[0m"

	afni -yesplugouts \
		-com 'SWITCH_UNDERLAY t1_postop.nii' \
		-com 'OPEN_WINDOW A.plugin.Draw_Dataset' \
		t1_postop.nii rsxn-v2.msk.nii

	sleep 10 
	echo -e "\033[0;35m++ Is the resection now correct? (Y/N) ++\033[0m"
	read ynresponse

	if [ "$ynresponse" == "Y" ]; then
		echo "Continuing"
	else
		echo -e "\033[0;35m++ Resection mask has been marked as not correct. Exiting... ++\033[0m"
		exit 1
	fi

else
	echo -e "\033[0;35m++ Corrected resection mask already exists ++\033[0m"
fi
#--------------------------------------------------------------------------------------------------------------------

# STEP10: Run clustering and select largest cluster to be part of mask
if [ ! -f rsxn-v4.msk.nii ]; then
	echo -e "\033[0;35m++ Creating cluster resection mask ++\033[0m"
	3dclust \
			-1Dformat \
			-nosum \
			-1dindex 0 \
			-1tindex 1 \
			-dxyz=1 \
			-savemask rsxn-v3-clust.msk.nii \
			1.01 1000 \
			rsxn-v2.msk.nii
	3dcalc \
			-a rsxn-v3-clust.msk.nii \
			-exp 'equals(a,1)' \
			-prefix rsxn-v4.msk.nii
else
	echo -e "\033[0;35m++ Cluster selection mask already exists ++\033[0m"
fi
#--------------------------------------------------------------------------------------------------------------------

# STEP11: Final check up incase the manual correction exceeded the actual brain

if [ ! -f rsxn.msk.nii ]; then

	3dcalc \
		-a brain.msk.nii \
		-b rsxn-v4.msk.nii \
		-exp 'iszero(a-b)*b' \
		-prefix rsxn.msk.nii
else
	echo -e "\033[0;35m++ Final resection mask already exists. ++\033[0m"
fi

#--------------------------------------------------------------------------------------------------------------------
# STEP12: Check the final mask

if [[ ! -f "${data_dir}/${subj}/rsxn.msk.nii" ]]; then
	afni -yesplugouts \
		-com 'SWITCH_UNDERLAY t1_postop.nii' \
		-com 'OPEN_WINDOW A.plugin.Draw_Dataset' \
		t1_postop.nii rsxn.msk.nii

	sleep 10 
	echo -e "\033[0;35m++ Is the final resection mask correct? (Y/N) ++\033[0m"
	read ynresponse

	if [ "$ynresponse" == "Y" ]; then
		echo "Continuing"
		mv rsxn.msk.nii ${data_dir}/${subj}/rsxn_msk/.
	else
		echo -e "\033[0;35m++ Resection mask has been marked as not correct. Exiting... ++\033[0m"
		exit 1
	fi
else
	echo -e "\033[0;35m++ Final mask has been checked. ++\033[0m"
fi
