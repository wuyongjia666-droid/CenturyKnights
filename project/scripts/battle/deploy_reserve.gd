class_name CKDeployReserve
extends RefCounted
## P2 预备换人。Board #1 locked 2026-10-12：从地图边缘进场，不占死者格。
## P0 只钳人数到六；本模块先把入口约定写死，避免日后默认改成死者格。

const ENTRY := "map_edge"  # alternate: "fallen_cell" — not used unless paper drills fail
const HALL_LEVELS_WITHOUT_EXTRA_CAP := [4, 5]  # 厅堂 4/5 不加人，只计入工事志向


static func entry_mode() -> String:
	return ENTRY


static func enters_from_edge() -> bool:
	return ENTRY == "map_edge"
