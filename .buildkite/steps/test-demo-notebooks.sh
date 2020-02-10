#!/bin/bash

set -xeo pipefail

stellargraph_dir="$PWD"

SPLIT="${BUILDKITE_PARALLEL_JOB_COUNT:-1}"
INDEX="${BUILDKITE_PARALLEL_JOB:-0}"

echo "--- :books: collecting notebooks"
# Create array with all notebooks in demo directories.
cd "${stellargraph_dir}"
NOTEBOOKS=()
while IFS= read -r -d $'\0'; do
  NOTEBOOKS+=("$REPLY")
done < <(find "${stellargraph_dir}/demos" -name "*.ipynb" -print0)

NUM_NOTEBOOKS_TOTAL=${#NOTEBOOKS[@]}

if [ "$NUM_NOTEBOOKS_TOTAL" -ne "$SPLIT" ]; then
  echo "Buildkite step parallelism is set to $SPLIT but found $NUM_NOTEBOOKS_TOTAL notebooks. Please update parallelism to match the number of notebooks!"
  exit 1
fi

echo "--- :python: installing papermill"
# Pulling in https://github.com/nteract/papermill/pull/459 for --execution-timeout, which hasn't been released yet
pip install --user https://github.com/nteract/papermill/archive/master.tar.gz

echo "--- installing dependencies"
pip install -q --no-cache-dir '.[demos]'

echo "--- listing dependency versions"
pip freeze

f=${NOTEBOOKS[$INDEX]}

echo "+++ :python: running $f"
case $(basename "$f") in
  'attacks_clustering_analysis.ipynb' | 'hateful-twitters-interpretability.ipynb' | 'hateful-twitters.ipynb' | 'stellargraph-attri2vec-DBLP.ipynb' | \
    'node-link-importance-demo-gat.ipynb' | 'node-link-importance-demo-gcn.ipynb' | 'node-link-importance-demo-gcn-sparse.ipynb' | 'rgcn-aifb-node-classification-example.ipynb' | \
    'stellargraph-metapath2vec.ipynb' | \
    'ensemble-node-classification-example.ipynb' | 'cora-gcn-links-example.ipynb')
    # FIXME: these notebooks do not yet work on CI (#818 - datasets can't be downloaded)
    # FIXME: these notebooks do not yet work on CI (#819 - out-of-memory)
    # FIXME: these notebooks do not yet work on CI (#833 - too slow)
    # FIXME: these notebooks do not yet work on CI (#816 - missing dataset download)
    exit 2 # this will be a soft-fail for buildkite
    ;;
  *) # fine, run this one
    cd "$(dirname "$f")"
    # run the notebook, saving it back to where it was, printing everything
    exitCode=0
    python3 -m papermill --execution-timeout=2400 --log-output "$f" "$f" || exitCode=$?

    # and also upload the notebook with outputs, for someone to download and look at
    buildkite-agent artifact upload "$(basename "$f")"
    exit $exitCode
    ;;
esac