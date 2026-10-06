# submit_gxtb_xtb-gaussian_jobs
# g16_xtb.slurm

A SLURM job-array script that runs many Gaussian 16 jobs which use xTB as the external energy
engine through [`xtb-gaussian`](https://github.com/aspuru-guzik-group/xtb-gaussian) (e.g. g-xTB or
GFN2-xTB). Each array task runs one `.com` file from a list, in its own scratch directory, and writes
the `.log` (and `.chk`) back to the submission folder.

Use it for optimizations, frequency calculations, relaxed scans, TS optimizations, and IRCs at the
xTB level, before moving to DFT.

## How it works

```
filenames.txt          array task 0  ->  line 1  ->  mol_a.com  ->  mol_a.log, mol_a.chk
  mol_a.com            array task 1  ->  line 2  ->  mol_b.com  ->  mol_b.log, mol_b.chk
  mol_b.com            ...
  ...
```

For each task, the script:

1. Loads Gaussian and xTB and checks that `xtb` and `xtb-gaussian` can be found (it stops
   immediately if not, instead of letting Gaussian crash later).
2. Reads line *N*+1 of the file list for task *N* (Windows line endings are stripped automatically).
3. Warns if the `-P` thread count in the input's `external=` line differs from `--cpus-per-task`.
4. Copies the input to a private scratch folder, runs `g16`, copies the `.log` and `.chk` back, and
   deletes the scratch folder.

## Requirements

- SLURM, Gaussian 16, and xTB available on the cluster (as modules, or on your `PATH`)
- [`xtb-gaussian`](https://github.com/aspuru-guzik-group/xtb-gaussian) installed somewhere on your
  `PATH` (the script adds `~/bin`); it is a Perl script, so `perl` must be available
- Gaussian inputs whose route uses `external="xtb-gaussian ..."`, for example:

  ```
  %mem=16000MB
  %chk=mol_a.chk
  # external="xtb-gaussian -P 4 --gxtb --charge 0 --uhf 1 --acc 0.0001" UGBS opt=(maxcycles=200,nomicro) freq=noraman

  mol_a

  0 2
  <coordinates>

  ```

  `UGBS` is a placeholder basis; all energies come from xTB. `--uhf` must equal the multiplicity − 1,
  and `--charge` must equal the Gaussian charge.

## Setup (once per cluster)

Open `g16_xtb.slurm` and edit the lines marked for your cluster:

| Setting | In the script | Notes |
|---|---|---|
| Partition and account | `#SBATCH --partition`, `--account` | Guest/preemptable partitions may kill long jobs |
| Time and memory | `--time`, `--mem` | `--mem` should be a little more than `%mem` in the inputs |
| CPUs | `--cpus-per-task` | Must match `-P` in the inputs' `external=` line |
| Modules | `module load gaussian16`, `module load xtb/6.7.1` | Use `module spider xtb` to see versions |
| `xtb-gaussian` location | `export PATH=$HOME/bin:$PATH` | Change if you installed it elsewhere |
| Scratch | `SCRATCH_ROOT=...` | Your cluster's fast scratch file system |

## Usage

Put the script, the `.com` files, and a file list (one `.com` name per line) in the same folder,
then submit from that folder:

```bash
ls *.com > filenames.txt
sbatch --array=0-$(( $(wc -l < filenames.txt) - 1 ))%20 g16_xtb.slurm filenames.txt
```

`--array=0-(N-1)` runs one task per line; `%20` limits how many run at once. To test a single input
before submitting everything:

```bash
sbatch --array=0 g16_xtb.slurm filenames.txt
```

Monitor and manage jobs with:

```bash
squeue -u $USER          # queued / running
scancel <jobID>          # cancel
sacct -j <jobID>         # state and run time of finished tasks
```

## Output

- `<name>.log` and `<name>.chk` next to each `.com`
- `slurm-<jobID>_<task>.out` / `.err` for each task: the task's input name, any warnings, and
  "Finished" or "Check" at the end

To check all results at once, use [`check_gxtb_logs.py`](../check_gxtb_logs) in the same folder.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `xtb not found` / `xtb-gaussian not found` in `.out` | Module name or `PATH` line wrong for your cluster |
| `export: ... not a valid identifier` | A malformed `export PATH=` line (often a space after `=`) |
| Gaussian `FIO-F-217 ... read past end of file` | xTB crashed, so Gaussian found no energy; run xTB directly on the structure to see its error |
| `Input ... not found` | Submitted from a different folder than the inputs, or a typo in the file list |
| `cannot stat '...com'$'\r'` | File list with Windows line endings (older versions of this script); run `dos2unix filenames.txt` |
| `WARNING: ... uses -P 8 but --cpus-per-task=4` | Change one so they match; otherwise xTB over- or under-uses the CPUs |
| Jobs disappear without a termination message | Time limit or preemption; restart from the last geometry |

If you prepared files on Windows, run `dos2unix *.com filenames.txt` on the cluster before submitting.
