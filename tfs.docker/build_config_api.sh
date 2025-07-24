TF_SERVING_VERSION=${TF_SERVING_VERSION:-r2.18}
BASE_DIR=$(pwd)

# Clean up previous runs
rm -rf proto_source tmp src dist build *.egg-info

# Create directories
mkdir -p proto_source
mkdir -p tmp
mkdir -p src
mkdir -p src/tensorflow_serving
mkdir -p src/tensorflow_serving/config

# Create __init__.py for tensorflow_serving package
echo '' > src/tensorflow_serving/__init__.py

# Clone TensorFlow Serving repository
git clone --depth=1 --recurse-submodules --branch=${TF_SERVING_VERSION} https://github.com/tensorflow/serving.git proto_source/serving

# Copy relevant proto files to tmp
cp -r proto_source/serving/tensorflow_serving $BASE_DIR/tmp

python3 -m grpc_tools.protoc \
       --proto_path=./tmp \
       --python_out=./src \
       ./tmp/tensorflow_serving/config/*.proto

echo '__version__ = "0.0.1"' > src/tensorflow_serving/config/__init__.py
# Clean up temporary directories
rm -rf tmp proto_source

# Build the wheel file
python3 setup.py sdist bdist_wheel

ls -lh dist
