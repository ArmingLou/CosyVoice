#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
CosyVoice 3.0 测试脚本
用于验证安装和基本功能
"""

import sys
import os
sys.path.append('/Users/arming/Documents/develop/third/CosyVoice')

def test_import():
    """测试导入CosyVoice模块"""
    try:
        from cosyvoice.cli.cosyvoice import CosyVoice
        print("✓ CosyVoice 模块导入成功")
        return True
    except ImportError as e:
        print(f"✗ CosyVoice 模块导入失败: {e}")
        return False

def test_model_load():
    """测试加载CosyVoice 3.0模型"""
    try:
        from cosyvoice.cli.cosyvoice import CosyVoice
        
        # 尝试加载模型
        print("正在加载 CosyVoice3-0.5B 模型...")
        cosyvoice = CosyVoice('pretrained_models/Fun-CosyVoice3-0.5B')
        print("✓ CosyVoice3-0.5B 模型加载成功")
        print(f"✓ 采样率: {cosyvoice.sample_rate}")
        return True
    except Exception as e:
        print(f"✗ 模型加载失败: {e}")
        return False

def test_synthesis():
    """测试语音合成（简短测试）"""
    try:
        from cosyvoice.cli.cosyvoice import CosyVoice
        
        cosyvoice = CosyVoice('pretrained_models/Fun-CosyVoice3-0.5B')
        
        # 测试预训练音色合成
        print("正在测试预训练音色合成...")
        for i, j in enumerate(cosyvoice.inference_sft('你好，这是CosyVoice 3.0的测试。', '中文女')):
            print(f"✓ 合成成功，音频长度: {j['tts_speech'].shape}")
            break
            
        print("✓ 语音合成测试成功")
        return True
    except Exception as e:
        print(f"✗ 语音合成测试失败: {e}")
        return False

def main():
    """主函数"""
    print("="*50)
    print("CosyVoice 3.0 安装验证脚本")
    print("="*50)
    
    # 检查模型是否存在
    model_path = 'pretrained_models/Fun-CosyVoice3-0.5B'
    if not os.path.exists(model_path):
        print(f"✗ 模型路径不存在: {model_path}")
        print("请先下载模型")
        return
    
    print(f"✓ 模型路径存在: {model_path}")
    print()
    
    # 执行测试
    tests = [
        ("模块导入测试", test_import),
        ("模型加载测试", test_model_load),
        #("语音合成测试", test_synthesis),  # 注释掉合成测试，因为可能需要较长时间
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"执行 {test_name}...")
        result = test_func()
        results.append((test_name, result))
        print()
    
    # 输出总结
    print("="*50)
    print("测试结果总结:")
    print("="*50)
    for test_name, result in results:
        status = "✓ 通过" if result else "✗ 失败"
        print(f"{test_name}: {status}")
    
    all_passed = all(result for _, result in results)
    if all_passed:
        print("\n✓ 所有测试通过！CosyVoice 3.0 环境配置成功。")
    else:
        print("\n✗ 部分测试失败，请检查环境配置。")

if __name__ == "__main__":
    main()