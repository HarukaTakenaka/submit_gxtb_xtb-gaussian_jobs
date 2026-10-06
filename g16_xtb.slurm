#!/bin/bash
#SBATCH --partition=notchpeak-guest
#SBATCH --account=owner-guest
#SBATCH --time=4:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=18G
#SBATCH -o slurm-%A_%a.out
#SBATCH -e slurm-%A_%a.err
#SBATCH --array=0-7%20
# Submit from this folder:  sbatch g16_xtb.slurm filenames.txt

module load gaussian16
module load xtb/6.7.1
export PATH=$HOME/bin:$PATH
which xtb || { echo "xtb not found"; exit 1; }
which xtb-gaussian || { echo "xtb-gaussian not found"; exit 1; }

ulimit -s unlimited
export OMP_STACKSIZE=1G
export OMP_NUM_THREADS=4,1
export OMP_MAX_ACTIVE_LEVELS=1
export MKL_NUM_THREADS=4

FILELIST=$1
WORKDIR=$PWD
file=$(sed -n "$(( SLURM_ARRAY_TASK_ID + 1 ))p" $FILELIST)
base=${file%.com}
export GAUSS_SCRDIR=/scratch/general/vast/$USER/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}_${base}
mkdir -p $GAUSS_SCRDIR
cp $WORKDIR/$file $GAUSS_SCRDIR/
cd $GAUSS_SCRDIR
g16 < $file > $WORKDIR/${base}.log
[[ -f ${base}.chk ]] && cp ${base}.chk $WORKDIR/
cd $WORKDIR
rm -rf $GAUSS_SCRDIR
