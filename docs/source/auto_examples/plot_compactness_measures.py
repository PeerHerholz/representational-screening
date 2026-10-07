"""
Comparing compactness measures
==============================

The compactness measure decides which categories the screening
considers differently represented, so it is worth seeing how much the
nine available measures agree before settling on one.
"""

# %%
# Scoring every measure
# ---------------------

import matplotlib.pyplot as plt
import numpy as np

from _synthetic import MODELS, synthetic_activations
from repscreen.metrics.compactness import (
    COMPACTNESS_MEASURES,
    compute_compactness,
    compute_compactness_pair,
)
from repscreen.plotting.compactness import plot_compactness_scatter
from repscreen.screening.categories import screen_categories

activations, category_names = synthetic_activations(seed=0)

scores = {
    measure: compute_compactness(
        activations[MODELS[0]], measure=measure
    )
    for measure in COMPACTNESS_MEASURES
}
for measure, values in scores.items():
    print(
        f"{measure:30s} range "
        f"[{values.min():+.3f}, {values.max():+.3f}]"
    )

# %%
# How much do they agree?
# -----------------------
#
# The measures live on different scales, so they are compared by
# rank.  ``Davies-Bouldin_Index`` is negated first, because for that
# measure a higher value marks a *less* compact category.

names = list(COMPACTNESS_MEASURES)
ranked = np.array(
    [
        np.argsort(
            np.argsort(
                -scores[name]
                if name == "Davies-Bouldin_Index"
                else scores[name]
            )
        )
        for name in names
    ]
)
agreement = np.corrcoef(ranked)

figure, axes = plt.subplots(figsize=(7, 6))
image = axes.imshow(agreement, cmap="coolwarm", vmin=-1, vmax=1)
axes.set_xticks(range(len(names)))
axes.set_xticklabels(names, rotation=90)
axes.set_yticks(range(len(names)))
axes.set_yticklabels(names)
axes.set_title("Rank agreement between compactness measures")
figure.colorbar(image, ax=axes, shrink=0.8)
figure.tight_layout()
plt.show()

# %%
# Do the models agree with each other?
# ------------------------------------
#
# Under the default measure, plotting one model's compactness against
# the other's shows how much room the screening has: a low
# correlation means many categories are compact under one model and
# diffuse under the other.

compactness = compute_compactness_pair(
    activations, MODELS, category_names, measure="R-squared"
)
figure, _ = plot_compactness_scatter(
    compactness.compactness, MODELS
)
plt.show()

# %%
# Does the measure change the selection?
# --------------------------------------
#
# Running the category stage with each measure and comparing the
# selections shows how much the choice matters in practice.

reference = None
for measure in ("R-squared", "Fisher_discriminant", "CH_Index"):
    pair = compute_compactness_pair(
        activations, MODELS, category_names, measure=measure
    )
    selected = set(
        screen_categories(
            activations,
            MODELS,
            pair,
            category_names,
            n_categories=12,
        ).selected_names
    )
    if reference is None:
        reference = selected
        print(f"{measure:22s} reference selection")
    else:
        shared = len(reference & selected)
        print(f"{measure:22s} shares {shared}/12 categories")
