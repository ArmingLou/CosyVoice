#!/usr/bin/env python
"""
CosyVoice API 接口脚本
提供命令行接口来调用 CosyVoice 的各种功能
"""

import sys
import os
import argparse
import torchaudio
from pathlib import Path

# 添加项目路径
sys.path.append(os.path.join(os.path.dirname(__file__)))
sys.path.append(os.path.join(os.path.dirname(__file__), 'third_party/Matcha-TTS'))

from cosyvoice.cli.cosyvoice import AutoModel
from cosyvoice.utils.file_utils import logging
from cosyvoice.utils.class_utils import get_model_type
from hyperpyyaml import load_hyperpyyaml


def get_model_version(model_dir):
    """检测模型版本"""
    if os.path.exists('{}/cosyvoice3.yaml'.format(model_dir)):
        return 'cosyvoice3'
    elif os.path.exists('{}/cosyvoice2.yaml'.format(model_dir)):
        return 'cosyvoice2'
    elif os.path.exists('{}/cosyvoice.yaml'.format(model_dir)):
        return 'cosyvoice1'
    else:
        raise ValueError('无法识别模型版本')


def format_zero_shot_prompt_for_version(user_prompt_text, model_version):
    """根据模型版本格式化零样本提示文本，将用户输入内容与固定提示语组合
    
    用于 inference_zero_shot 方法
    - CosyVoice3: 'You are a helpful assistant.<|endofprompt|>{用户内容}'
    - CosyVoice2: '{用户内容}'
    - CosyVoice1: '{用户内容}'
    """
    if model_version == 'cosyvoice3':
        # CosyVoice3 零样本需要 <|endofprompt|> 标记，格式为 'You are a helpful assistant.<|endofprompt|>{用户内容}'
        formatted_prompt = f'You are a helpful assistant.<|endofprompt|>{user_prompt_text}'
    elif model_version == 'cosyvoice2':
        # CosyVoice2 零样本不需要 <|endofprompt|> 标记
        formatted_prompt = user_prompt_text
    else:
        # CosyVoice1 零样本不需要 <|endofprompt|> 标记
        formatted_prompt = user_prompt_text
    
    return formatted_prompt


def format_instruct_prompt_for_version(user_instruct_text, model_version):
    """根据模型版本格式化指令提示文本，将用户输入内容与固定提示语组合
    
    用于 inference_instruct 和 inference_instruct2 方法
    - CosyVoice3: 'You are a helpful assistant. {用户指令}<|endofprompt|>'
    - CosyVoice2: '{用户指令}<|endofprompt|>'
    - CosyVoice1: '{用户指令}<|endofprompt|>'
    """
    if model_version == 'cosyvoice3':
        # CosyVoice3 指令控制需要 <|endofprompt|> 标记，格式为 'You are a helpful assistant. {用户指令}. <|endofprompt|>'
        formatted_instruct = f'You are a helpful assistant. {user_instruct_text}<|endofprompt|>'
    elif model_version == 'cosyvoice2':
        # CosyVoice2 指令控制需要 <|endofprompt|> 标记，但不需要 'You are a helpful assistant.'
        formatted_instruct = f'{user_instruct_text}<|endofprompt|>'
    else:
        # CosyVoice1 指令控制需要 <|endofprompt|> 标记，格式可能包含详细的角色描述
        formatted_instruct = f'{user_instruct_text}<|endofprompt|>'
    
    return formatted_instruct


def format_cross_lingual_text_for_version(user_text, model_version):
    """根据模型版本格式化跨语种文本
    
    用于 inference_cross_lingual 方法
    - CosyVoice3: 'You are a helpful assistant.<|endofprompt|>{用户内容}'
    - CosyVoice2/CosyVoice1: {用户内容}
    """
    if model_version == 'cosyvoice3':
        # CosyVoice3 跨语种需要 <|endofprompt|> 标记
        if '<|endofprompt|>' not in user_text:
            # 如果用户输入中没有 <|endofprompt|> 标记，自动添加
            return f'You are a helpful assistant.<|endofprompt|>{user_text}'
        else:
            # 如果用户输入中已有 <|endofprompt|> 标记，直接返回
            return user_text
    else:
        # CosyVoice2 和 CosyVoice1 跨语种不支持 <|endofprompt|> 标记
        return user_text.replace('<|endofprompt|>', '')


def load_model_for_version(model_dir, load_jit=False, load_trt=False, load_vllm=False, fp16=False, trt_concurrent=1):
    """根据模型版本自动加载对应的模型"""
    # 检测模型版本以确定支持的参数
    model_version = get_model_version(model_dir)
    
    if model_version == 'cosyvoice3':
        # CosyVoice3 不支持 load_jit 参数
        cosyvoice = AutoModel(
            model_dir=model_dir,
            load_trt=load_trt,
            load_vllm=load_vllm,
            fp16=fp16,
            trt_concurrent=trt_concurrent
        )
    else:
        # CosyVoice1 和 CosyVoice2 支持 load_jit 参数
        cosyvoice = AutoModel(
            model_dir=model_dir,
            load_jit=load_jit,
            load_trt=load_trt,
            load_vllm=load_vllm,
            fp16=fp16,
            trt_concurrent=trt_concurrent
        )
    return cosyvoice


def sft_synthesis(text, spk_id, output_file, model_dir):
    """预训练音色合成"""
    cosyvoice = load_model_for_version(model_dir)
    for i, j in enumerate(cosyvoice.inference_sft(text, spk_id)):
        torchaudio.save(output_file, j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
        break
    print(f"音频已保存到: {output_file}")


def zero_shot_synthesis(text, prompt_text, prompt_wav, output_file, model_dir):
    """零样本语音克隆"""
    # 检测模型版本并格式化提示文本
    model_version = get_model_version(model_dir)
    formatted_prompt_text = format_zero_shot_prompt_for_version(prompt_text, model_version)
    
    cosyvoice = load_model_for_version(model_dir)
    for i, j in enumerate(cosyvoice.inference_zero_shot(text, formatted_prompt_text, prompt_wav)):
        torchaudio.save(output_file, j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
        break
    print(f"音频已保存到: {output_file}")


def cross_lingual_synthesis(text, prompt_wav, output_file, model_dir):
    """跨语种复刻"""
    # 检测模型版本并格式化文本
    model_version = get_model_version(model_dir)
    formatted_text = format_cross_lingual_text_for_version(text, model_version)
    
    cosyvoice = load_model_for_version(model_dir)
    for i, j in enumerate(cosyvoice.inference_cross_lingual(formatted_text, prompt_wav)):
        torchaudio.save(output_file, j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
        break
    print(f"音频已保存到: {output_file}")


def instruct_synthesis(text, spk_id, instruct_text, output_file, model_dir):
    """指令控制合成"""
    # 检测模型版本并格式化指令文本
    model_version = get_model_version(model_dir)
    formatted_instruct_text = format_instruct_prompt_for_version(instruct_text, model_version)
    
    cosyvoice = load_model_for_version(model_dir)
    for i, j in enumerate(cosyvoice.inference_instruct(text, spk_id, formatted_instruct_text)):
        torchaudio.save(output_file, j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
        break
    print(f"音频已保存到: {output_file}")


def cantonese_synthesis(text, prompt_wav, output_file, model_dir):
    """粤语语音变声"""
    # 检测模型版本并格式化提示文本
    model_version = get_model_version(model_dir)
    
    # 粤语指令文本（用户输入部分）
    cantonese_user_instruct = '请用广东话表达.'
    formatted_instruct_text = format_instruct_prompt_for_version(cantonese_user_instruct, model_version)
    
    cosyvoice = load_model_for_version(model_dir)
    for i, j in enumerate(cosyvoice.inference_instruct2(text, formatted_instruct_text, prompt_wav)):
        torchaudio.save(output_file, j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
        break
    print(f"音频已保存到: {output_file}")


def voice_conversion(source_wav, prompt_wav, output_file, model_dir):
    """语音转换"""
    cosyvoice = load_model_for_version(model_dir)
    for i, j in enumerate(cosyvoice.inference_vc(source_wav, prompt_wav)):
        torchaudio.save(output_file, j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
        break
    print(f"音频已保存到: {output_file}")


def instruct2_synthesis(text, instruct_text, prompt_wav, output_file, model_dir):
    """指令合成参考音频文转语音"""
    # 检测模型版本并格式化提示文本
    model_version = get_model_version(model_dir)
    formatted_instruct_text = format_instruct_prompt_for_version(instruct_text, model_version)
    
    cosyvoice = load_model_for_version(model_dir)
    for i, j in enumerate(cosyvoice.inference_instruct2(text, formatted_instruct_text, prompt_wav)):
        torchaudio.save(output_file, j['tts_speech'], cosyvoice.sample_rate, backend='soundfile')
        break
    print(f"音频已保存到: {output_file}")


def main():
    parser = argparse.ArgumentParser(description='CosyVoice API 接口')
    parser.add_argument('function', choices=[
        'sft_synthesis', 'zero_shot_synthesis', 'cross_lingual_synthesis', 
        'instruct_synthesis', 'instruct2_synthesis', 'cantonese_synthesis', 'voice_conversion'
    ], help='要执行的功能')
    
    # 通用参数
    parser.add_argument('--model_dir', default='pretrained_models/Fun-CosyVoice3-0.5B', help='模型目录')
    
    # SFT 参数
    parser.add_argument('--text', help='要合成的文本')
    parser.add_argument('--spk_id', default='中文女', help='音色ID')
    
    # 零样本参数
    parser.add_argument('--prompt_text', help='参考文本')
    parser.add_argument('--prompt_wav', help='参考音频文件路径')
    
    # 语音转换参数
    parser.add_argument('--source_wav', help='源音频文件路径')
    
    # 指令控制参数
    parser.add_argument('--instruct_text', help='指令文本')
    
    # 输出参数
    parser.add_argument('--output_file', required=True, help='输出文件路径')
    
    args = parser.parse_args()
    
    try:
        if args.function == 'sft_synthesis':
            sft_synthesis(args.text, args.spk_id, args.output_file, args.model_dir)
        elif args.function == 'zero_shot_synthesis':
            zero_shot_synthesis(args.text, args.prompt_text, args.prompt_wav, args.output_file, args.model_dir)
        elif args.function == 'cross_lingual_synthesis':
            cross_lingual_synthesis(args.text, args.prompt_wav, args.output_file, args.model_dir)
        elif args.function == 'instruct_synthesis':
            instruct_synthesis(args.text, args.spk_id, args.instruct_text, args.output_file, args.model_dir)
        elif args.function == 'instruct2_synthesis':
            instruct2_synthesis(args.text, args.instruct_text, args.prompt_wav, args.output_file, args.model_dir)
        elif args.function == 'cantonese_synthesis':
            cantonese_synthesis(args.text, args.prompt_wav, args.output_file, args.model_dir)
        elif args.function == 'voice_conversion':
            voice_conversion(args.source_wav, args.prompt_wav, args.output_file, args.model_dir)
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)


def example_usage():
    """使用示例"""
    # 示例：零样本语音克隆
    # 用户只需输入他们想要的提示文本，不需要关心版本特定的格式
    zero_shot_synthesis(
        text="你好，这是CosyVoice的测试。",
        prompt_text="希望你以后能够做的比我还好呦。",
        prompt_wav="./asset/zero_shot_prompt.wav",
        output_file="zero_shot_output.wav",
        model_dir="pretrained_models/Fun-CosyVoice3-0.5B"
    )
    
    # 示例：指令控制语音合成
    instruct2_synthesis(
        text="请用四川话说这句话",
        instruct_text="用四川话说这句话",
        prompt_wav="./asset/zero_shot_prompt.wav",
        output_file="instruct_output.wav",
        model_dir="pretrained_models/Fun-CosyVoice3-0.5B"
    )
    
    # 示例：粤语语音变声
    cantonese_synthesis(
        text="好少咯，一般系放嗰啲国庆啊，中秋嗰啲可能会咯。",
        prompt_wav="./asset/zero_shot_prompt.wav",
        output_file="cantonese_output.wav",
        model_dir="pretrained_models/Fun-CosyVoice3-0.5B"
    )


if __name__ == "__main__":
    main()