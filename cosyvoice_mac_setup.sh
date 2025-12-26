#!/bin/bash

# CosyVoice Mac环境设置脚本
# 用于解决依赖安装问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    if ! command -v conda &> /dev/null; then
        print_error "conda 未安装，请先安装 Anaconda 或 Miniconda"
        exit 1
    fi
}

# 创建适配Mac的conda环境
create_conda_env() {
    print_info "创建 cosyvoice conda 环境 (适配Mac环境)..."
    
    # 创建Python 3.11环境
    conda create -n cosyvoice python=3.11 -y
    
    if [ $? -ne 0 ]; then
        print_error "创建 conda 环境失败"
        exit 1
    fi
    
    # 激活环境
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate cosyvoice
    
    print_info "安装适配Mac的PyTorch..."
    # 为Mac安装CPU版本的PyTorch
    conda install pytorch torchvision torchaudio cpuonly -c pytorch -y
    
    print_info "安装其他依赖..."
    # 安装requirements.txt中除torch外的其他依赖
    pip install modelscope hyperpyyaml tqdm omegaconf librosa inflect onnx onnxruntime
    pip install hydra-core HyperPyYAML networkx matplotlib tensorboard pyworld
    pip install soundfile pyarrow pydantic rich uvicorn wetext wget
    pip install conformer deepspeed diffusers fastapi fastapi-cli gradio grpcio grpcio-tools
    pip install x-transformers transformers openai-whisper protobuf
    
    print_info "依赖安装完成"
}

# 检查并修复torch版本问题
fix_torch_issue() {
    print_info "检查PyTorch安装情况..."
    
    # 激活环境
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate cosyvoice
    
    # 检查torch版本
    if python -c "import torch; print(torch.__version__)" &> /dev/null; then
        print_info "PyTorch 已成功安装: $(python -c "import torch; print(torch.__version__)" 2>/dev/null)"
    else
        print_warning "PyTorch 安装失败，尝试安装兼容版本..."
        conda install pytorch torchvision torchaudio cpuonly -c pytorch -y
    fi
}

# 下载必需的模型
download_models() {
    print_info "下载必需的模型文件..."
    
    # 创建模型目录
    mkdir -p pretrained_models
    
    # 检查是否有已下载的模型
    if [ ! -d "pretrained_models/Fun-CosyVoice3-0.5B" ]; then
        print_info "正在下载 CosyVoice3-0.5B 模型..."
        python3 -c "from modelscope import snapshot_download; snapshot_download('FunAudioLLM/Fun-CosyVoice3-0.5B-2512', local_dir='pretrained_models/Fun-CosyVoice3-0.5B')"
    else
        print_info "CosyVoice3-0.5B 模型已存在"
    fi
}

# 验证安装
verify_installation() {
    print_info "验证安装..."
    
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate cosyvoice
    
    # 测试基本导入
    if python -c "import torch; import transformers; import modelscope" &> /dev/null; then
        print_info "依赖库导入成功"
    else
        print_error "依赖库导入失败"
        return 1
    fi
    
    # 测试CosyVoice导入
    if python -c "import sys; sys.path.append('.'); from cosyvoice.cli.cosyvoice import CosyVoice" &> /dev/null; then
        print_info "CosyVoice 模块导入成功"
    else
        print_warning "CosyVoice 模块导入失败，但可以继续"
    fi
}

# 主函数
main() {
    print_info "开始设置 CosyVoice Mac 环境"
    
    check_dependencies
    create_conda_env
    fix_torch_issue
    download_models
    verify_installation
    
    print_info "环境设置完成！"
    print_info "请运行以下命令激活环境："
    echo "source $(conda info --base)/etc/profile.d/conda.sh && conda activate cosyvoice"
}

main "$@"