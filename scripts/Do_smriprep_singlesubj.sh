#!/bin/bash
#Template provided by Daniel Levitas of Indiana University
#Edits by Andrew Jahn, University of Michigan, 07.22.2020

#User inputs:
subj=$1
bids_root_dir=$2
nthreads=4
mem=20 #gb
cpus=6
container=docker #docker or singularity

#Begin 

#Convert virtual memory from gb to mb
mem=`echo "${mem//[!0-9]/}"` #remove gb at end
mem_mb=`echo $(((mem*1000)-5000))` #reduce some memory for buffer space during pre-processing

#export TEMPLATEFLOW_HOME=$HOME/.cache/templateflow
export FS_LICENSE=/Applications/freesurfer/7.1.1/license.txt

#Run fmriprep
if [ $container == singularity ]; then
  unset PYTHONPATH; singularity run -B $HOME/.cache/templateflow:/opt/templateflow $HOME/fmriprep.simg \
    $bids_root_dir/data $bids_root_dir/derivatives \
    participant \
    --participant-label $subj \
    --skip-bids-validation \
    --md-only-boilerplate \
    --fs-license-file /Applications/freesurfer/7.1.1/license.txt \
    --output-spaces  anat fsnative MNI152NLin2009cAsym MNI152NLin6Asym\
    --nthreads $nthreads \
    --stop-on-first-crash \
    --mem_mb $mem_mb \
    -w $bids_root_dir
else
  smriprep-docker $bids_root_dir/data $bids_root_dir/derivatives \
    participant \
    --participant-label $subj \
    --n_cpus $cpus \
    --fs-license-file /Applications/freesurfer/7.1.1/license.txt  \
    --fs-no-reconall \
    --output-spaces anat fsnative \
    --write-graph \
    --notrack \
    -w $bids_root_dir
fi
