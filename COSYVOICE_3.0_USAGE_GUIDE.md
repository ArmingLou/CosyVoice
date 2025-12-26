# CosyVoice 3.0 使用指南

## 目录
- [项目概述](#项目概述)
- [环境要求](#环境要求)
- [安装步骤](#安装步骤)
- [模型下载](#模型下载)
- [功能介绍](#功能介绍)
- [交互式脚本使用](#交互式脚本使用)
- [粤语语音变声](#粤语语音变声)
- [常见问题](#常见问题)

## 项目概述

CosyVoice 3.0 是一个先进的文本到语音（TTS）系统，基于大语言模型，支持零样本跨语言语音合成。主要特性包括：

- 支持9种主流语言 + 18+中文方言（包括粤语）
- 零样本语音克隆
- 指令控制语音生成
- 发音修复功能
- 跨语言语音合成
- 高质量语音输出

## 环境要求

### 硬件要求
- **CPU**: Intel/Apple Silicon (推荐16GB+内存)
- **内存**: 最少16GB (推荐32GB+)
- **存储**: 10GB+可用空间（用于模型文件）

### 软件要求
- **操作系统**: macOS (Intel/Apple Silicon)
- **Python**: 3.11
- **Conda**: Anaconda 或 Miniconda
- **依赖**: 根据功能需求自动安装

## 安装步骤

### 1. 环境准备
```bash
# 确保已安装conda
conda --version

# 创建Python 3.11环境
conda create -n cosyvoice python=3.11 -y
conda activate cosyvoice
```

### 2. 安装PyTorch
```bash
# 安装CPU版本（适用于Mac）
conda install pytorch torchvision torchaudio cpuonly -c pytorch -y

# 或使用pip安装
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
```

### 3. 安装其他依赖
```bash
pip install modelscope hyperpyyaml tqdm omegaconf librosa inflect onnx onnxruntime
pip install hydra-core HyperPyYAML networkx matplotlib tensorboard pyworld
pip install soundfile pyarrow pydantic rich uvicorn wetext wget conformer
pip install diffusers fastapi fastapi-cli gradio grpcio grpcio-tools x-transformers
pip install transformers openai-whisper protobuf
```

### 4. 验证安装
```bash
python -c "import torch; print(f'PyTorch version: {torch.__version__}')"
python -c "import modelscope; print(f'ModelScope version: {modelscope.__version__}')"
```

## 模型下载

### 1. 下载CosyVoice 3.0模型
```bash
# 使用Python脚本下载
python -c "from modelscope import snapshot_download; snapshot_download('FunAudioLLM/Fun-CosyVoice3-0.5B-2512', local_dir='pretrained_models/Fun-CosyVoice3-0.5B')"
```

### 2. 模型组件说明
下载的模型包含以下组件：
- `campplus.onnx` (27MB) - 说话人验证模型
- `flow.pt` (1.24GB) - 流式模型参数
- `flow.decoder.estimator.fp32.onnx` (1.24GB) - 流式解码器
- `llm.pt` (1.89GB) - 大语言模型
- `llm.rl.pt` (1.89GB) - 强化学习优化模型
- `hift.pt` (79.3MB) - 音高和韵律模型
- 配置文件和资源文件

**注意**: 模型文件较大，下载可能需要较长时间（1-2小时），请耐心等待。

## 功能介绍

### 1. 预训练音色合成 (SFT)
使用预定义的音色进行文本转语音。

### 2. 零样本语音克隆 (Zero-shot)
使用参考音频和文本，克隆特定说话人的声音特征。

### 3. 跨语言复刻 (Cross-lingual)
使用一种语言的参考音频，合成另一种语言的语音。

### 4. 指令控制合成 (Instruct)
通过指令控制语音的情感、语速、音量等属性。

### 5. 粤语语音变声 (Cantonese)
使用指令控制生成粤语语音。

### 6. 语音转换 (Voice Conversion)
将源音频转换为目标说话人的声音特征。

## 交互式脚本使用

### 1. 环境激活
在运行脚本前，请确保激活conda环境：
```bash
source $(conda info --base)/etc/profile.d/conda.sh && conda activate cosyvoice
```

### 2. 启动交互式脚本
```bash
./cosyvoice_interactive_cli.sh
```

### 3. 新增功能说明
在Mac环境下，脚本现在支持图形界面弹窗选择文件和目录：
- **目录选择**：在需要选择输出目录时，会弹出系统目录选择对话框
- **文件选择**：在需要选择音频文件时，会弹出系统文件选择对话框
- **自动生成输出文件名**：根据源文件名和功能类型自动生成输出文件名
- **默认目录控制**：弹窗会默认打开到相关目录（如选择音频文件时默认打开asset目录）
- **交互提示**：在弹出选择对话框前，会显示提示信息告知用户需要在弹出的窗口中进行选择

### 4. 菜单功能说明
```
===================================
    CosyVoice 交互式命令行工具
===================================
1) 预训练音色合成 (SFT)
2) 零样本语音克隆 (Zero-shot)
3) 跨语种复刻 (Cross-lingual)
4) 指令控制合成 (Instruct)
5) 粤语语音变声 (Cantonese)
6) 语音转换 (Voice Conversion)
7) 下载模型
8) 退出
===================================
```

### 5. 各功能使用方法

#### 预训练音色合成
- 选择功能1
- 输入要合成的文本
- 选择音色ID（如"中文女"）
- 指定输出文件路径

#### 零样本语音克隆
- 选择功能2
- 输入目标文本
- 输入参考文本（参考音频中的内容）
- 选择参考音频文件
- 指定输出文件路径

#### 粤语语音变声
- 选择功能5
- 输入粤语文本
- 选择参考音频文件
- 指定输出文件路径

## 粤语语音变声

### 使用方法
1. 准备参考音频文件（包含目标说话人声音特征）
2. 输入粤语文本
3. 选择粤语语音变声功能
4. 系统将生成带有粤语发音的语音

### 示例
```bash
# 使用Python API
from cosyvoice.cli.cosyvoice import CosyVoice
import torchaudio

cosyvoice = CosyVoice('pretrained_models/Fun-CosyVoice3-0.5B')
for i, j in enumerate(cosyvoice.inference_instruct2('好少咯，一般系放嗰啲国庆啊，中秋嗰啲可能会咯。', 'You are a helpful assistant. 请用广东话表达.<|endofprompt|>', './asset/zero_shot_prompt.wav')):
    torchaudio.save('output_cantonese.wav', j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
    break
```

## 常见问题

### Q1: 环境配置和依赖安装问题？
A: 如果遇到依赖冲突问题：
- 使用conda和pip结合安装依赖
- 确保在正确的环境中安装包
- 对于编译依赖（如pyworld），可能需要额外的系统工具

### Q2: 模型下载很慢怎么办？
A: 模型文件较大，下载需要时间。可以：
- 检查网络连接
- 确保有足够的存储空间
- 耐心等待下载完成

### Q2: 内存不足怎么办？
A: CosyVoice 3.0对内存要求较高，建议：
- 关闭其他占用内存的应用
- 确保至少16GB可用内存
- 在Mac上，系统会使用虚拟内存，但速度会变慢

### Q3: 音频文件格式要求？
A: 支持常见音频格式：
- WAV
- MP3
- FLAC
- 采样率建议16kHz或22.05kHz

### Q4: 如何提高语音质量？
A: 
- 使用高质量的参考音频（清晰、无噪音）
- 确保参考音频与目标文本内容相关性高
- 调整参数以获得最佳效果

### Q5: 粤语语音变声效果不理想？
A: 
- 确保文本使用正确的粤语表达
- 参考音频质量要高
- 可以尝试不同的参考音频

## 性能优化

### Mac Intel CPU优化
- 使用CPU优化的PyTorch版本
- 调整批处理大小以适应内存限制
- 关闭不必要的后台程序

### 内存管理
- 系统会按需加载模型组件
- 不同功能使用不同的模型子集
- 合理安排任务顺序以减少内存压力

## 技术支持

如遇到问题，请检查：
1. 环境配置是否正确
2. 模型文件是否完整下载
3. 参考音频格式是否支持
4. 网络连接是否稳定

如需进一步帮助，可参考官方文档或寻求技术支持。