# 配置字段与约束

所有 JSON 顶层 `schema_version` 为 1；ID 使用小写 ASCII snake_case。名字用于显示，ID 用于引用。当前逻辑单位为格、秒、HP、整金币；抗性、概率与倍率均为 0 至 1 范围内的小数，伤害倍率可大于 1。

|文件|主要字段|必须检查|
|---|---|---|
|maps/confluence_courtyard.json|grid_size、routes、nodes、gates、exits|坐标范围、节点 ID 唯一、路线长度、无环、分流前缀相同|
|towers.json|towers、damage_multiplier_by_level、upgrade_cost_ratio|造价正数、射程／间隔正数、空地目标合法、升级数量正确|
|enemies.json|enemies、hp_growth_per_wave|生命速度正数、抗性不高于 0.8、赏金非负、boss 不叠波次增长|
|heroes.json|heroes、skills|角色与技能 ID 唯一、冷却正数；光环／救援边界按规则文档|
|waves/courtyard_normal.json|wave、reward_per_player、events|波连续、时间非负、有序、引用 enemy_id 存在、入口合法|
|rules.json|经济、连锁、机关、共鸣、频率与端口|赏金比例、HP 正数、模拟频率可整除快照频率、端口不重叠|

出怪表已展开为每只敌人的 entry／enemy_id／time。第 4 波分组间隔按每侧队列分半后额外 +6 秒；第 10 波首领独立延迟 8 秒，不占其他兵的队列位置。扩展时可生成编辑友好的组表，但运行配置仍以已展开事件作为唯一基准。

基础生命乘以 1 + 0.08 ×（wave − 1），nearest half up；普通难度倍率 1。路线按敌人的 route_id 与行进距离存储，不以屏幕位置推导出口。金币余数用四分之一金币单位保存，界面只显示可消费整金币。

默认基础暴击率 0；共享塔的金币、伤害与状态归属跟随当前管理者。转交不改变塔等级与冷却，已有投射物与状态保留发射／施加时所有者，避免转交瞬间改变连锁归属。转交只在准备期，接收者确认后完成。

命令负载字段约定：build(node_id,tower_id)、upgrade(tower_instance_id)、sell(tower_instance_id)、transfer(amount)、hero_move(position)、cast(skill_id,target)、gate_request(gate_id)、gate_reply(request_id,accept)、ultimate_ready、pause_reply、ready。Host 补齐 owner 与 match_id，校验后返回 command_id、accepted、reason_code、authoritative_tick；不能只返回布尔值。

本次配置覆盖数值起点，不是运行时加载器。字段格式校验由设计工具提供，引擎内的加载、消息序列化和版本哈希是 T01／T06 的实现任务。
