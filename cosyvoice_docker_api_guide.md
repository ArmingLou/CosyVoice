# CosyVoice Docker API 部署与调用指南

本指南介绍如何在 Mac Intel CPU 环境下通过 Docker 部署并调用 CosyVoice API。

## 1. 环境准备

### 1.1 系统要求
- macOS (Intel CPU)
- Docker Desktop (已安装并运行)
- 至少 16GB 内存

### 1.2 安装 Docker
```bash
# 下载并安装 Docker Desktop for Mac
# 启动 Docker Desktop 应用
```

## 2. 构建 Docker 镜像

### 2.1 进入项目目录
```bash
cd /path/to/CosyVoice
```

### 2.2 构建镜像
```bash
cd runtime/python
docker build -t cosyvoice:v1.0 .  # 构建基础镜像，支持CosyVoice 1.0/2.0/3.0
```

### 2.3 下载 CosyVoice3 模型
```bash
# 下载 CosyVoice3 模型
python3 -c "from modelscope import snapshot_download; snapshot_download('FunAudioLLM/Fun-CosyVoice3-0.5B-2512', local_dir='pretrained_models/Fun-CosyVoice3-0.5B')"
```

## 3. 启动 API 服务

### 3.1 启动 FastAPI 服务 (推荐用于 Mac)
```bash
# 使用 CPU 运行（适用于 Mac Intel）
docker run -d --name cosyvoice-api \
  -p 50000:50000 \
  -m 12g \
  --cpus="4" \
  cosyvoice:v1.0 /bin/bash -c \
  "cd /opt/CosyVoice/CosyVoice/runtime/python/fastapi && \
   python3 server.py --port 50000 --model_dir pretrained_models/Fun-CosyVoice3-0.5B && sleep infinity"

# 或者使用 CosyVoice2 模型
# docker run -d --name cosyvoice-api \
#  -p 50000:50000 \
#  -m 12g \
#  --cpus="4" \
#  cosyvoice:v1.0 /bin/bash -c \
#  "cd /opt/CosyVoice/CosyVoice/runtime/python/fastapi && \
#   python3 server.py --port 50000 --model_dir pretrained_models/CosyVoice2-0.5B && sleep infinity"

# 或者使用 CosyVoice1 模型
# docker run -d --name cosyvoice-api \
#  -p 50000:50000 \
#  -m 12g \
#  --cpus="4" \
#  cosyvoice:v1.0 /bin/bash -c \
#  "cd /opt/CosyVoice/CosyVoice/runtime/python/fastapi && \
#   python3 server.py --port 50000 --model_dir iic/CosyVoice-300M && sleep infinity"
```

### 3.2 验证服务启动
```bash
# 检查容器状态
docker ps

# 查看服务日志
docker logs cosyvoice-api
```

## 4. API 接口说明

### 4.1 预训练音色合成 (SFT)
- **接口**: `POST /inference_sft`
- **参数**:
  - `spk_id`: 音色ID
  - `tts_text`: 待合成文本

### 4.2 零样本语音克隆
- **接口**: `POST /inference_zero_shot`
- **参数**:
  - `tts_text`: 待合成文本
  - `prompt_text`: 参考文本
  - `prompt_wav`: 参考音频文件

### 4.3 跨语种复刻
- **接口**: `POST /inference_cross_lingual`
- **参数**:
  - `tts_text`: 待合成文本
  - `prompt_wav`: 参考音频文件

### 4.4 指令控制
- **接口**: `POST /inference_instruct`
- **参数**:
  - `tts_text`: 待合成文本
  - `spk_id`: 音色ID
  - `instruct_text`: 指令文本

## 5. API 调用示例

### 5.1 零样本语音克隆示例
```bash
curl -X POST "http://localhost:50000/inference_zero_shot" \
  -F "tts_text=你好，这是零样本语音克隆测试" \
  -F "prompt_text=希望你以后能够做的比我还好呦" \
  -F "prompt_wav=@./asset/zero_shot_prompt.wav"
```

### 5.2 预训练音色合成示例
```bash
curl -X POST "http://localhost:50000/inference_sft" \
  -F "tts_text=这是预训练音色合成测试" \
  -F "spk_id=中文女"
```

### 5.3 跨语种复刻示例
```bash
curl -X POST "http://localhost:50000/inference_cross_lingual" \
  -F "tts_text=This is cross lingual test" \
  -F "prompt_wav=@./asset/cross_lingual_prompt.wav"
```

## 6. 语音变声功能

### 6.1 语音转换 (Voice Conversion)
```bash
curl -X POST "http://localhost:50000/inference_cross_lingual" \
  -F "tts_text=需要转换的文本" \
  -F "prompt_wav=@./source_audio.wav"
```

### 6.2 指令控制变声
```bash
curl -X POST "http://localhost:50000/inference_instruct" \
  -F "tts_text=请用四川话说这句话" \
  -F "spk_id=中文男" \
  -F "instruct_text=You are a helpful assistant. 请用四川话说这句话.<|endofprompt|>"
```

### 6.3 粤语语音变声
```bash
curl -X POST "http://localhost:50000/inference_instruct2" \
  -F "tts_text=好少咯，一般系放嗰啲国庆啊，中秋嗰啲可能会咯。" \
  -F "instruct_text=You are a helpful assistant. 请用广东话表达.<|endofprompt|>" \
  -F "prompt_wav=@./asset/zero_shot_prompt.wav"
```

### 6.4 跨语种语音转换
```bash
curl -X POST "http://localhost:50000/inference_cross_lingual" \
  -F "tts_text=This is a cross-lingual voice conversion test" \
  -F "prompt_wav=@./asset/cantonese_audio.wav"
```

## 7. 停止服务
```bash
# 停止容器
docker stop cosyvoice-api

# 删除容器
docker rm cosyvoice-api
```

## 8. 性能优化建议

### 8.1 Docker 资源限制
- 在 Docker Desktop 中分配至少 8GB 内存
- 限制 CPU 核心数以避免系统卡顿

### 8.2 模型选择
- 使用较小的模型以减少内存占用
- 考虑使用量化模型以提高性能

### 8.3 批处理
- 对于批量处理，建议合并多个请求以提高效率

## 9. 故障排除

### 9.1 服务启动失败
- 检查 Docker 是否运行
- 确认端口 50000 未被占用
- 检查内存是否足够

### 9.2 API 调用超时
- 模型加载可能需要几分钟时间
- 检查系统资源使用情况

### 9.3 音频质量不佳
- 确认参考音频质量
- 检查文本和音频内容匹配度