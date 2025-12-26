#!/bin/bash

# 交互式选择目录
select_directory() {
    local prompt="$1"
    local default="$2"
    
    echo -n "$prompt"
    if [ -n "$default" ]; then
        echo -n " (默认: $default)"
    fi
    echo -n ": "
    
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        echo "$default"
    else
        echo "$input"
    fi
}

# 根据源文件名生成输出文件路径
generate_output_path() {
    local source_file="$1"
    local output_dir="$2"
    local suffix="$3"
    
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
        echo "$output_dir/${name}_${suffix}.$extension"
    fi
}

echo "测试新功能："
echo "1. 为参考音频生成输出路径："
result1=$(generate_output_path "./asset/test.wav" "./test_output" "vc")
echo "   $result1"

echo "2. 为SFT合成生成输出路径："
result2=$(generate_output_path "<sft_synthesis>" "./test_output" "sft")
echo "   $result2"

echo "3. 测试目录创建功能："
test_dir=$(select_directory "选择测试目录" "./test_output")
echo "   选择的目录: $test_dir"

echo "所有测试完成！"