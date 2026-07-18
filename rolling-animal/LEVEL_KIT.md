# 关卡套件（Level Kit）使用说明

这套东西让你搭「能死、能重生、有检查点」的关卡**几乎不用写代码**——靠把物件放进约定好的**组**自动接线。核心是一个 `RespawnManager` 节点 + 三个组。

> 主角必须是 `SoftPlayer`（用到它的 `reset_size()` / `reset_motion_visuals()`）。

---

## 一分钟上手：新建一关

1. 关卡根节点用 `Node2D`。
2. 加一个 **RespawnManager**（在「创建节点」里直接搜 `RespawnManager` 就有）+ 一个 **DefaultSpawn**（`Marker2D`，摆在起点）。选中 RespawnManager，检查器把 `Player`、`Default Spawn` 拖上（拖不上也行，它会自动全树找 `SoftPlayer` 兜底）。
3. 放主角实例（`scenes/player/player.tscn`），给它加个 `Camera2D` 子节点跟随。
4. 放危险物（毒水用 `PoisonWater.tscn`）、检查点（`Checkpoint.tscn`）。**不用连任何线。**
5. F6 运行。碰到危险物 → 回最近检查点。

参考成品：`scenes/Stage1.tscn`。

---

## 三个组 —— 这就是全部「接线」

RespawnManager 进场后自动扫描这三个组并接管。你只要保证物件在对的组里（**母本都已内置组，实例会继承，什么都不用做**）：

| 组名 | 物件需要有 | 会发生什么 |
|---|---|---|
| `hazards` | 信号 `player_died(player, effect)` | 玩家碰到 →（可选特效）→ 回最近检查点 |
| `checkpoints` | 信号 `activated(cp)` + `order:int` + 方法 `get_respawn_position()` | 玩家经过 → 更新重生点（只前进不后退） |
| `resettable` | 方法 `reset_state()` | 每次重生时被调用 → 恢复本段状态（比如破坏的墙长回来） |

---

## 组件清单

### RespawnManager — `scripts/levels/respawn_manager.gd`
每关放一个。逐检查点重生（死了不回起点，回最近检查点，无限重试）。

导出项：
- `player`：主角（留空自动找）。
- `default_spawn`：起点 = 0 号检查点（**建议一定要设**，否则第一个检查点之前死会重生到玩家初始位置 / 极端情况 (0,0)）。
- `death_effect_offset`：死亡特效相对玩家（脚底为原点）的位置，默认 `(0,-150)` = 头顶。

### 危险物：Killzone / PoisonWater — `scenes/obstacle/original/`
「碰到即死」的通用母本。地刺、毒水、岩浆都用它，换碰撞形状 + 换皮即可，逻辑不用改。
- 已在 `hazards` 组、已发 `player_died`，**零连线**。
- 导出 `death_effect`：留空 = 瞬间重生（毒水就留空）；拖入特效 = 死亡先播特效再重生。

### 检查点：Checkpoint — `scenes/obstacle/original/Checkpoint.tscn`
玩家进入即设为当前重生点，旗子变绿。
- 导出 `order`：段序号，越靠后越大（防止回头触发旧点，从左到右填 0/1/2…）。
- 子节点 `RespawnPoint`(Marker2D)：重生落点，摆到安全站立处。

### 眩晕特效：StunEffect — `scenes/effects/StunEffect.tscn`
星星沿椭圆绕头顶转一小段，播完发 `finished` 信号并自毁。**完全自包含，任何场景任何地方都能用。**

两种用法：
1. **当死亡特效**：把它拖进某个 hazard 的 `death_effect`。
2. **单独播**（被撞、答错等任意眩晕反馈）：
   ```gdscript
   var fx = preload("res://scenes/effects/StunEffect.tscn").instantiate()
   some_node.add_child(fx)
   fx.position = Vector2(0, -150)  # 头顶
   await fx.finished               # 想等它播完再干别的（可选）
   ```
换成自己的星星贴图：打开 `StunEffect.tscn`，根节点检查器设 `star_texture`。数量/椭圆/转速/时长都在导出项里。

---

## 破坏墙（glass.gd）—— 重点：星星什么时候才播

破坏墙有两个**默认关闭**的开关，行为完全由它们决定：

| `stun_if_too_small` | `death_effect` | 太小撞墙时 | 够大撞墙时 |
|---|---|---|---|
| **false（默认）** | 任意 | 什么都不发生（墙挡着，过不去） | 撞碎 |
| true | 留空 | 立刻重生（**无特效**） | 撞碎 |
| true | 拖入 StunEffect | **播星星 → 重生** | 撞碎 |

**关键结论（正好是你担心的两点）：**
- **别人的墙默认永远不会冒星星。** `stun_if_too_small` 默认 false，墙这时根本不进 `hazards` 组、不与 RespawnManager 相连，太小撞它只是过不去——和原版一模一样。想要星星必须**主动**把两个开关都设上。
- **想要星星却没播？** 检查是不是只开了 `stun_if_too_small` 但忘了拖 `death_effect`（那样是「瞬间重生、无特效」）。两个都设才有星星。

另一个独立开关：
- `restore_on_respawn`（默认 false）：开了以后撞碎的墙**不销毁只失效**，重生时通过 `resettable` 组自动长回来（死了重来墙还在）。关掉 = 老行为（`queue_free` 销毁）。
- `grow_grace_time`：太小撞墙后允许原地狂点变大的宽限秒数；`0` = 一碰就判定。

> ⚠️ 别把出生点 / 检查点放进一堵会恢复的墙里，否则恢复瞬间玩家会卡进墙。

---

## FAQ

- **我的危险物碰上去不死？** 它在 `hazards` 组里吗？有没有发 `player_died` 信号？（用 Killzone/PoisonWater 母本就自带，自制的要记得加。）
- **重生跑到 (0,0) / 屏幕外？** RespawnManager 的 `default_spawn` 没设，且检查点还没触发。设上 `default_spawn`。
- **检查点顺序乱 / 回头触发了旧检查点？** 每个 Checkpoint 的 `order` 从左到右递增填。
- **破坏墙冒了不该冒的星星 / 该冒没冒？** 看上面那张真值表，星星 = `stun_if_too_small=true` 且 `death_effect` 有值，两者缺一都不会播。

---

## 给要自制物件的人：签名速查

```gdscript
# 自制危险物（hazard）：进组 + 发这个信号即可被 RespawnManager 接管
signal player_died(player: SoftPlayer, effect: PackedScene)   # effect 可为 null=瞬死
func _ready(): add_to_group("hazards")

# 自制检查点（checkpoint）
signal activated(cp)                       # 进组 "checkpoints"
@export var order := 0
func get_respawn_position() -> Vector2: ...

# 自制可复位物件（resettable）：重生时会被自动调用
func reset_state() -> void: ...            # 进组 "resettable"
```

现成母本（Killzone / PoisonWater / Checkpoint / breakable obstacle / StunEffect）已经把这些都实现好了，优先复用它们。
