## Killzone —— “碰到即死”危险区的通用母本 scene（graybox 阶段用）。
##
## 【这是什么】
## 一个 Area2D：只要 SoftPlayer 碰到它，就广播“玩家死了”。地刺、毒水、岩浆、
## 掉落死亡线……凡是“碰到就死 → 回检查点重生”的东西，都用这一个母本，逻辑不用重写。
##
## 【怎么做一种新危险物】
## 1. 实例化这个母本（或复制一份改名，如 Spike / PoisonWater）。
## 2. 改 CollisionShape2D 的形状 / 大小 = 改死亡判定范围。
## 3. 换 Placeholder 的颜色，之后换成 Sprite 贴图 = 换皮。逻辑一行都不用动。
##
## 【摆放提示】
## · 地刺类：坐在实心地面“上面”，碰撞框只盖住尖端那一块。
## · 毒水类：放在地面的“缺口”里（那儿没有地板），碰撞框铺满水面及以下；玩家没跳过去
##   就掉进去死。铺在实心地板上会碰不到——记得给 TileMap 地面留洞。
##
## 【怎么接线】—— 不用接。
## 母本已经在 "hazards" 组里（实例会继承）。场景里的 RespawnManager 会自动收集这个组、
## 连上 player_died 信号，负责“传送回最近检查点 + 恢复默认大小”。新加的 Killzone 进组即可，零连线。
##
## 【死亡特效】可选：给 death_effect 拖入一个特效母本（如 StunEffect.tscn），死亡会先播它再重生；
## 留空则瞬间重生。毒水一般留空（瞬死），撞墙那种才用眩晕特效。
##
## 【注意】
## · 主角 SoftPlayer(CharacterBody2D) 自己没有 die()，所以这里只“检测 + 发信号”，不自己
##   处理重生（重生是关卡/RespawnManager 的事，各段解耦）。
## · 死亡与玩家大小无关（大小机制在别的物件上体现）。
class_name Killzone
extends Area2D

signal player_died(player: SoftPlayer, effect: PackedScene)

## 死亡特效（留空=瞬间重生，无特效）。
@export var death_effect: PackedScene

var _killed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if _killed:
		return
	if body is SoftPlayer:
		_killed = true
		player_died.emit(body, death_effect)


func _on_body_exited(body: Node2D) -> void:
	# 玩家被重生传送离开后解锁，允许再次触发。
	if body is SoftPlayer:
		_killed = false
