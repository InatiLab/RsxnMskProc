#!python

#====================================================================================================================

# Name: 		doVol_train_rsxn.py

# Author:   	Katie Snyder
# Date:     	5/1/19
# Updated:      5/29/19

# Syntax:       python3 doVol_train_rsxn.py RSXN_DIR SUBJ1 SUBJ2 SUBJ3 SUBJ4 SUBJ5
# Arguments:    RSXN_DIR: path to MRI projects directory
#				SUBJ1-5: subject IDs for training controls
# Description:  Trains tissue classifier.
# Requirements: --
# Notes:  		Called in MRI_do_train.sh

#====================================================================================================================

# IMPORT MODULES

import numpy as np 
import pandas as pd 
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import train_test_split
import sys
import os
from pathlib import Path
import joblib
import getpass
import socket
import datetime

#====================================================================================================================

# INPUT

if len(sys.argv) == 7:
	rsxn_dir=sys.argv[1]
	subjects=[sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]]
elif len(sys.argv) == 6:
	rsxn_dir=sys.argv[1]
	subjects=[sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]]
elif len(sys.argv) == 5:
	rsxn_dir=sys.argv[1]
	subjects=[sys.argv[2], sys.argv[3], sys.argv[4]]
else:
	print('usage: python train.py rsxn_DIR SUBJ_ID1 SUBJ_ID2 SUBJ_ID3 SUBJ_ID4 SUBJ_ID5')
	sys.exit()

smriprep_dir=os.path.dirname(rsxn_dir)
derivative_dir=os.path.dirname(smriprep_dir)
train_dir=os.path.dirname(derivative_dir)
data_dir=os.path.dirname(train_dir)
#---------------------------------------------------------------------------------------------------------------------
# check that subject has training data

for subj in subjects:
	for file in ['X', 'y']:
		my_file = Path(rsxn_dir+f'/{subj}/trainMsk/{file}') 
		if not my_file.is_file():
			print('{} does not have {} in trainMsk directory. Please run MRI_do_trainMsk_forClassifier.sh. Exiting...'.format(subj,file))
			sys.exit()

#---------------------------------------------------------------------------------------------------------------------

# check that this script has not already been run

my_output1 = Path(data_dir+'/classifier/stdsc')
my_output2 = Path(data_dir+'/classifier/clf')
if my_output1.is_file() and my_output2.is_file():
	print('Classifier already exists. Please delete or move to rerun. Exiting.')
	sys.exit()

#---------------------------------------------------------------------------------------------------------------------

# make directory

if not os.path.exists(data_dir+'/classifier'):
	os.makedirs(data_dir+'/classifier')

#---------------------------------------------------------------------------------------------------------------------

# define function

def loadData(subj):

	top_dir=rsxn_dir+'/'+subj+'/trainMsk'

	X = joblib.load(top_dir+'/X')
	y = joblib.load(top_dir+'/y')

	return X, y

#====================================================================================================================
# BEGIN SCRIPT
#====================================================================================================================

# STEP 1: load training data

X=[]
y=[]
for subj in subjects:
	print('Working on subject {}'.format(subj))
	xx, yy = loadData(subj)
	X.append(xx)
	y.append(yy)

X_all = np.vstack(X)
y_all = np.ravel(np.vstack(y))

X_train, X_test, y_train, y_test = train_test_split(X_all, y_all, test_size=0.2)
#====================================================================================================================

# STEP 2: standardize data

stdsc = StandardScaler()
X_train_std = stdsc.fit_transform(X_train)
X_test_std = stdsc.fit_transform(X_test)

joblib.dump(stdsc, data_dir+'/classifier/stdsc')
#====================================================================================================================

# STEP 3: classify

clf = LogisticRegression(solver='saga', penalty='l2', C=0.0001, multi_class='multinomial', class_weight=None)
clf.fit(X_train_std, y_train)
accuracy = clf.score(X_test_std, y_test)

joblib.dump(clf, data_dir+'/classifier/clf')
#====================================================================================================================

# STEP 4: write out a text file with info about the classifier

if os.path.exists(data_dir+'/classifier/clf_info'):
	os.remove(data_dir+'/classifier/clf_info')

clf_info = open(data_dir+"/classifier/clf_info", "w")

clf_info.write("Training subjects: {}".format(subjects))
clf_info.write('\n')

clf_info.write("Testing acuracy: {}".format(accuracy))
clf_info.write('\n')

nX=X_train.shape[1]
clf_info.write("N_features: {}".format(nX))

username = getpass.getuser()
clf_info.write("Run by: {}".format(username))
clf_info.write('\n')

now = datetime.datetime.now()
day = now.day
month = now.month
year = now.year
clf_info.write("Date: {}/{}/{}".format(month,day,year))
clf_info.write('\n')

hostname = socket.gethostname()
clf_info.write('Hostname: {}'.format(hostname))

clf_info.close()

#====================================================================================================================
