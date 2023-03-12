INSTALL_ENV_DIR="$(pwd)/installer_files/env"
export PATH="$INSTALL_ENV_DIR/bin:$PATH"
CONDA_BASEPATH=$(conda info --base)
source "$CONDA_BASEPATH/etc/profile.d/conda.sh" # otherwise conda complains about 'shell not initialized' (needed when running in a script)

conda activate
cd text-generation-webui
python download-model.py
