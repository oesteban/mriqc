# Handover: validate FLAIR support (#1438) and the Harmonize fix (#1474)

This branch (`test/flair-validation` on `oesteban/mriqc`) exists only for this validation. Do not merge it.

## Context

- **#1438** (by @cooper-sharp) adds FLAIR to MRIQC's anatomical workflow. When `StructuralQC` finds the bias-corrected data "empty", it swaps in the raw FLAIR image and logs `N4 produced near-empty output for FLAIR image`.
- **Hypothesis (from the review on #1438):** the empty data come from `Harmonize`, not from N4.
  - `Harmonize` checked the WM mask size (30 voxels) before eroding the mask.
  - On FLAIR's weak GM/WM contrast, a sparse WM mask can pass the check and erode to nothing.
  - `np.median` of an empty selection is NaN, so the whole image becomes NaN.
  - `StructuralQC` reads it through `nan_to_num`, so it sees zeros: "seem empty".
- **#1474** checks the size after erosion, and falls back to the brain mask's 75th to 95th percentiles. It logs `White-matter mask too small to harmonize intensities`.

Commits on this branch:

| Ref | Commit | Content |
| --- | --- | --- |
| master | `33ff96eb` | base |
| **A** | `b0c4478b` | master + #1438 as submitted |
| **B** | `0e9ba6fe` | A + #1474 |
| head | (this file) | B + this handover and `validation/` |

`validation/harmonize_report.py` and `validation/compare_iqms.py` were tested on synthetic data. With a sparse mask, A's `Harmonize` gives `wm_eroded=0` and `out_nan_fraction=1.0`, and B's gives `0.0`.

## Goals

1. Reproduce #1438's failure with **A**, and confirm or refute the hypothesis.
2. Check that **B** processes FLAIR without the N4 fallback, and that the FLAIR reports and IQMs look sensible.
3. Check that T1w IQMs do not change between A and B.

## Requirements

- Linux amd64 with Docker; about 40 GB of disk, 16 GB of RAM and 8 or more cores.
- DataLad, to fetch the data (or the AWS CLI, see step 2).
- Allow about 2 hours per run (5 subjects, T1w and FLAIR each). A and B can run at the same time if the machine has the cores and memory.

## Steps

Run everything from the root of the clone, with this branch checked out.

### 0. Setup

```bash
git log --oneline -4   # expect: this handover, 0e9ba6fe (B), b0c4478b (A), ...
export DATA=$HOME/flair-validation
mkdir -p "$DATA"
```

### 1. Build an image for A and one for B

`Dockerfile_devel` installs the checkout (editable) on top of `nipreps/mriqc:latest`, which should be 26.0.0:

```bash
docker pull nipreps/mriqc:latest
docker run --rm nipreps/mriqc:latest --version   # expect 26.0.0

git checkout b0c4478b
docker build -f Dockerfile_devel -t mriqc:flair-a --build-arg VERSION=26.1.0.dev0+flaira .
git checkout 0e9ba6fe
docker build -f Dockerfile_devel -t mriqc:flair-b --build-arg VERSION=26.1.0.dev0+flairb .
git checkout test/flair-validation

# Sanity: only B has the Harmonize fix (prints False for A, True for B)
for t in a b; do
  docker run --rm --entrypoint /app/.pixi/envs/mriqc/bin/python mriqc:flair-$t \
    -c "import mriqc.interfaces.anatomical as m; print('$t', hasattr(m, 'IFLOGGER'))"
done
```

### 2. Get ds007486

All five subjects have one T1w and one FLAIR. The FLAIR is a 2D axial dark-fluid TSE (Siemens, 3 T) with 3 mm slices.

```bash
datalad clone https://github.com/OpenNeuroDatasets/ds007486.git "$DATA/ds007486"
(cd "$DATA/ds007486" && datalad get sub-*/anat/)
```

Without DataLad:

```bash
aws s3 sync --no-sign-request s3://openneuro.org/ds007486 "$DATA/ds007486" \
  --exclude '*' --include '*.json' --include '*.tsv' --include 'sub-*/anat/*'
```

### 3. Run A and B (participant level)

```bash
for t in a b; do
  mkdir -p "$DATA/out-$t" "$DATA/work-$t"
  docker run --rm \
    -v "$DATA/ds007486:/data:ro" \
    -v "$DATA/out-$t:/out" \
    -v "$DATA/work-$t:/work" \
    mriqc:flair-$t /data /out participant \
    -m T1w FLAIR -w /work \
    --no-sub --no-datalad-get --verbose-reports \
    --random-seed 1234 --nprocs 8 --omp-nthreads 4 --mem 16 \
    2>&1 | tee "$DATA/run-$t.log"
done
```

Keep `-w /work`: the reports in step 4 read paths stored in the work directory. The containers run as root, so `sudo chown -R "$USER" "$DATA"` afterwards if needed.

### 4. Collect the evidence

```bash
# a) Fallback and harmonization warnings
for t in a b; do
  echo "== $t"
  grep -c 'N4 produced near-empty output' "$DATA/run-$t.log"
  grep -c 'White-matter mask too small to harmonize' "$DATA/run-$t.log"
  grep -E 'ERROR|Traceback|crash' "$DATA/run-$t.log" | head
done

# b) Harmonize nodes: WM mask sizes before/after erosion, NaNs in the output
for t in a b; do
  echo "== $t"
  docker run --rm --entrypoint /app/.pixi/envs/mriqc/bin/python \
    -v "$DATA/work-$t:/work:ro" -v "$PWD/validation:/validation:ro" \
    mriqc:flair-b /validation/harmonize_report.py /work | tee "$DATA/harmonize-$t.tsv"
done

# c) IQMs: A vs B differences, and key IQMs per run in B
docker run --rm --entrypoint /app/.pixi/envs/mriqc/bin/python \
  -v "$DATA:/data:ro" -v "$PWD/validation:/validation:ro" \
  mriqc:flair-b /validation/compare_iqms.py /data/out-a /data/out-b | tee "$DATA/iqms.txt"

# d) Group level: expect a KeyError for FLAIR (QCGROUPS has no FLAIR yet, review item 3)
docker run --rm -v "$DATA/ds007486:/data:ro" -v "$DATA/out-b:/out" \
  mriqc:flair-b /data /out group -m T1w FLAIR 2>&1 | tail -20 | tee "$DATA/group-b.log"
```

Step d) should write `out-b/group_T1w.html` (T1w comes first) and then stop at FLAIR with `KeyError: 'FLAIR'`.

Then open the five FLAIR reports, `out-b/sub-*_FLAIR.html` (MRIQC writes reports at the top of the output folder; the IQMs are in `out-b/sub-*/anat/sub-*_FLAIR+iqms.parquet`). Look at:

- the brain mask;
- the tissue segmentation (GM and WM labels on the right tissues);
- the spatial normalization panel (FLAIR is normalized to the MNI T2w template);
- the background and noise panels.

## Reading the results

| Check | Hypothesis holds | Hypothesis refuted |
| --- | --- | --- |
| A: `N4 produced near-empty output` | present for some FLAIR runs | present |
| A: `harmonize-a.tsv`, those FLAIR rows | `wm_eroded` < 30, `out_nan_fraction` 1.0, `in_brain_median` well above 0 | `in_brain_median` near 0 (N4 output really empty) |
| B: `N4 produced near-empty output` | absent | present |
| B: `White-matter mask too small` | present for the same FLAIR runs | n/a |
| B: `harmonize-b.tsv` | `out_nan_fraction` 0.0 everywhere | n/a |
| T1w, A vs B (`iqms.txt`) | 0 or negligible differences | n/a |

If the hypothesis is refuted (N4's output really is empty), note the FLAIR runs affected and their `in_brain_median`, and keep the work directory: the skull-stripping (SynthStrip and N4) nodes are the next place to look.

If A shows no fallback at all, FLAIR worked on this dataset even without #1474. Report that too: it means the failure in #1438 depends on the data.

## What to report back

Post a comment on #1438, or hand these to the next session:

1. the warning counts from 4a, and any errors or crashes;
2. `harmonize-a.tsv` and `harmonize-b.tsv`;
3. `iqms.txt`;
4. the tail of `group-b.log`;
5. a short note per FLAIR report (masks, segmentation, normalization), with screenshots of anything odd;
6. the run times, if they look unusual.
