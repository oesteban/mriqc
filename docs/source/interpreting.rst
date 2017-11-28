

.. _interpreting:

=====================================
Interpreting the derivatives of MRIQC
=====================================
------------------------------------------------------------------
What to expect when you are expecting (for your images to be good)
------------------------------------------------------------------

This far, you probably :ref:`have successfully run MRIQC <running>` on
your dataset.
At this point, you have two valuable classes of derivatives:
:ref:`a table of Image Quality Metrics (IQMs) <measures>` and
:ref:`the MRIQC visual reports <reports>`.
Let's leverage those outcomes and curate our dataset.


Using the :abbr:`IQMs (image quality metrics)`
==============================================

MRIQC extracts a number of :abbr:`IQMs (image quality metrics)`
that can be used as features in machine learning frameworks
to predict how a human would have rated the quality of each
MRI scan (e.g. `our paper <https://doi.org/10.1371/journal.pone.0184661>`_).

However, and according to our experience, these :abbr:`IQMs (image quality metrics)`
suffer from "batch effects" and require the harmonization of the features
across different scanning centers and parameters.
In other words, with the data we have collected so far we would expect a
performance in accuracy of about 78% for the internal MRIQC classifier in
a new (unseen) sample of T1-weighed images.

Since your dataset is likely different to those that were used in
training the classifier (available 
`here <https://doi.org/10.1371/journal.pone.0184661.t001>`_), then
you should expect MRIQC to make mistakes if you apply the 
:ref:`internal classifier <classifier>` directly on your dataset,
without :ref:`extending the training of it to your data <clfcustom>`.
For the case of functional MRI, MRIQC does not even provide a
pre-trained classifier.

In sum, the :abbr:`IQMs (image quality metrics)` are hard to interpret and
wildly unknown (in terms of their typical distributions or, at least,
some ranges of values and data moments).
For these reasons, we recently started the 
`MRIQC Web-API <https://doi.org/10.1101/216671>`_, a resource for scientist
to train new automatic classifiers.
We hope that crowdsourcing the :abbr:`IQMs (image quality metrics)` will
provide insights over the normative values of these metrics, calculate
confidence intervals and discover trends and relationships with metadata
such as scanning parameters, or the version of MRIQC.

Therefore the :abbr:`IQMs (image quality metrics)` may not be the most
useful tool for scientists to curate their datasets (yet).
In other words, MRIQC does not avoid (yet) the time consuming visual assessment
of all images in a sample.
For that reason, MRIQC generates `thorough visual reports <reports>`_ to
minimize the time it takes for an expert to asses an image.
The next step using MRIQC is revising all images of your sample individually.
Finally, we will propose some "shortcuts" for when the visual
inspection of every image is not possible.


Visual inspection of an MRI scan using the reports
==================================================


Assessing T1-weighted images
----------------------------
