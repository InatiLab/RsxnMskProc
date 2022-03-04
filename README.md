# Brain segmentation & resection mask generation pipleline 

## Processing Step
```
For this processing pipeline, dataset will be in following structure:
RsxnMskProc 
    -README.md
    -scripts
    -data
      -sub-01
         -orig
         -reg
         -features
         -clf
         -rxsn_msk  
      -classifier
      -Training

To begin processing you will need to first place your preoperative mprage of your healthy voluneers under data/${subj}/orig/ as mprage.nii, and once you have the classifier model trained, you can import both pre and post operative mprage images of your patients as mprage.nii & mprage_postop.nii under orig directory.

Note: Before starting this pipeline, please create a conda environment with python version 3.7, you can achieve that by running the following commandline 'conda create -n p3.7 python=3.7'. once you have your conda environment setup, you will need to install JEM package by running 'pip install jem nibabel smriprep-docker'
Throughout this pipleine you will also need to have AFNI and Freesurfer installed. please check out the the following links to install these software packages: 
(https://afni.nimh.nih.gov/pub/dist/doc/htmldoc/background_install/install_instructs/index.html)
(https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall)

```

# Training a classifier
```
./Do_smriprep_singlesubj.sh $subj $bids_root_path
```
-  The first step to getting your data ready for training is to preprocess them under the smriprep pipeline. (https://www.nipreps.org/smriprep/)
-  From this pipleine you get a spatially normalized, B1 filed coorecred, segmented and skull stripped brain which you can use for your training.
-  smriprep expect the dataset to be BIDS validated, convert you dataset accordingly and place it under RsxnMskProc/data/Training/data 
```NOTE: you can validate your BIDS dataset with (https://github.com/bids-standard/bids-validator)```
-  smriprep can be run with or without freesurfer. If you have a pre-run freesurfer resutls driven from the same input T1, please place them under RsxnMskProc/data/Training/derivatives/freesufer and add option --fs-no-reconall to your smriprep-docker commandline. (this analysus should take ~30 min for each subejct). Not running freesurfer allow for smriprep to compute the segmentation through FAST FSL funtion (which has shown to give you a better estimation of CSF mask, with that we will threshold the csf_probability map by 0.5 which helps us in having a better training csf mask)
-  However, if you dont have freesurfer results, smriprep can run that for you & you dont need to change anything in your code. (one caveat of running the smriprep with freesurfer is that the probability maps that you get are less realsitic as they seem eroded espicially for csf mask you most likely loose alot of csf around the brain)
-  Rememeber to change your FS_License path if its installed in a different location or its a different version (mine is version 7.1.1)

```
./Do_FS_to_SUMA.sh $subj
```
-  At first the script allows you to check freesurfer outputs.
-  If the freesurfer outputs are approved,it will then convert freesurfer outputs into AFNI/SUMA format & aligns the surface volume back to the registered t1.
-  It also align and resamples freesurfer aseg segmentation to the registered t1.
-  This script will computes 13 Original features.
   
```
./Do_trainMask_forClassifier.sh $subj
```
-  this script will then take cortical grey matter and White matter mask from freesurfer as well as csf mask from smriprep to create training mask sets

```Note: By now you should have run all your training subjects through the above preprocessing scripts```

```
./Do_train_classifier.sh [-l|--list SUBJ_LIST] [SUBJ [SUBJ ...]]
```
-  This script will combine all your training dataset and uses %80 of those for training & %20 for testing 
-  the training and testing dataset are randomly chosen
-  At last the script will save the classification model, so it can be used for the patient population.

 
# Applying the classification model to new dataset

```
./Do_axialize_anat.sh  $subj
```
-   for this script to run you will need to have a conda environmnet with python==3.7 as well as AFNI software installed
-   this script will axialize preop mprage with respect to TT_N27 template. 

```
./Do_segment_predict.sh -p $subj
```
-   This script first generates the 13 original feature vectors from the axialized T1.
-   Then, it will uses the learned classfication model to segment the brain into GM, WM and CSF.
-   You will need to run this script once with option '-p' for postop brain segmentation and once without it for preop brain segmentation.

```
./Do_reg_lin_nonlin.sh $subj
```
-   This script will first apply linear registration between preop axialized T1 and postop T1. 
-   It then applies a nonlinear transformation to get the postop brain as closely registered to the prepop brain.
-   You will get a chance to look at the nonlinear registeration through AFNI GUI
-   If you approve the registeration results, it will then applies the transformation matrices to the postop segmentation under $subj/clf/postop/y_class.nii to bring everyting in alignment.

```
./Do_calc_rxsn.sh $subj
```
-   This script generate resection mask computationally at first
-   It then allows you to browse through the resection mask in AFNI and if you need to make some manual refinement, you can do so using AFNI.








