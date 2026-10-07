"""Synthetic activation sets shared by the gallery examples.

The activations the paper screens are not distributed with the
repository, so the examples build a pair of activation sets whose
categories differ in compactness between the two models.  That is the
structure the screening looks for, so the examples exercise the real
code path on data small enough to ship.
"""

import numpy as np

MODELS = ("model_compact", "model_diffuse")
N_CATEGORIES = 24
N_PER_CATEGORY = 10
N_FEATURES = 32


def synthetic_activations(seed: int = 0):
    """Build a pair of category-structured activation sets.

    Each model places every category's exemplars around a category
    centroid, but with a per-category spread that differs between the
    two models, so the two disagree about which categories form tight
    clusters.

    Parameters
    ----------
    seed : int
        Seed for the random generator.

    Returns
    -------
    activations : dict
        Mapping from model name to an array of shape
        ``(N_CATEGORIES, N_PER_CATEGORY, N_FEATURES)``, with unit
        length rows.
    category_names : list of str
        Category labels in category order.
    """
    rng = np.random.default_rng(seed)
    centroids = rng.normal(size=(N_CATEGORIES, 1, N_FEATURES))

    activations = {}
    for index, model in enumerate(MODELS):
        spread = rng.uniform(0.3, 2.5, size=(N_CATEGORIES, 1, 1))
        if index == 1:
            spread = spread[::-1]
        noise = rng.normal(
            size=(N_CATEGORIES, N_PER_CATEGORY, N_FEATURES)
        )
        values = centroids + spread * noise
        flat = values.reshape(-1, N_FEATURES)
        flat = flat / np.linalg.norm(flat, axis=1, keepdims=True)
        activations[model] = flat.reshape(
            N_CATEGORIES, N_PER_CATEGORY, N_FEATURES
        )

    category_names = [
        f"{i:04d}_category{i}" for i in range(N_CATEGORIES)
    ]
    return activations, category_names
