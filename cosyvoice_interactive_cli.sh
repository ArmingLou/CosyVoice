#!/bin/bash

# CosyVoice 交互式命令行工具
# 用于在conda环境中调用CosyVoice API

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

# 激活conda环境
activate_conda_env() {
    # 检查是否存在cosyvoice环境
    if conda env list | grep -q "^cosyvoice "; then
        print_info "激活 cosyvoice 环境"
        source $(conda info --base)/etc/profile.d/conda.sh
        conda activate cosyvoice
    else
        print_warning "未找到 cosyvoice 环境，正在创建..."
        create_conda_env
    fi
}

# 创建conda环境
create_conda_env() {
    print_info "创建 cosyvoice conda 环境..."
    conda create -n cosyvoice python=3.11 -y
    
    if [ $? -ne 0 ]; then
        print_error "创建 conda 环境失败"
        exit 1
    fi
    
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate cosyvoice
    
    print_info "安装 PyTorch (适配Mac CPU版本)..." 
    conda install pytorch torchvision torchaudio cpuonly -c pytorch -y
    
    print_info "安装其他依赖..."
    pip install modelscope hyperpyyaml tqdm omegaconf librosa inflect onnxruntime
    
    print_info "环境创建完成"
}

# 将HFS路径转换为Unix路径
convert_hfs_to_unix() {
    local hfs_path="$1"
    if [[ -n "$hfs_path" ]]; then
        # 清理HFS路径，移除开头的"alias "前缀
        local clean_path="${hfs_path#alias }"
        
        # 使用AppleScript将HFS路径转换为Unix路径
        local unix_path=$(osascript -e "POSIX path of \"$clean_path\"" 2>/dev/null)
        if [[ $? -eq 0 && -n "$unix_path" ]]; then
            echo "$unix_path"
            return 0
        fi
    fi
    # 如果转换失败，返回原始路径
    echo "$hfs_path"
}

# 交互式选择目录函数
select_directory() {
    local prompt="$1"
    local default_path="$2"
    local initial_dir="$3"
    
    # 检查是否在macOS上运行
    if command -v osascript &> /dev/null; then
        echo "正在打开目录选择对话框，请在弹出的窗口中选择目录。" >&2
        echo "取消选择，则使用默认目录路径: $default_path" >&2
        # 使用AppleScript显示目录选择对话框
        local script="choose folder with prompt \"$prompt\""
        # 优先使用初始目录参数，如果未提供则使用默认路径的目录部分
        if [[ -n "$initial_dir" && -d "$initial_dir" ]]; then
            script+=" default location POSIX file \"$initial_dir\""
        elif [[ -n "$default_path" && -d "$default_path" ]]; then
            script+=" default location POSIX file \"$default_path\""
        fi
        local result=$(osascript -e "$script" 2>/dev/null)
        if [[ $? -eq 0 && -n "$result" ]]; then
            # 将AppleScript的HFS路径转换为Unix路径
            local unix_path=$(convert_hfs_to_unix "$result")
            if [[ -d "$unix_path" ]]; then
                echo "已选择目录: $unix_path" >&2
            else
                echo "已选择文件: $unix_path" >&2
            fi
            echo "$unix_path"
        else
            if [[ -d "$default_path" ]]; then
                echo "已使用默认目录: $default_path" >&2
            else
                echo "已使用默认文件: $default_path" >&2
            fi
            echo "$default_path"  # 如果用户取消选择，返回默认路径
        fi
    else
        # 如果没有图形界面，提示用户手动输入路径
        echo -n "$prompt"
        if [ -n "$default_path" ]; then
            echo -n " (默认: $default_path)"
        fi
        echo -n ": "
        read -r input
        if [ -z "$input" ] && [ -n "$default_path" ]; then
            echo "$default_path"
        else
            echo "$input"
        fi
    fi
}

# 交互式选择文件函数
select_file() {
    local prompt="$1"
    local default_path="$2"
    local initial_dir="$3"
    
    # 检查是否在macOS上运行
    if command -v osascript &> /dev/null; then
        echo "正在打开文件选择对话框，请在弹出的窗口中选择文件。" >&2
        echo "取消选择，则使用默认文件路径: $default_path" >&2
        # 使用AppleScript显示文件选择对话框
        local script="choose file with prompt \"$prompt\""
        # 优先使用初始目录参数，如果未提供则使用默认路径的目录部分
        if [[ -n "$initial_dir" && -d "$initial_dir" ]]; then
            script+=" default location POSIX file \"$initial_dir\""
        elif [[ -n "$default_path" ]]; then
            # 获取默认路径的目录部分
            local default_dir=$(dirname "$default_path")
            if [[ -d "$default_dir" ]]; then
                script+=" default location POSIX file \"$default_dir\""
            fi
        fi
        local result=$(osascript -e "$script" 2>/dev/null)
        if [[ $? -eq 0 && -n "$result" ]]; then
            # 将AppleScript的HFS路径转换为Unix路径
            local unix_path=$(convert_hfs_to_unix "$result")
            if [[ -d "$unix_path" ]]; then
                echo "已选择目录: $unix_path" >&2
            else
                echo "已选择文件: $unix_path" >&2
            fi
            echo "$unix_path"
        else
            if [[ -d "$default_path" ]]; then
                echo "已使用默认目录: $default_path" >&2
            else
                echo "已使用默认文件: $default_path" >&2
            fi
            echo "$default_path"  # 如果用户取消选择，返回默认路径
        fi
    else
        # 如果没有图形界面，提示用户手动输入路径
        echo -n "$prompt"
        if [ -n "$default_path" ]; then
            echo -n " (默认: $default_path)"
        fi
        echo -n ": "
        read -r input
        if [ -z "$input" ] && [ -n "$default_path" ]; then
            echo "$default_path"
        else
            echo "$input"
        fi
    fi
}

# 根据源文件名生成输出文件路径
generate_output_path() {
    local source_file="$1"
    local output_dir="$2"
    local suffix="$3-cosyvoice"
    
    # 确保输出目录存在
    mkdir -p "$output_dir"
    
    # 如果源文件是特殊标记（如<sft_synthesis>），则使用时间戳生成文件名
    if [[ "$source_file" == "<"*">" ]]; then
        echo "$output_dir/${suffix}_output_$(date +%s).wav"
    else
        # 获取源文件名（不含路径）
        local filename=$(basename "$source_file")
        # 获取源文件扩展名
        local extension="${filename##*.}"
        # 获取源文件名（不含扩展名）
        local name="${filename%.*}"
        
        # 生成输出路径
        echo "$output_dir/${name}_${suffix}.wav"
    fi
}

# 交互式输入文本
input_text() {
    local prompt="$1"
    local default="$2"
    
    # 输出提示信息到控制台，与select_file和select_directory保持一致
    echo "正在等待文本输入: $prompt" >&2
    if [ -n "$default" ]; then
        echo "默认值: $default" >&2
    fi
    
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        echo "$default"
    else
        echo "$input"
    fi
}

# 选择模型版本
select_model() {
    local default_model="2"
    echo "选择模型版本:" >&2
    echo "1) CosyVoice2-0.5B" >&2
    echo "2) CosyVoice3-0.5B (默认)" >&2
    echo "3) CosyVoice3-1.5B" >&2
    echo -n "请选择 (1-3，默认为 $default_model): " >&2
    read -r model_choice 
    
    # 如果用户没有输入，则使用默认值
    if [ -z "$model_choice" ]; then
        model_choice=$default_model
    fi
    
    case $model_choice in
        1)
            echo "选择模型 CosyVoice2-0.5B" >&2
            echo "pretrained_models/CosyVoice2-0.5B"
            ;;
        2)
            echo "选择模型 CosyVoice3-0.5B" >&2 
            echo "pretrained_models/Fun-CosyVoice3-0.5B"
            ;;
        3)
            echo "选择模型 CosyVoice3-1.5B" >&2
            echo "pretrained_models/Fun-CosyVoice3-1.5B"
            ;;
        *)
            print_error "无效选择，使用默认模型版本 CosyVoice3-0.5B" >&2
            echo "pretrained_models/Fun-CosyVoice3-0.5B"
            ;;
    esac
}

# 预训练音色>文转语音
sft_synthesis() {
    local text=$(input_text "输入要合成的文本" "你好，我是测试ttl文本")
    local spk_id=$(input_text "输入音色ID" "中文女")
    local output_dir=$(select_directory "选择输出目录" "/Users/arming/Downloads" "/Users/arming/Downloads")
    local output_file=$(generate_output_path "<sft_synthesis>" "$output_dir" "sft")
    
    print_info "开始  预训练音色>文转语音: $text"
    
    local model_dir=$(select_model)
    python cosyvoice_api.py sft_synthesis --text "$text" --spk_id "$spk_id" --output_file "$output_file" --model_dir "$model_dir"
}

# 自动识别语种>文转语音
zero_shot_synthesis() {
    local text=$(input_text "输入要合成的文本" "我是测试ttl文本")
    local prompt_text=$(input_text "输入音色参考音频的转录文本" "希望你以后能够做的比我还好呦")
    local prompt_wav=$(select_file "选择音色参考音频文件" "./asset/zero_shot_prompt.wav" "/Users/arming/Downloads")
    local output_dir=$(select_directory "选择输出目录" "/Users/arming/Downloads" "/Users/arming/Downloads")
    local output_file=$(generate_output_path "<sft_synthesis>" "$output_dir" "zero_shot")
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "音色参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    print_info "开始  自动识别语种>文转语音: $text"
    
    local model_dir=$(select_model)
    python cosyvoice_api.py zero_shot_synthesis --text "$text" --prompt_text "$prompt_text" --prompt_wav "$prompt_wav" --output_file "$output_file" --model_dir "$model_dir"
}

# 跨语种>文转语音
cross_lingual_synthesis() {
    local text=$(input_text "输入要合成的文本" "This is cross lingual test")
    local prompt_wav=$(select_file "选择音色参考音频文件" "/Users/arming/Documents/ai/seedvc-train/模仿目标声音/yue-wise-woman/audio_9347.mp3" "/Users/arming/Downloads")
    local output_dir=$(select_directory "选择输出目录" "/Users/arming/Downloads" "/Users/arming/Downloads")
    local output_file=$(generate_output_path "<sft_synthesis>" "$output_dir" "cross_lingual")
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "音色参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    print_info "开始  跨语种>文转语音: $text"
    
    local model_dir=$(select_model)
    python cosyvoice_api.py cross_lingual_synthesis --text "$text" --prompt_wav "$prompt_wav" --output_file "$output_file" --model_dir "$model_dir"
}

# 指令控制>文转语音
instruct_synthesis() {
    local text=$(input_text "输入要合成的文本" "在面对挑战时，他展现了非凡的勇气与智慧。")
    local spk_id=$(input_text "输入音色ID" "中文男")
    local instruct_text=$(input_text "输入指令文本" "Theo 'Crimson', is a fiery, passionate rebel leader. Fights with fervor for justice, but struggles with impulsiveness.")
    local output_dir=$(select_directory "选择输出目录" "/Users/arming/Downloads" "/Users/arming/Downloads")
    local output_file=$(generate_output_path "<instruct_synthesis>" "$output_dir" "instruct")
    
    print_info "开始  指令控制>文转语音: $text"
    
    local model_dir=$(select_model)
    python cosyvoice_api.py instruct_synthesis --text "$text" --spk_id "$spk_id" --instruct_text "$instruct_text" --output_file "$output_file" --model_dir "$model_dir"
}

# 粤语专用>文转语音
cantonese_synthesis() {
    local text=$(input_text "输入要合成的粤语文本" "好少咯，一般系放嗰啲国庆啊，中秋嗰啲可能会咯。")
    local prompt_wav=$(select_file "选择音色参考音频文件" "/Users/arming/Documents/ai/seedvc-train/模仿目标声音/yue-wise-woman/audio_9347.mp3" "/Users/arming/Downloads")
    local output_dir=$(select_directory "选择输出目录" "/Users/arming/Downloads" "/Users/arming/Downloads")
    local output_file=$(generate_output_path "<sft_synthesis>" "$output_dir" "cantonese")
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "音色参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    print_info "开始  粤语专用>文转语音: $text"
    
    local model_dir=$(select_model)
    python cosyvoice_api.py cantonese_synthesis --text "$text" --prompt_wav "$prompt_wav" --output_file "$output_file" --model_dir "$model_dir"
}

# 指令控制+参考音频>文转语音
instruct2_synthesis() {
    local text=$(input_text "输入要合成的文本" "我是测试ttl文本")
    local instruct_text=$(input_text "输入指令文本" "Theo 'Crimson', is a fiery, passionate rebel leader. Fights with fervor for justice, but struggles with impulsiveness.")
    local prompt_wav=$(select_file "选择参考音频文件" "./asset/zero_shot_prompt.wav" "/Users/arming/Downloads")
    local output_dir=$(select_directory "选择输出目录" "/Users/arming/Downloads" "/Users/arming/Downloads")
    local output_file=$(generate_output_path "<sft_synthesis>" "$output_dir" "instruct2")
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    print_info "开始  指令控制+参考音频>文转语音: $text"
    
    local model_dir=$(select_model)
    python cosyvoice_api.py instruct2_synthesis --text "$text" --instruct_text "$instruct_text" --prompt_wav "$prompt_wav" --output_file "$output_file" --model_dir "$model_dir"
}

# 参考音频>源音频变声
voice_conversion() {
    local source_wav=$(select_file "选择源音频文件" "/Users/arming/Documents/filmmiking" "/Users/arming/Documents/filmmiking")
    local prompt_wav=$(select_file "选择目标音色参考音频文件" "/Users/arming/Documents/ai/seedvc-train/模仿目标声音/yue-wise-woman/audio_9347.mp3" "/Users/arming/Downloads")
    local output_dir=$(select_directory "选择输出目录" "/Users/arming/Downloads" "/Users/arming/Downloads")
    local output_file=$(generate_output_path "$source_wav" "$output_dir" "vc")
    
    if [ ! -f "$source_wav" ]; then
        print_error "源音频文件不存在: $source_wav"
        return 1
    fi
    
    if [ ! -f "$prompt_wav" ]; then
        print_error "音色参考音频文件不存在: $prompt_wav"
        return 1
    fi
    
    print_info "开始  参考音频>源音频变声"
    
    local model_dir=$(select_model)
    python cosyvoice_api.py voice_conversion --source_wav "$source_wav" --prompt_wav "$prompt_wav" --output_file "$output_file" --model_dir "$model_dir"
}

# 下载模型
download_model() {
    local model_choice
    echo "选择要下载的模型:"
    echo "1) Fun-CosyVoice3-0.5B (最新3.0模型)"
    echo "2) CosyVoice-300M-Instruct (指令控制模型)"
    echo "3) CosyVoice-300M-SFT (预训练音色模型)"
    echo "4) CosyVoice2-0.5B (增强模型)"
    echo "5) CosyVoice-300M (基础模型)"
    echo "6) Fun-CosyVoice3-1.5B (最新大模型)"
    echo -n "请选择 (1-6): "
    read -r model_choice
    
    case $model_choice in
        1)
            python -c "from modelscope import snapshot_download; snapshot_download('FunAudioLLM/Fun-CosyVoice3-0.5B-2512', local_dir='pretrained_models/Fun-CosyVoice3-0.5B')"
            ;;
        2)
            python -c "from modelscope import snapshot_download; snapshot_download('iic/CosyVoice-300M-Instruct', local_dir='pretrained_models/CosyVoice-300M-Instruct')"
            ;;
        3)
            python -c "from modelscope import snapshot_download; snapshot_download('iic/CosyVoice-300M-SFT', local_dir='pretrained_models/CosyVoice-300M-SFT')"
            ;;
        4)
            python -c "from modelscope import snapshot_download; snapshot_download('iic/CosyVoice2-0.5B', local_dir='pretrained_models/CosyVoice2-0.5B')"
            ;;
        5)
            python -c "from modelscope import snapshot_download; snapshot_download('iic/CosyVoice-300M', local_dir='pretrained_models/CosyVoice-300M')"
            ;;
        6)
            python -c "from modelscope import snapshot_download; snapshot_download('FunAudioLLM/Fun-CosyVoice3-1.5B', local_dir='pretrained_models/Fun-CosyVoice3-1.5B')"
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_info "模型下载完成"
    else
        print_error "模型下载失败"
    fi
}

# 主菜单
show_menu() {
    echo ""
    echo "==================================="
    echo "    CosyVoice 交互式命令行工具"
    echo "==================================="
    echo "1) 预训练音色>文转语音 (SFT)"
    echo "2) 自动识别语种>文转语音 (Zero-shot)"
    echo "3) 跨语种>文转语音 (Cross-lingual)"
    echo "4) 指令控制>文转语音 (Instruct)"
    echo "5) 指令控制+参考音频>文转语音 (Instruct2)"
    echo "6) 粤语专用>文转语音 (Cantonese)"
    echo "7) 参考音频>源音频变声 (Voice Conversion)"
    echo "8) 下载模型"
    echo "9) 退出"
    echo "==================================="
    echo -n "请选择功能 (1-9): "
}

# 主函数
main() {
    check_dependencies
    activate_conda_env
    
    while true; do
        show_menu
        read -r choice
        
        # 如果用户直接按回车，设置为空值
        if [ -z "$choice" ]; then
            print_error "请输入数字选项"
        elif ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            print_error "请输入数字选项"
        else
            case $choice in
                1)
                    sft_synthesis
                    ;;
                2)
                    zero_shot_synthesis
                    ;;
                3)
                    cross_lingual_synthesis
                    ;;
                4)
                    instruct_synthesis
                    ;;
                5)
                    instruct2_synthesis
                    ;;
                6)
                    cantonese_synthesis
                    ;;
                7)
                    voice_conversion
                    ;;
                8)
                    download_model
                    ;;
                9)
                    print_info "退出程序"
                    break
                    ;;
                *)
                    print_error "无效选择，请重新输入"
                    # 跳过按回车继续部分，直接回到循环开始  
                    echo ""
                    continue
                    ;;
            esac
        fi
        
        echo ""
        echo -n "按回车键继续..."
        read -r
    done
}

# 将模型名称转换为模型目录
model_name_to_dir() {
    local model_name="$1"
    case "$model_name" in
        CosyVoice3-0.5B)
            echo "pretrained_models/Fun-CosyVoice3-0.5B"
            ;;
        CosyVoice2-0.5B)
            echo "pretrained_models/CosyVoice2-0.5B"
            ;;
        CosyVoice3-1.5B)
            echo "pretrained_models/Fun-CosyVoice3-1.5B"
            ;;
        *)
            # 如果已经是完整的路径，直接返回
            echo "$model_name"
            ;;
    esac
}

cd /Users/arming/Documents/develop/third/CosyVoice

# 检查是否有命令行参数，如果有则直接执行对应功能，否则进入交互模式
if [ $# -gt 0 ]; then
    # 激活conda环境
    check_dependencies
    activate_conda_env
    
    # 有命令行参数，直接执行对应功能
    case "$1" in
        sft_synthesis)
            # 直接调用Python API，需要提供所有必需参数
            if [ $# -lt 6 ]; then
                echo "用法: $0 sft_synthesis <text> <spk_id> <output_file> <model_name>"
                echo "支持的模型名称<model_name>: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            model_dir=$(model_name_to_dir "$5")
            python cosyvoice_api.py sft_synthesis --text "$2" --spk_id "$3" --output_file "$4" --model_dir "$model_dir"
            exit $?
            ;;
        zero_shot_synthesis)
            # 直接调用Python API，需要提供所有必需参数
            if [ $# -lt 6 ]; then
                echo "用法: $0 zero_shot_synthesis <text> <prompt_text> <prompt_wav> <output_file> <model_name>"
                echo "支持的模型名称<model_name>: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            model_dir=$(model_name_to_dir "$6")
            python cosyvoice_api.py zero_shot_synthesis --text "$2" --prompt_text "$3" --prompt_wav "$4" --output_file "$5" --model_dir "$model_dir"
            exit $?
            ;;
        cross_lingual_synthesis)
            # 直接调用Python API，需要提供所有必需参数
            if [ $# -lt 5 ]; then
                echo "用法: $0 cross_lingual_synthesis <text> <prompt_wav> <output_file> <model_name>"
                echo "支持的模型名称<model_name>: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            model_dir=$(model_name_to_dir "$5")
            python cosyvoice_api.py cross_lingual_synthesis --text "$2" --prompt_wav "$3" --output_file "$4" --model_dir "$model_dir"
            exit $?
            ;;
        instruct_synthesis)
            # 直接调用Python API，需要提供所有必需参数
            if [ $# -lt 6 ]; then
                echo "用法: $0 instruct_synthesis <text> <spk_id> <instruct_text> <output_file> <model_name>"
                echo "支持的模型名称<model_name>: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            model_dir=$(model_name_to_dir "$6")
            python cosyvoice_api.py instruct_synthesis --text "$2" --spk_id "$3" --instruct_text "$4" --output_file "$5" --model_dir "$model_dir"
            exit $?
            ;;
        instruct2_synthesis)
            # 直接调用Python API，需要提供所有必需参数
            if [ $# -lt 6 ]; then
                echo "用法: $0 instruct2_synthesis <text> <instruct_text> <prompt_wav> <output_file> <model_name>"
                echo "支持的模型名称<model_name>: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            model_dir=$(model_name_to_dir "$6")
            python cosyvoice_api.py instruct2_synthesis --text "$2" --instruct_text "$3" --prompt_wav "$4" --output_file "$5" --model_dir "$model_dir"
            exit $?
            ;;
        cantonese_synthesis)
            # 直接调用Python API，需要提供所有必需参数
            if [ $# -lt 5 ]; then
                echo "用法: $0 cantonese_synthesis <text> <prompt_wav> <output_file> <model_name>"
                echo "支持的模型名称<model_name>: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            model_dir=$(model_name_to_dir "$5")
            python cosyvoice_api.py cantonese_synthesis --text "$2" --prompt_wav "$3" --output_file "$4" --model_dir "$model_dir"
            exit $?
            ;;
        voice_conversion)
            # 直接调用Python API，需要提供所有必需参数
            if [ $# -lt 5 ]; then
                echo "用法: $0 voice_conversion <source_wav> <prompt_wav> <output_file> <model_name>"
                echo "支持的模型名称<model_name>: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            model_dir=$(model_name_to_dir "$5")
            python cosyvoice_api.py voice_conversion --source_wav "$2" --prompt_wav "$3" --output_file "$4" --model_dir "$model_dir"
            exit $?
            ;;
        download_model)
            # 直接调用下载功能，需要提供模型名称
            if [ $# -lt 2 ]; then
                echo "用法: $0 download_model <model_name>"
                echo "model_name 可选值: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                exit 1
            fi
            case "$2" in
                CosyVoice3-0.5B)
                    python -c "from modelscope import snapshot_download; snapshot_download('FunAudioLLM/Fun-CosyVoice3-0.5B-2512', local_dir='pretrained_models/Fun-CosyVoice3-0.5B')"
                    ;;
                CosyVoice2-0.5B)
                    python -c "from modelscope import snapshot_download; snapshot_download('iic/CosyVoice2-0.5B', local_dir='pretrained_models/CosyVoice2-0.5B')"
                    ;;
                CosyVoice3-1.5B)
                    python -c "from modelscope import snapshot_download; snapshot_download('FunAudioLLM/Fun-CosyVoice3-1.5B', local_dir='pretrained_models/Fun-CosyVoice3-1.5B')"
                    ;;
                *)
                    echo "错误: 不支持的模型名称 '$2'"
                    echo "支持的模型名称: CosyVoice3-0.5B, CosyVoice2-0.5B, CosyVoice3-1.5B"
                    exit 1
                    ;;
            esac
            exit $?
            ;;
        *)
            echo "错误: 未知的功能 '$1'"
            echo "用法: $0 [功能名称] [参数...]"
            echo "功能名称:"
            echo "  sft_synthesis <text> <spk_id> <output_file> <model_name>          - 预训练音色>文转语音"
            echo "  zero_shot_synthesis <text> <prompt_text> <prompt_wav> <output_file> <model_name>    - 自动识别语种>文转语音"
            echo "  cross_lingual_synthesis <text> <prompt_wav> <output_file> <model_name> - 跨语种>文转语音"
            echo "  instruct_synthesis <text> <spk_id> <instruct_text> <output_file> <model_name>     - 指令控制>文转语音"
            echo "  instruct2_synthesis <text> <instruct_text> <prompt_wav> <output_file> <model_name>    - 指令控制+参考音频>文转语音"
            echo "  cantonese_synthesis <text> <prompt_wav> <output_file> <model_name>    - 粤语专用>文转语音"
            echo "  voice_conversion <source_wav> <prompt_wav> <output_file> <model_name>       - 参考音频>源音频变声"
            echo "  download_model <model_name>         - 下载模型"
            echo "  无参数                 - 进入交互模式"
            exit 0
            ;;
    esac
fi

# 执行主函数
main "$@"