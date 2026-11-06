"""Compare the IQMs of two MRIQC output directories, and tabulate a few key IQMs.

Run it inside the MRIQC image (it needs pandas and pyarrow)::

    docker run --rm --entrypoint /app/.pixi/envs/mriqc/bin/python \
        -v "$DATA:/data:ro" -v "$PWD/validation:/validation:ro" \
        mriqc:flair-b /validation/compare_iqms.py /data/out-a /data/out-b

For every ``*+iqms.parquet`` present in both directories it prints the largest absolute
difference across numeric IQMs (T1w should not change between runs A and B), and then
a table of key IQMs per run from the second directory.
"""

import sys
from pathlib import Path

import pandas as pd

KEY_IQMS = (
    'cjv',
    'cnr',
    'efc',
    'fber',
    'fwhm_avg',
    'inu_med',
    'qi_1',
    'qi_2',
    'snr_total',
    'wm2max',
)

first, second = Path(sys.argv[1]), Path(sys.argv[2])

print('== Largest absolute IQM difference (first vs. second)')
for path in sorted(first.glob('sub-*/**/*+iqms.parquet')):
    other = second / path.relative_to(first)
    if not other.exists():
        print(f'{path.name}\tmissing in {second}')
        continue
    df_a, df_b = pd.read_parquet(path), pd.read_parquet(other)
    columns = [c for c in df_a.select_dtypes('number').columns if c in df_b.columns]
    diff = (df_a[columns] - df_b[columns]).abs().max()
    print(f'{path.name}\t{diff.max():.6g}\t(worst: {diff.idxmax()})')

print(f'\n== Key IQMs in {second}')
rows = []
for path in sorted(second.glob('sub-*/**/*+iqms.parquet')):
    df = pd.read_parquet(path)
    row = {'run': path.name.replace('+iqms.parquet', '')}
    row |= {iqm: df[iqm].iloc[0] for iqm in KEY_IQMS if iqm in df.columns}
    rows.append(row)
print(pd.DataFrame(rows).to_string(index=False, float_format=lambda v: f'{v:.4g}'))
