"""Summarize every Harmonize node in an MRIQC work directory, as a TSV on stdout.

Node results store absolute paths, so run this inside the MRIQC image with the work
directory mounted where the run had it (``/work``)::

    docker run --rm --entrypoint /app/.pixi/envs/mriqc/bin/python \
        -v "$DATA/work-a:/work:ro" -v "$PWD/validation:/validation:ro" \
        mriqc:flair-b /validation/harmonize_report.py /work

Columns:

* ``input``: the bias-corrected image Harmonize received.
* ``in_brain_median``: its median within the brain mask. Near zero means the input was
  already empty, i.e., the N4 (skull-stripping) output, not Harmonize, is the problem.
* ``wm_thresholded`` and ``wm_eroded``: WM voxels at probability >= ``thresh``, before
  and after the erosion. On master, the size check (``min_size``, 30) ran before the
  erosion only.
* ``out_nan_fraction``: fraction of NaN voxels in Harmonize's output. 1.0 means the
  "corrected data seem empty" error (or #1438's N4 fallback) comes from Harmonize.
"""

import sys
from pathlib import Path

import nibabel as nb
import numpy as np
import scipy.ndimage as nd
from nipype.utils.filemanip import loadpkl

work = Path(sys.argv[1])
print('input\tin_brain_median\twm_thresholded\twm_eroded\tmin_size\tout_nan_fraction\tnode')
for res_file in sorted(work.rglob('result_harmonize.pklz')):
    result = loadpkl(res_file)
    inputs = result.inputs

    data = np.asanyarray(nb.load(inputs['in_file']).dataobj)
    brain = np.asanyarray(nb.load(inputs['brain_mask']).dataobj) > 0.5
    wm = np.asanyarray(nb.load(inputs['wm_mask']).dataobj) >= inputs['thresh']
    eroded = (
        nd.binary_erosion(wm, structure=nd.generate_binary_structure(3, 2))
        if inputs['erodemsk']
        else wm
    )

    out_file = getattr(result.outputs, 'out_file', None)
    nan_fraction = (
        float(np.isnan(np.asanyarray(nb.load(out_file).dataobj)).mean())
        if out_file and Path(out_file).exists()
        else 'missing'
    )

    print(
        '\t'.join(
            str(v)
            for v in (
                Path(inputs['in_file']).name,
                round(float(np.median(data[brain])), 2),
                int(wm.sum()),
                int(eroded.sum()),
                inputs['min_size'],
                nan_fraction,
                res_file.parent.relative_to(work),
            )
        )
    )
