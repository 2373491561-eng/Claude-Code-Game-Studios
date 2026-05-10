# Accessibility Requirements — 裂隙反应

## Tier: Basic

MVP 阶段实现基础无障碍支持。Tier 2 升级到 Standard。

## Requirements

### Input Remapping
- 所有游戏动作通过 Godot Input Map 绑定（不硬编码按键）
- 支持键盘/鼠标和部分手柄
- Shift + 右键双通道闪避保留

### Visual Clarity
- 敌人类型通过尺寸区分（16-24/32-48/64-96px）——非仅颜色
- 充能球状态通过颜色+脉动频率双重编码
- 中型敌人子弹 3×3px，与背景对比度 ≥3:1
- 极限闪避冷色滤镜持续时间短暂（200ms）——不影响持续可读性

### Color Vision Deficiency
- 充能球"就绪"状态：橙红脉动 + 5Hz 高频闪烁——不依赖红绿辨别
- 血量光环段数（3 段）比颜色变化更可靠
- 闪避光点数量（1-3 个）直接对应充能次数

### Known Gaps (Tier 2)
- 无屏幕阅读器支持
- 无文本缩放选项
- 无自定义色盲模式（仅美术圣经中的调色板安全设计）
- 无按键完全自定义（固定映射）
