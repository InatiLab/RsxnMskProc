#!python

#====================================================================================================================

# Name: 		doVol_dumpLabels_rsxn.py

# Author:   	Katie Snyder
# Date:     	5/1/19
# Updated:      5/29/19

# Syntax:       python3 doVol_dumpLabels_rsxn.py
# Arguments:    --
# Description:  Pickles and dumps out training data and labels.
# Requirements: --
# Notes:  		Called in MRI_do_trainMsk.sh

#====================================================================================================================

# IMPORT MODULES

import numpy as np 
import nibabel
import sys
import os
from pathlib import Path
import joblib


#====================================================================================================================

# VARIABLES

wdir = os.getcwd()+'/'

#---------------------------------------------------------------------------------------------------------------------

# FUNCTIONS

def loadDset(filepath):
	data = np.loadtxt(filepath, dtype=np.float32)
	
	if data.ndim == 1:
		data = data.reshape([data.shape[0],1])

	return data

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: process features

X = loadDset(wdir+'t1_features')
y = loadDset(wdir+'labels')

#====================================================================================================================

# STEP 2: process labels

joblib.dump(X, wdir+'X')
joblib.dump(y, wdir+'y')

#====================================================================================================================
