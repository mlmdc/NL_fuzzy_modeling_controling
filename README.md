<div align="center">

# Fuzzy Modeling and Control of a Helicrane
## Modélisation floue et commande d'un hélicrane

**EN** — MATLAB experiments in nonlinear system identification, Takagi–Sugeno fuzzy modeling, NARX comparison, and model-based control.

**FR** — Expériences MATLAB d'identification de systèmes non linéaires, de modélisation floue de Takagi–Sugeno, de comparaison NARX et de commande fondée sur un modèle.

<img src="medias/controller/controller_output_steps.png" alt="Controller response during a step simulation" width="850">

[Portfolio / Portfolio](https://github.com/mlmdc)

</div>

## Overview / Présentation

**EN** — This repository studies the input-output dynamics of a simulated helicopter-like process. MATLAB scripts generate excitation signals, identify local models, compare fuzzy and NARX responses, and simulate a fuzzy-model-based controller. This is coursework and experimentation, not a deployable flight-control system.

**FR** — Ce dépôt étudie la dynamique entrée-sortie d'un procédé simulé de type hélicrane. Les scripts MATLAB génèrent des signaux d'excitation, identifient des modèles locaux, comparent les réponses floues et NARX, puis simulent un contrôleur fondé sur un modèle flou. Il s'agit d'un travail expérimental, pas d'un système de commande de vol destiné au déploiement.

The experiments use a fixed sample interval of 0.01 s. Gustafson–Kessel clustering identifies operating regions; weighted least squares estimates local ARX dynamics; Takagi–Sugeno rules combine local models. A NARX network provides an additional nonlinear model for comparison.

Les expériences utilisent un pas d'échantillonnage fixe de 0,01 s. Le clustering de Gustafson–Kessel définit les zones de fonctionnement ; les moindres carrés pondérés estiment les dynamiques ARX locales ; des règles de Takagi–Sugeno combinent les modèles. Un réseau NARX fournit un modèle non linéaire supplémentaire à comparer.

## Requirements / Prérequis

- MATLAB with the toolboxes required by each experiment: Fuzzy Logic, Control System, Signal Processing, and Deep Learning (`narxnet`). Clustering scripts may also require Statistics and Machine Learning Toolbox.
- The supplied `helicrane.p` P-code model, required for process simulations. Its implementation is protected and is not included as source.
- Run scripts from the repository root so MATLAB can find the model, data, and `generate_prbs.m`.

- MATLAB et les boîtes à outils nécessaires à chaque expérience : Fuzzy Logic, Control System, Signal Processing et Deep Learning (`narxnet`). Les scripts de clustering peuvent aussi nécessiter Statistics and Machine Learning Toolbox.
- Le modèle P-code `helicrane.p`, nécessaire aux simulations du procédé. Son implémentation est protégée et n'est pas fournie sous forme de code source.
- Lancer les scripts depuis la racine du dépôt afin que MATLAB trouve le modèle, les données et `generate_prbs.m`.

No MATLAB release or toolbox version has been verified/documented. The repository does not include an automated test suite.

Aucune version de MATLAB ni des boîtes à outils n'a été vérifiée ou documentée. Le dépôt ne contient pas de suite de tests automatisés.

## Experiments / Expériences

| Purpose / Objectif | Script | Inputs / Entrées |
| --- | --- | --- |
| Run a short process simulation / Simuler brièvement le procédé | `helicrane_simulation_example.m` | `helicrane.p` |
| Identify fuzzy and NARX models / Identifier les modèles flou et NARX | `fuzzy_narx_identification.m` | `helicrane.p`, `generate_prbs.m` |
| Explore alternate identification methods / Explorer d'autres méthodes d'identification | `alternate_model_identification.m` | `helicrane.p`, `generate_prbs.m` |
| Cluster saved identification data / Regrouper les données d'identification enregistrées | `gustafson_kessel_analysis.m` | `ident_data.mat`, `helicrane.p` |
| Simulate fuzzy-model control / Simuler la commande floue | `fuzzy_model_control.m` | `fuzzy_data.mat`, `helicrane.p` |
| Explore fuzzy input-output mapping / Explorer la correspondance entrée-sortie floue | `fuzzy_mapping_experiment.m` | `helicrane.p`, `generate_prbs.m` |

For example, run the short process simulation from MATLAB:

```matlab
run('helicrane_simulation_example.m')
```

`fuzzy_model_control.m` expects `fuzzy_data.mat` to contain model variables compatible with that script. The identification scripts do not form a fully automated save-and-run pipeline. Check that saved data matches the model and variable names expected before running the controller.

`fuzzy_model_control.m` attend que `fuzzy_data.mat` contienne des variables de modèle compatibles avec le script. Les scripts d'identification ne constituent pas un pipeline entièrement automatisé d'enregistrement et d'exécution. Vérifier la compatibilité des données enregistrées avant de lancer le contrôleur.

## Repository contents / Contenu du dépôt

- `generate_prbs.m` — PRBS signal generator used by the experiments / générateur de signaux PRBS.
- `ident_data.mat`, `fuzzy_data.mat`, `narxNet.mat` — saved MATLAB datasets and model artifact / jeux de données MATLAB et artefact de modèle enregistrés.
- `helicrane.p` — protected process simulator / simulateur du procédé protégé.
- `medias/` — experiment plots and reference documents / graphiques expérimentaux et documents de référence.

`backup.m` and MATLAB's malformed autosave `mapping_curve.asv` were removed; the experiment scripts, saved data, simulator, and media are retained.

Les fichiers `backup.m` et `mapping_curve.asv`, une autosauvegarde MATLAB invalide, ont été supprimés ; les scripts expérimentaux, données, simulateur et médias sont conservés.

## Results / Résultats

The saved figures show clustering, local-model, step-response, and chirp experiments. They are qualitative illustrations: the repository does not define a common benchmark or report comparable aggregate validation metrics for all models. Results may vary because some experiments use random initialization or noise without a shared random seed.

Les figures enregistrées illustrent le clustering, les modèles locaux ainsi que des expériences en échelons et en chirp. Elles sont qualitatives : le dépôt ne définit pas de benchmark commun et ne fournit pas de métriques de validation agrégées comparables pour tous les modèles. Les résultats peuvent varier car certaines expériences utilisent des initialisations aléatoires ou du bruit sans graine commune.
