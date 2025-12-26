#!/bin/bash

# CosyVoice API 客户端脚本
# 用于调用 Docker 部署的 CosyVoice API 服务

# API 服务地址
API_HOST="http://localhost:50000"

# CosyVoice3 模型支持的粤语变声功能

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
    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装，请先安装 curl"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "docker 未安装，请先安装 Docker"
        exit 1
    fi
}

# 检查 API 服务是否运行
check_api_status() {
    if curl -s --connect-timeout 5 $API_HOST/inference_sft --form "tts_text=test" --form "spk_id=中文女" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 预训练音色合成
sft_synthesis() {
    local text="$1"
    local spk_id="${2:-中文女}"
    local output_file="${3:-output_sft.wav}"
    
    print_info "开始预训练音色合成: $text"
    
    if check_api_status; then
        curl -X POST "$API_HOST/inference_sft" \
            -F "tts_text=$text" \
            -F "spk_id=$spk_id" \
            --output "$output_file"
        
        if [ $? -eq 0 ]; then
            print_info "音频已保存到: $output_file"
        else
            print_error "API 调用失败"
        fi
    else
        print_error "API 服务未运行，请先启动服务"
    fi
}

# 零样本语音克隆
zero_shot_synthesis() {
    local text="$1"
    local prompt_text="$2"
    local prompt_wav="$3"
    local output_file="${4:-output_zero_shot.wav}"
    
    print_info "开始零样本语音克隆: $text"
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    if check_api_status; then
        curl -X POST "$API_HOST/inference_zero_shot" \
            -F "tts_text=$text" \
            -F "prompt_text=$prompt_text" \
            -F "prompt_wav=@$prompt_wav" \
            --output "$output_file"
        
        if [ $? -eq 0 ]; then
            print_info "音频已保存到: $output_file"
        else
            print_error "API 调用失败"
        fi
    else
        print_error "API 服务未运行，请先启动服务"
    fi
}

# 跨语种复刻
cross_lingual_synthesis() {
    local text="$1"
    local prompt_wav="$2"
    local output_file="${3:-output_cross_lingual.wav}"
    
    print_info "开始跨语种复刻: $text"
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    if check_api_status; then
        curl -X POST "$API_HOST/inference_cross_lingual" \
            -F "tts_text=$text" \
            -F "prompt_wav=@$prompt_wav" \
            --output "$output_file"
        
        if [ $? -eq 0 ]; then
            print_info "音频已保存到: $output_file"
        else
            print_error "API 调用失败"
        fi
    else
        print_error "API 服务未运行，请先启动服务"
    fi
}

# 指令控制合成
instruct_synthesis() {
    local text="$1"
    local spk_id="${2:-中文女}"
    local instruct_text="$3"
    local output_file="${4:-output_instruct.wav}"
    
    print_info "开始指令控制合成: $text"
    
    if check_api_status; then
        curl -X POST "$API_HOST/inference_instruct" \
            -F "tts_text=$text" \
            -F "spk_id=$spk_id" \
            -F "instruct_text=$instruct_text" \
            --output "$output_file"
        
        if [ $? -eq 0 ]; then
            print_info "音频已保存到: $output_file"
        else
            print_error "API 调用失败"
        fi
    else
        print_error "API 服务未运行，请先启动服务"
    fi
}

# 启动 Docker 服务
start_service() {
    print_info "启动 CosyVoice API 服务..."
    
    # 检查容器是否已存在
    if [ "$(docker ps -q -f name=cosyvoice-api)" ]; then
        print_warning "容器已存在，先停止旧容器"
        docker stop cosyvoice-api
        docker rm cosyvoice-api
    fi
    
    # 启动新容器 - 使用 CosyVoice3 模型
    docker run -d \
        --name cosyvoice-api \
        -p 50000:50000 \
        -m 12g \
        --cpus="4" \
        cosyvoice:v1.0 /bin/bash -c \
        "cd /opt/CosyVoice/CosyVoice/runtime/python/fastapi && \
         python3 server.py --port 50000 --model_dir pretrained_models/Fun-CosyVoice3-0.5B && sleep infinity"
    
    if [ $? -eq 0 ]; then
        print_info "服务启动中，请等待约1分钟完成模型加载..."
        
        # 等待服务启动
        for i in {1..20}; do
            sleep 5
            if check_api_status; then
                print_info "API 服务已启动并运行在 $API_HOST"
                return 0
            fi
            print_info "等待服务启动... ($i/20)"
        done
        
        print_error "服务启动超时，请检查日志"
        docker logs cosyvoice-api
    else
        print_error "启动容器失败"
        return 1
    fi
}

# 停止服务
stop_service() {
    print_info "停止 CosyVoice API 服务..."
    
    if [ "$(docker ps -q -f name=cosyvoice-api)" ]; then
        docker stop cosyvoice-api
        docker rm cosyvoice-api
        print_info "服务已停止"
    else
        print_warning "容器不存在"
    fi
}

# 查看服务日志
show_logs() {
    if [ "$(docker ps -aq -f name=cosyvoice-api)" ]; then
        docker logs cosyvoice-api
    else
        print_error "容器不存在"
    fi
}

# 语音变声示例
voice_conversion_example() {
    local text="$1"
    local source_wav="$2"
    local output_file="${3:-output_vc.wav}"
    
    print_info "开始语音变声: $text"
    
    cross_lingual_synthesis "$text" "$source_wav" "$output_file"
}

# 粤语语音变声
cantonese_synthesis() {
    local text="$1"
    local prompt_wav="$2"
    local output_file="${3:-output_cantonese.wav}"
    
    print_info "开始粤语语音变声: $text"
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    if check_api_status; then
        curl -X POST "$API_HOST/inference_instruct2" \
            -F "tts_text=$text" \
            -F "instruct_text=You are a helpful assistant. 请用广东话表达.<|endofprompt|>" \
            -F "prompt_wav=@$prompt_wav" \
            --output "$output_file"
        
        if [ $? -eq 0 ]; then
            print_info "粤语音频已保存到: $output_file"
        else
            print_error "API 调用失败"
        fi
    else
        print_error "API 服务未运行，请先启动服务"
    fi
}

# 粤语语音转换
cantonese_voice_conversion() {
    local text="$1"
    local prompt_wav="$2"
    local output_file="${3:-output_cantonese_vc.wav}"
    
    print_info "开始粤语语音转换: $text"
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    if check_api_status; then
        curl -X POST "$API_HOST/inference_cross_lingual" \
            -F "tts_text=$text" \
            -F "prompt_wav=@$prompt_wav" \
            --output "$output_file"
        
        if [ $? -eq 0 ]; then
            print_info "粤语转换音频已保存到: $output_file"
        else
            print_error "API 调用失败"
        fi
    else
        print_error "API 服务未运行，请先启动服务"
    fi
}

# 批量处理
batch_synthesis() {
    local input_file="$1"
    local output_dir="${2:-./batch_output}"
    
    if [ ! -f "$input_file" ]; then
        print_error "输入文件不存在: $input_file"
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    print_info "开始批量处理..."
    
    local count=0
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            count=$((count + 1))
            local output_file="$output_dir/batch_$count.wav"
            sft_synthesis "$line" "中文女" "$output_file"
            sleep 2  # 避免请求过于频繁
        fi
    done < "$input_file"
    
    print_info "批量处理完成，共处理 $count 条记录"
}

# 显示帮助信息
show_help() {
    echo "CosyVoice API 客户端脚本"
    echo ""
    echo "用法: $0 [选项] [参数...]"
    echo ""
    echo "选项:"
    echo "  start                    启动 API 服务"
    echo "  stop                     停止 API 服务"
    echo "  logs                     查看服务日志"
    echo "  sft <text> [spk_id] [output_file]  预训练音色合成"
    echo "  zero_shot <text> <prompt_text> <prompt_wav> [output_file]  零样本语音克隆"
    echo "  cross_lingual <text> <prompt_wav> [output_file]  跨语种复刻"
    echo "  instruct <text> [spk_id] <instruct_text> [output_file]  指令控制合成"
    echo "  vc <text> <source_wav> [output_file]  语音变声"
    echo "  cantonese <text> <prompt_wav> [output_file]  粤语语音变声"
    echo "  cantonese_vc <text> <prompt_wav> [output_file]  粤语语音转换"
    echo "  batch <input_file> [output_dir]  批量处理"
    echo "  help                     显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start"
    echo "  $0 sft \"你好，这是测试\" \"中文女\" \"output.wav\""
    echo "  $0 zero_shot \"这是零样本测试\" \"参考文本\" \"./ref.wav\" \"output.wav\""
    echo "  $0 stop"
}

# 主函数
main() {
    check_dependencies
    
    case "$1" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "logs")
            show_logs
            ;;
        "sft")
            if [ $# -lt 2 ]; then
                print_error "缺少必要参数: text"
                show_help
                exit 1
            fi
            sft_synthesis "$2" "$3" "$4"
            ;;
        "zero_shot")
            if [ $# -lt 4 ]; then
                print_error "缺少必要参数: text, prompt_text, prompt_wav"
                show_help
                exit 1
            fi
            zero_shot_synthesis "$2" "$3" "$4" "$5"
            ;;
        "cross_lingual")
            if [ $# -lt 3 ]; then
                print_error "缺少必要参数: text, prompt_wav"
                show_help
                exit 1
            fi
            cross_lingual_synthesis "$2" "$3" "$4"
            ;;
        "instruct")
            if [ $# -lt 3 ]; then
                print_error "缺少必要参数: text, instruct_text"
                show_help
                exit 1
            fi
            instruct_synthesis "$2" "$3" "$4" "$5"
            ;;
        "vc")
            if [ $# -lt 3 ]; then
                print_error "缺少必要参数: text, source_wav"
                show_help
                exit 1
            fi
            voice_conversion_example "$2" "$3" "$4"
            ;;
        "cantonese")
            if [ $# -lt 3 ]; then
                print_error "缺少必要参数: text, prompt_wav"
                show_help
                exit 1
            fi
            cantonese_synthesis "$2" "$3" "$4"
            ;;
        "cantonese_vc")
            if [ $# -lt 3 ]; then
                print_error "缺少必要参数: text, prompt_wav"
                show_help
                exit 1
            fi
            cantonese_voice_conversion "$2" "$3" "$4"
            ;;
        "batch")
            if [ $# -lt 2 ]; then
                print_error "缺少必要参数: input_file"
                show_help
                exit 1
            fi
            batch_synthesis "$2" "$3"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            if [ -z "$1" ]; then
                show_help
            else
                print_error "未知命令: $1"
                show_help
                exit 1
            fi
            ;;
    esac
}

# 执行主函数
main "$@"