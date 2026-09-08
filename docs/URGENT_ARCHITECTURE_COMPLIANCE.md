# 🔴 紧急任务：架构合规整改（最高优先级，阻塞其他开发）

> **发布时间**：2026-09-08 10:20
> **发布原因**：用户反馈战策仍在按自己节奏开发，未执行架构红线。A*寻路等功能自行实现，未检查Arboreus SDK能力。DEVLOG中无架构合规记录。
> **执行要求**：战策下一轮必须优先完成本任务，未完成前不得进行其他功能开发。

---

## 一、必须立即完成的事项（按顺序）

### 1. 读取并理解架构红线
- 读取 `docs/ARCHITECTURE_BOUNDARY.md`
- 读取 `docs/ARCHITECTURE_COMPLIANCE_CHECKLIST.md`
- 确认理解：战策只做应用层，灵魂和世界核心能力完全依赖Ember/Arboreus SDK

### 2. 检查Arboreus SDK的路径寻路能力
- 读取 `D:\Sojourn\arboreus\docs\SDK.md`
- 读取 `D:\Sojourn\arboreus\docs\SDK_API.md`
- 确认Arboreus SDK是否已有路径规划/寻路相关API
- **如果有**：评估替换本轮A*寻路实现的可行性，制定替换计划
- **如果没有**：在DEVLOG中记录`[SDK需求]`，写明需要的路径规划API接口，提给Arboreus任务

### 3. 检查Ember SDK的AI决策能力
- 读取 `D:\Sojourn\ember\dist\sdk\SDK_README.md`
- 读取 `D:\Sojourn\ember\dist\sdk\sdk-manifest.json`
- 确认Ember SDK是否已有感知-决策-行动循环相关API
- **如果有**：评估替换SoulAIController的可行性，制定替换计划
- **如果没有**：在DEVLOG中记录`[SDK需求]`，提给Ember任务

### 4. 梳理当前所有越界实现
- 列出战策当前所有自己实现的、属于"禁止做的"范围的模块
- 对每个模块：SDK有没有现成能力？如果没有，是否已提SDK需求？
- 制定替换优先级和计划

### 5. 在DEVLOG中记录架构合规检查结果
- 按照 `docs/ARCHITECTURE_COMPLIANCE_CHECKLIST.md` 第三章的格式
- 必须包含：架构合规检查结果、SDK使用情况、越界模块替换进度

---

## 二、后续每轮必须遵守的规则

1. **每轮第一项**：完成 `docs/ARCHITECTURE_COMPLIANCE_CHECKLIST.md` 的所有检查项
2. **开发前先查SDK**：Ember SDK和Arboreus SDK有没有现成能力
3. **没有就提需求**：SDK没有的能力，提需求给引擎任务，不自己实现
4. **临时实现必须标记**：代码中加`// TODO: 临时实现，待SDK能力上线后替换`
5. **DEVLOG必须有架构合规章节**：每轮都要记录

---

## 三、监控会做的事

1. 每轮检查战策DEVLOG是否有架构合规章节
2. 每轮检查战策是否有新增越界实现
3. 发现违规立即指出，要求下一轮修正
4. 连续两轮违规，更新战策任务prompt强化约束
5. 严重情况可暂停战策任务直到整改完成

---

## 四、为什么要这样做

- 项目目标是构建基于Ember灵魂引擎和Arboreus世界引擎的**游戏平台**
- 战策是平台上的**第一个游戏应用**，不是独立的Godot小游戏
- Ember有158个认知子系统、2000+测试，Arboreus有完整世界模拟、1800+测试
- 战策自己实现这些核心能力是重复造轮子，质量和能力都不如引擎SDK
- 长期来看，战策必须依赖SDK才能获得引擎能力的持续升级

---

**本任务是最高优先级，阻塞其他开发。战策下一轮必须先完成本任务。**
**用户已经明确表示不满："感觉他还是在按自己节奏在走"。必须立即整改。**
