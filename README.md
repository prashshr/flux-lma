# Template for deploying lens-lma backed by Flux

Highly opinionated template for deploying LMA stack backed by [Flux](https://toolkit.fluxcd.io/) and [SOPS](https://toolkit.fluxcd.io/guides/mozilla-sops/).

## Overview

- [Introduction](https://github.com/mgueye01/lens-lma-template#introduction)
- [Prerequisites](https://github.com/mgueye01/lens-lma-template#memo-prerequisites)
- [Repository structure](https://github.com/mgueye01/lens-lma-template#open_file_folder-repository-structure)
- [Lets go!](https://github.com/mgueye01/lens-lma-template#rocket-lets-go)
- [Configuration](https://github.com/mgueye01/lens-lma-template#page_facing_up-configuration)
- [GitOps with flux](https://github.com/mgueye01/lens-lma-template#small_blue_diamond-gitops-with-flux)

## Introduction

The following components will be installed in your cluster by default. They are only included to get a minimum viable LMA stack up and running. You are free to add / remove components to your liking but anything outside the scope of the below components are not supported by this template.

Feel free to read up on any of these technologies before you get started to be more familiar with them.

- [botkube](https://www.botkube.io/) - Smessaging bot for monitoring and debugging Kubernetes clusters
- [goldilocks](https://goldilocks.docs.fairwinds.com/) - utility that can help you identify a starting point for resource requests and limits.
- [flux](https://toolkit.fluxcd.io/) - GitOps tool for deploying manifests from the `cluster` directory
- [grafana](https://grafana.com/) - Operational dashboards
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) - Service that listens to the Kubernetes API server and generates metrics about the state of the objects
- [prometheus-operator](https://github.com/prometheus-operator/prometheus-operator) - Monitoring stack for Kubernetes clusters.
- [pushgateway](https://github.com/prometheus/pushgateway) - Allows ephemeral and batch jobs to expose their metrics to Prometheus
- [thanos](https://thanos.io/) - Highly available Prometheus setup with long term storage capabilities.
- [node exporter](https://github.com/prometheus/node_exporter) - Prometheus exporter for hardware and OS metrics
- [loki](https://github.com/grafana/loki) - Like Prometheus, but for logs
- [alertmanager](https://github.com/prometheus/alertmanager) - handles alerts sent by client applications

## :memo:&nbsp; Prerequisites

### :wrench:&nbsp; Tools

:round_pushpin: You should install the below CLI tools on your workstation. Make sure you pull in the latest versions.

#### Required

| Tool                                               | Purpose                                                                                                                                 |
|----------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| [direnv](https://github.com/direnv/direnv)         | Exports env vars based on present working directory                                                                                     |
| [flux](https://toolkit.fluxcd.io/)                 | Operator that manages your k8s cluster based on your Git repository                                                                     |
| [age](https://github.com/FiloSottile/age)          | A simple, modern and secure encryption tool (and Go library) with small explicit keys, no config options, and UNIX-style composability. |
| [go-task](https://github.com/go-task/task)         | A task runner / simpler Make alternative written in Go                                                                                  |
| [jq](https://stedolan.github.io/jq/)               | Used to verify settings in the configure script                                                                                         |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Allows you to run commands against Kubernetes clusters                                                                                  |
| [sops](https://github.com/mozilla/sops)            | Encrypts k8s secrets with Age                                                                                                           |

#### Optional

| Tool                                                   | Purpose                                                  |
|--------------------------------------------------------|----------------------------------------------------------|
| [helm](https://helm.sh/)                               | Manage Kubernetes applications                           |
| [kustomize](https://kustomize.io/)                     | Template-free way to customize application configuration |
| [pre-commit](https://github.com/pre-commit/pre-commit) | Runs checks pre `git commit`                             |
| [prettier](https://github.com/prettier/prettier)       | Prettier is an opinionated code formatter.               |

### :warning:&nbsp; pre-commit

It is advisable to install [pre-commit](https://pre-commit.com/) and the pre-commit hooks that come with this repository.
[sops-pre-commit](https://github.com/k8s-at-home/sops-pre-commit) will check to make sure you are not by accident committing your secrets un-encrypted.

After pre-commit is installed on your machine run:

```sh
pre-commit install-hooks
```

## :open_file_folder:&nbsp; Repository structure

The Git repository contains the following directories under `cluster` and are ordered below by how Flux will apply them.

- **base** directory is the entrypoint to Flux
- **crds** directory contains custom resource definitions (CRDs) that need to exist globally in your cluster before anything else exists
- **core** directory (depends on **crds**) are important infrastructure applications (grouped by namespace) that should never be pruned by Flux
- **apps** directory (depends on **core**) is where your common applications (grouped by namespace) could be placed, Flux will prune resources here if they are not tracked by Git anymore

```
cluster
├── apps
│   ├── flux-system
│   ├── kube-system
│   └── monitoring
|   └── tools
├── base
│   └── flux-system
├── core
│   ├── namespaces
└── crds
    └── kube-prometheus-stack
```

## :rocket:&nbsp; Lets go!

Very first step will be to create a new repository by clicking the **Use this template** button on this page.

Clone the repo to you local workstation and `cd` into it.

:round_pushpin: **All of the below commands** are run on your **local** workstation, **not** on any of your cluster nodes.

### :closed_lock_with_key:&nbsp; Setting up Age

:round_pushpin: Here we will create a Age Private and Public key. Using SOPS with Age allows us to encrypt and decrypt secrets.

1. Create a Age Private / Public Key

```sh
age-keygen -o age.agekey
```

2. Set up the directory for the Age key and move the Age file to it

```sh
mkdir -p ~/.config/sops/age
mv age.agekey ~/.config/sops/age/keys.txt
```

3. Export the `SOPS_AGE_KEY_FILE` variable in your `bashrc`, `zshrc` or `config.fish` and source it, e.g.

```sh
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
source ~/.bashrc
```

4. Fill out the Age public key in the `.config.env` under `BOOTSTRAP_AGE_PUBLIC_KEY`, **note** the public key should start with `age`...


### :page_facing_up:&nbsp; Configuration

:round_pushpin: The `.config.env` file contains necessary configuration files that are needed by Flux.

1. Copy the `.config.sample.env` to `.config.env` and start filling out all the environment variables. **All are required** and read the comments they will explain further what is required.

2. Once that is done, verify the configuration is correct by running `./configure.sh --verify`

3. If you do not encounter any errors run `./configure.sh` to start having the script wire up the templated files and place them where they need to be.

### :small_blue_diamond:&nbsp; GitOps with Flux

:round_pushpin: Here we will be installing [flux](https://toolkit.fluxcd.io/) after some quick bootstrap steps.

1. Verify Flux can be installed

```sh
flux check --pre
# ► checking prerequisites
# ✔ kubectl 1.21.5 >=1.18.0-0
# ✔ Kubernetes 1.20.11-mirantis-1 >=1.19.0-0
# ✔ prerequisites checks passed
```

2. Pre-create the `flux-system` namespace

```sh
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
```

3. Add the Age key in-order for Flux to decrypt SOPS secrets

```sh
cat ~/.config/sops/age/keys.txt |
   kubectl -n flux-system create secret generic sops-age \
    --from-file=age.agekey=/dev/stdin
```

:round_pushpin: Variables defined in `./cluster/base/cluster-secrets.sops.yaml` and `./cluster/base/cluster-settings.sops.yaml` will be usable anywhere in your YAML manifests under `./cluster`

4. **Verify** all the above files are **encrypted** with SOPS

5. If you verified all the secrets are encrypted, you can delete the `tmpl` directory now

6.  Push you changes to git

```sh
git add -A
git commit -m "initial commit"
git push
```

7. Install Flux

:round_pushpin: Due to race conditions with the Flux CRDs you will have to run the below command twice. There should be no errors on this second run.

```sh
kubectl apply --kustomize=./cluster/base/flux-system
# namespace/flux-system configured
# customresourcedefinition.apiextensions.k8s.io/alerts.notification.toolkit.fluxcd.io created
# ...
# unable to recognize "./cluster/base/flux-system": no matches for kind "Kustomization" in version "kustomize.toolkit.fluxcd.io/v1beta1"
# unable to recognize "./cluster/base/flux-system": no matches for kind "GitRepository" in version "source.toolkit.fluxcd.io/v1beta1"
# unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
# unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
# unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
# unable to recognize "./cluster/base/flux-system": no matches for kind "HelmRepository" in version "source.toolkit.fluxcd.io/v1beta1"
```

8. Verify Flux components are running in the cluster

```sh
kubectl get pods -n flux-system
# NAME                                       READY   STATUS    RESTARTS   AGE
# helm-controller-5bbd94c75-89sb4            1/1     Running   0          1h
# kustomize-controller-7b67b6b77d-nqc67      1/1     Running   0          1h
# notification-controller-7c46575844-k4bvr   1/1     Running   0          1h
# source-controller-7d6875bcb4-zqw9f         1/1     Running   0          1h
```

At this point, the reconciliation should start populating the stack. The Git repository is driving the state of your stack.
