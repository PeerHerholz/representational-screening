
========
Plotting
========

Every plotting function returns its figure or axes rather than
showing or saving it, so the same call works from a script, a
notebook and the documentation gallery.  Functions that draw a
single panel also accept an existing ``ax``, which makes them
composable into a larger layout.

Dissimilarity matrices
======================

:func:`~repscreen.plotting.rdm.plot_rdm` draws one matrix as a
heatmap.  :func:`~repscreen.plotting.rdm.plot_rdm_pair` draws two
side by side and reports their similarity in the figure title.

Compactness
===========

:func:`~repscreen.plotting.compactness.plot_compactness` draws
compactness per category, one line per model; pass
``sorted_compactness`` to see each model's own ordering and
``compactness`` to keep the categories aligned between the models.
:func:`~repscreen.plotting.compactness.plot_compactness_scatter`
plots one model's compactness against the other's and reports their
correlation.

Embeddings
==========

:func:`~repscreen.plotting.embedding.tsne_from_rdm` embeds a
dissimilarity matrix in two dimensions, passing it to t-SNE as
precomputed distances so the layout reflects the model's own
geometry.
:func:`~repscreen.plotting.embedding.plot_tsne_comparison` draws two
models' embeddings with the same colour per category, so a category
that clusters under one model and scatters under the other shows up
as a change in the layout of one colour.
:func:`~repscreen.plotting.embedding.cluster_quality` returns the
silhouette of the labelled grouping and the adjusted Rand index
against a k-means partition of the embedding.

Stimuli
=======

:func:`~repscreen.plotting.stimuli.plot_stimulus_grid` draws a
curated set column by column, so each column holds one category's
exemplars when the paths are grouped by category.  An image that
cannot be read is reported as a warning and skipped.

Signatures
==========

:func:`~repscreen.plotting.signatures.plot_category_signature` draws
a category's mean spectrum next to its pooled CIELab chromaticity,
with each sampled pixel drawn in its own colour.
