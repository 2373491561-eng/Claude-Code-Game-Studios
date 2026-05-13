# 像素素材 AI 生成提示词

> 使用方法：每段单独发给 AI 图片生成工具（Midjourney / DALL-E / Stable Diffusion）。
> 所有角色必须同一批次生成，保持风格一致。

---

## 共用后缀（每个 Prompt 末尾都加上）
```
game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art, 1-bit shading, sharp silhouette
```

---

## 1. 玩家角色

```
top-down view pixel art, 45 degree isometric angle, a sci-fi soldier in combat armor,
electric blue primary color with orange-red visor glow,
24x24 pixel size, 4-direction character sprite sheet (up down left right),
simple clean silhouette, minimal detail, no face, helmet only,
dark background, game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art, 1-bit shading, sharp silhouette
```

| 用途 | 替换 `PlayerSprite` ColorRect |
|------|------|
| 尺寸 | 24×24px |
| 朝向 | 4 方向（单帧即可） |
| 配色 | 电光蓝 #4488FF + 橙红 #FF4422 |

---

## 2. 小型敌人（虫群）

```
top-down view pixel art, 45 degree isometric angle, a swarm of small alien insect creatures,
green carapace with dark grey legs, 16x24 pixel size,
4-direction sprite sheet (up down left right), multiple variants (3 different insects),
bug-like silhouette, antennae visible, small and numerous feel,
game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art, 1-bit shading, sharp silhouette
```

| 用途 | 替换小兵 ColorRect |
|------|------|
| 尺寸 | 16×24px |
| 朝向 | 4 方向 |
| 配色 | 绿 #33CC44 + 深灰 #333333 |

---

## 3. 中型敌人（远程类人）

```
top-down view pixel art, 45 degree isometric angle, a humanoid alien soldier,
orange-brown exoskeleton, holding a bio-rifle with both hands,
32x48 pixel size, 4-direction sprite sheet (up down left right),
tall lanky silhouette, weapon visible from top-down view,
game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art, 1-bit shading, sharp silhouette
```

| 用途 | 替换中兵 ColorRect |
|------|------|
| 尺寸 | 32×48px |
| 朝向 | 4 方向 |
| 配色 | 橙棕 #CC8833 + 深灰 |

---

## 4. 大型敌人（Boss，未来用）

```
top-down view pixel art, 45 degree isometric angle, a massive alien behemoth,
dark red and black armored plates, 64x64 pixel size,
4-direction sprite sheet (up down left right), heavy imposing silhouette,
thick legs and massive torso, visible from above,
game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art, 1-bit shading, sharp silhouette
```

| 用途 | Boss 敌人 |
|------|------|
| 尺寸 | 64×64px |
| 朝向 | 4 方向 |
| 配色 | 深红 #AA2222 + 黑 #111111 |

---

## 5. 子弹（我方）

```
top-down view pixel art, a bright energy bullet projectile,
electric blue with white-hot core, 4x16 pixel size, elongated shape,
single frame, no rotation needed, glowing appearance,
game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art
```

| 用途 | 替换弹道线 |
|------|------|
| 尺寸 | 4×16px |

---

## 6. 弹幕（敌方）

```
top-down view pixel art, an orange-red enemy projectile,
small glowing orb, 8x8 pixel size, round shape,
single frame, fiery toxic appearance,
game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art
```

| 用途 | 替换敌方弹幕 |
|------|------|
| 尺寸 | 8×8px |

---

## 7. 技能冲击波

```
top-down view pixel art, a circular shockwave energy blast,
electric blue outer ring with orange-red core burst,
64x64 pixel size, expanding ring shape, centered,
game asset sprite, centered on canvas, transparent background,
clean pixel edges, no gradients, no shadows, no anti-aliasing,
retro arcade style, flat pixel art
```

| 用途 | 替换 `_draw` 蓝色圆弧 |
|------|------|
| 尺寸 | 64×64px |

---

## 生成顺序

```
1. 先出玩家 + 一个小兵 → 确认风格统一
2. 风格定了再批量出剩下的
3. 全部导出为 PNG，放在 assets/sprites/
4. 在 Godot 里用 Sprite2D 替换 ColorRect
```

## 风格参考

目标风格接近：Hotline Miami / Enter the Gungeon / Hyper Light Drifter

- 硬边缘、无抗锯齿
- 有限色板（5-8 色）
- 强对比、高辨识度轮廓
- 45° 俯视透视
