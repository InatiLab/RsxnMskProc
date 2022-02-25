#!python

#====================================================================================================================

# Name: 		doVol_predict_rsxn.py

# Author:   	Katie Snyder, shervin Abdollahi
# Date:     	5/1/19
# Updated:      10/20/2020

# Syntax:       python3 doVol_predict_rsxn.py data_dir
# Arguments:    data_dir: path to data_dir
# Description:  Predicts tissue classes.
# Requirements: --
# Notes:  		Called in Do_segment_predict.sh

#====================================================================================================================

# IMPORT MODULES

import numpy as np 
import nibabel
import sys
import os
from pathlib import Path
import joblib

#====================================================================================================================

# INPUT

data_dir=sys.argv[1]

#---------------------------------------------------------------------------------------------------------------------

# VARIABLES

pwd_dir = os.getcwd()
temp = os.path.basename(pwd_dir)
if temp == 'postop':
	temp_dir = os.path.dirname(pwd_dir)
	subj_dir = os.path.dirname(temp_dir)
	feat_dir=subj_dir+'/features/postop/'
else:
	subj_dir = os.path.dirname(pwd_dir)
	feat_dir=subj_dir+'/features/'
wdir=pwd_dir+'/'
clf_dir=data_dir+'/classifier/'

#---------------------------------------------------------------------------------------------------------------------

# FUNCTIONS

def loadData(text_dir):
	input_images=[text_dir+'t1_features.nii']

	images = [nibabel.load(x) for x in input_images]
	nvox = images[0].shape[0]*images[0].shape[1]*images[0].shape[2]

	rImgs = [np.reshape(img.get_fdata(), [nvox, -1]) for img in images]

	final = np.concatenate(rImgs, axis=1)

	return final

def saveNifti(data, wdir, output):
	ref = nibabel.load(wdir+'t1.nii')
	ref_shape = ref.shape

	out_image = nibabel.nifti1.Nifti1Image(data.reshape([ref_shape[0],ref_shape[1],ref_shape[2],-1]), affine=ref.affine)
	out_image.to_filename(wdir+output)

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: read in features

X = loadData(feat_dir)

#====================================================================================================================

# STEP 2: standardize 

stdsc = joblib.load(clf_dir+'stdsc')
X_std = stdsc.transform(X)

#====================================================================================================================

# STEP 3: predict

clf = joblib.load(clf_dir+'clf')

yclass = clf.predict(X_std)
yproba = clf.predict_proba(X_std)

#====================================================================================================================

# STEP 4: save out

saveNifti(yclass, wdir, 'y_class.nii')
saveNifti(yproba, wdir, 'y_proba.nii')

#====================================================================================================================
