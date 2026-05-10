# Epic: 跨局进度

> **Layer**: Feature
> **GDD**: design/gdd/meta-progression.md
> **Architecture Module**: MetaProgression
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现跨局成长系统——每局结束后根据表现（击杀数×0.1 + 波次数×1）获得点数。点数达到阈值解锁新升级选项加入随机池。进度由 SaveManager 持久化。死亡结算画面展示点数获取和解锁进度。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0014: Save system | JSON 持久化解锁列表 | LOW |
| ADR-0006: Scene lifecycle | GameManager 承载跨局数据 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-meta-001 | 点数计算：floor(kills×0.1 + wave×1) | 设计层，无需 ADR |
| TR-meta-002 | 解锁阈值持久化（5/15/25/40/60） | ADR-0014 ✅ |

## Definition of Done

- 点数计算公式实现
- 结算画面展示点数+解锁进度
- 解锁内容加入构筑随机池
- 进度通过 SaveManager 持久化
- 所有验收标准通过测试

## Next Step

Run `/create-stories meta-progression`
