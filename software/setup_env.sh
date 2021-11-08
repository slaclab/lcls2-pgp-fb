# Setup environment
source /cds/sw/ds/ana/conda2/manage/bin/psconda.sh
conda activate ps-4.5.5

# Python Package directories
#export AXIPCIE_DIR=${CONDA_PREFIX}/lib/python3.7/site-packages/cameralink_gateway
export SURF_DIR=${CONDA_PREFIX}/lib/python3.7/site-packages/cameralink_gateway

# Setup python path
export PYTHONPATH=${PWD}/python:${SURF_DIR}:${PYTHONPATH}
