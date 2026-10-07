"""Comparison of dissimilarity matrices across model layers."""

from typing import Dict, List, Sequence

from .rdm import compare_rdms


def compare_rdms_per_layer(
    rdms: Dict[str, Sequence],
    models: Sequence[str],
    metric: str = "cosine",
) -> Dict[str, Dict[str, List[float]]]:
    """Compare every pair of models layer by layer.

    Parameters
    ----------
    rdms : dict
        Mapping from model name to its dissimilarity matrices, one
        per layer and in layer order.
    models : sequence of str
        Model names to compare.  The result is keyed so that each
        pair appears once, under the model that comes first here.
    metric : str
        Metric passed to
        :func:`~repscreen.metrics.rdm.compare_rdms`.

    Returns
    -------
    dict
        ``result[model1][model2]`` holds one similarity per layer.

    Raises
    ------
    ValueError
        If the models do not have the same number of layers.
    """
    depths = {model: len(rdms[model]) for model in models}
    if len(set(depths.values())) > 1:
        raise ValueError(
            f"Every model must have the same number of layers, got "
            f"{depths}."
        )

    similarities: Dict[str, Dict[str, List[float]]] = {
        model: {} for model in models
    }
    for i, model1 in enumerate(models):
        for model2 in models[i:]:
            similarities[model1][model2] = [
                compare_rdms(
                    rdms[model1][layer],
                    rdms[model2][layer],
                    metric=metric,
                )
                for layer in range(depths[model1])
            ]
    return similarities
