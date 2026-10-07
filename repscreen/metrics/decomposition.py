"""Linear decompositions and shape alignment of activation spaces."""

from dataclasses import dataclass
from typing import Tuple

import numpy as np


@dataclass
class PrincipalComponents:
    """Principal component decomposition of a data matrix.

    Parameters
    ----------
    coefficients : numpy.ndarray
        Array of shape ``(n_variables, n_variables)``, each column
        holding the coefficients of one component, ordered by
        descending eigenvalue.
    scores : numpy.ndarray
        Array of shape ``(n_variables, n_observations)``: the
        centred data projected onto the components, one row per
        component.
    eigenvalues : numpy.ndarray
        Eigenvalues of the covariance matrix, descending.
    explained : numpy.ndarray
        Percentage of total variance carried by each component.
    """

    coefficients: np.ndarray
    scores: np.ndarray
    eigenvalues: np.ndarray
    explained: np.ndarray


def principal_components(data: np.ndarray) -> PrincipalComponents:
    """Decompose a data matrix into its principal components.

    Parameters
    ----------
    data : numpy.ndarray
        Array of shape ``(n_observations, n_variables)``, with
        observations in rows and variables in columns.

    Returns
    -------
    PrincipalComponents
        Coefficients, scores, eigenvalues and explained variance,
        ordered by descending eigenvalue.

    Raises
    ------
    ValueError
        If ``data`` is not two-dimensional.
    """
    if data.ndim != 2:
        raise ValueError(
            f"data must be two-dimensional (n_observations, "
            f"n_variables), got shape {data.shape}."
        )

    centred = (data - data.mean(axis=0)).T
    eigenvalues, coefficients = np.linalg.eigh(np.cov(centred))

    order = np.argsort(-eigenvalues)
    eigenvalues = eigenvalues[order]
    coefficients = coefficients[:, order]

    return PrincipalComponents(
        coefficients=coefficients,
        scores=np.dot(coefficients.T, centred),
        eigenvalues=eigenvalues,
        explained=100.0 * eigenvalues / np.sum(eigenvalues),
    )


def classical_mds(
    distances: np.ndarray,
) -> Tuple[np.ndarray, np.ndarray]:
    """Embed a distance matrix by classical multidimensional scaling.

    Only the dimensions with a positive eigenvalue are returned, so
    a matrix that is not exactly Euclidean yields the embedding of
    its Euclidean part.  Each dimension is determined up to an
    overall sign.

    Parameters
    ----------
    distances : numpy.ndarray
        Square, symmetric distance matrix.

    Returns
    -------
    embedding : numpy.ndarray
        Array of shape ``(n_items, n_positive)``, one column per
        retained dimension.
    eigenvalues : numpy.ndarray
        All eigenvalues of the doubly centred matrix, descending.

    Raises
    ------
    ValueError
        If ``distances`` is not square.
    """
    if distances.ndim != 2 or distances.shape[0] != distances.shape[1]:
        raise ValueError(
            f"A distance matrix must be square, got shape "
            f"{distances.shape}."
        )

    size = len(distances)
    projector = np.eye(size) - np.ones((size, size)) / size
    centred = -projector.dot(distances**2).dot(projector) / 2.0

    eigenvalues, eigenvectors = np.linalg.eigh(centred)
    order = np.argsort(eigenvalues)[::-1]
    eigenvalues = eigenvalues[order]
    eigenvectors = eigenvectors[:, order]

    positive = np.where(eigenvalues > 0)[0]
    embedding = eigenvectors[:, positive].dot(
        np.diag(np.sqrt(eigenvalues[positive]))
    )
    return embedding, eigenvalues


def _force_reflection(rotation, singular, left, right, reflection):
    """Flip the last axis when the solution's handedness is wrong."""
    has_reflection = np.linalg.det(rotation) < 0
    if reflection == bool(has_reflection):
        return rotation, singular
    right = right.copy()
    singular = singular.copy()
    right[:, -1] *= -1
    singular[-1] *= -1
    return np.dot(right, left.T), singular


def procrustes(
    target: np.ndarray,
    moved: np.ndarray,
    scaling: bool = True,
    reflection="best",
):
    """Align one configuration of points to another.

    Finds the translation, rotation, optional reflection and
    optional uniform scaling of ``moved`` that minimises the sum of
    squared distances to ``target``.  Follows MATLAB's
    ``procrustes``.

    Parameters
    ----------
    target : numpy.ndarray
        Array of shape ``(n_points, n_dimensions)``.
    moved : numpy.ndarray
        Array of shape ``(n_points, n_dimensions)`` with the same
        number of points as ``target`` and no more dimensions.
        Fewer dimensions are zero-padded.
    scaling : bool
        Whether the transformation may scale ``moved``.  The scale
        is held at 1 when False.
    reflection : {'best'} or bool
        ``"best"`` lets the fit decide whether to reflect; True or
        False forces a solution with or without a reflection.

    Returns
    -------
    disparity : float
        Residual sum of squared errors, normalised by the scale of
        ``target``, so it does not depend on the units of either
        configuration.
    transformed : numpy.ndarray
        ``moved`` after the transformation, of the same shape as
        ``target``.
    transform : dict
        The ``rotation``, ``scale`` and ``translation`` taking
        ``moved`` to ``transformed``.

    Raises
    ------
    ValueError
        If the two configurations hold different numbers of points,
        or ``moved`` has more dimensions than ``target``.
    """
    n_points, n_dimensions = target.shape
    n_moved_points, n_moved_dimensions = moved.shape

    if n_points != n_moved_points:
        raise ValueError(
            f"Both configurations must hold the same number of "
            f"points, got {n_points} and {n_moved_points}."
        )
    if n_moved_dimensions > n_dimensions:
        raise ValueError(
            f"moved must not have more dimensions than target, got "
            f"{n_moved_dimensions} and {n_dimensions}."
        )

    target_mean = target.mean(0)
    moved_mean = moved.mean(0)
    centred_target = target - target_mean
    centred_moved = moved - moved_mean

    target_scatter = (centred_target**2.0).sum()
    moved_scatter = (centred_moved**2.0).sum()
    target_norm = np.sqrt(target_scatter)
    moved_norm = np.sqrt(moved_scatter)

    centred_target = centred_target / target_norm
    centred_moved = centred_moved / moved_norm

    if n_moved_dimensions < n_dimensions:
        centred_moved = np.concatenate(
            (
                centred_moved,
                np.zeros(
                    (n_points, n_dimensions - n_moved_dimensions)
                ),
            ),
            axis=1,
        )

    left, singular, right_t = np.linalg.svd(
        np.dot(centred_target.T, centred_moved), full_matrices=False
    )
    right = right_t.T
    rotation = np.dot(right, left.T)

    if reflection != "best":
        rotation, singular = _force_reflection(
            rotation, singular, left, right, bool(reflection)
        )

    trace = singular.sum()

    if scaling:
        scale = trace * target_norm / moved_norm
        disparity = 1 - trace**2
        transformed = (
            target_norm
            * trace
            * np.dot(centred_moved, rotation)
            + target_mean
        )
    else:
        scale = 1
        disparity = (
            1
            + moved_scatter / target_scatter
            - 2 * trace * moved_norm / target_norm
        )
        transformed = (
            moved_norm * np.dot(centred_moved, rotation)
            + target_mean
        )

    if n_moved_dimensions < n_dimensions:
        rotation = rotation[:n_moved_dimensions, :]

    translation = target_mean - scale * np.dot(moved_mean, rotation)
    return (
        disparity,
        transformed,
        {
            "rotation": rotation,
            "scale": scale,
            "translation": translation,
        },
    )
