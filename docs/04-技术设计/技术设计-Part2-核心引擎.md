# 错题猎手（ErrorHunter）— 技术设计 Part2：核心引擎

```
┌──────────────────────────────────────────────────┐
│                  文档信息                          │
├──────────────┬───────────────────────────────────┤
│ 文档名称      │ 技术设计-Part2-核心引擎             │
│ 所属产品      │ 错题猎手（ErrorHunter）V1.0         │
│ 文档版本      │ V1.0                              │
│ 编写人        │ @Arch（李工）                       │
│ 创建日期      │ 2026-06-17                        │
│ 上游依赖      │ PRD V1.1 + 竞品分析会议纪要          │
│ 状态          │ 待评审                             │
└──────────────┴───────────────────────────────────┘
```

---

## 修订记录

| 版本 | 日期 | 修改内容 | 修改人 |
|------|------|---------|--------|
| V1.0 | 2026-06-17 | 初始版本，覆盖7个核心引擎模块 | @Arch |

---

## 目录

1. [模块1：艾宾浩斯复习调度引擎](#模块1艾宾浩斯复习调度引擎)
2. [模块2：消灭引擎](#模块2消灭引擎)
3. [模块3：OCR服务集成](#模块3ocr服务集成)
4. [模块4：离线同步引擎](#模块4离线同步引擎)
5. [模块5：知识点AI推荐引擎](#模块5知识点ai推荐引擎)
6. [模块6：学情统计引擎](#模块6学情统计引擎)
7. [模块7：通知服务](#模块7通知服务)

---

## 模块1：艾宾浩斯复习调度引擎

> **对应PRD：** FR-400 艾宾浩斯复习调度引擎、FR-401 每日复习流程
> **MVP范围：** 全部纳入MVP

### 1.1 策略模式接口设计

采用策略模式，将调度算法抽象为可插拔接口，便于后续版本替换或A/B测试不同算法。

```go
// review/scheduler/interface.go
package scheduler

import "time"

type ReviewPlan struct {
    QuestionID     int64
    UserID         int64
    CurrentRound   int       // 当前轮次 1-5
    MasterCount    int       // 消灭计数 0-3
    NextReviewDate time.Time
}

type SelfRating string
const (
    RatingMastered SelfRating = "MASTERED"
    RatingPartial  SelfRating = "PARTIAL"
    RatingFailed   SelfRating = "FAILED"
)

// ScheduleStrategy 调度策略接口（策略模式）
// MVP实现EbbinghausStrategy，V1.1可扩展AdaptiveStrategy
type ScheduleStrategy interface {
    Name() string
    CalcNextReview(plan ReviewPlan, rating SelfRating) (nextDate time.Time, newRound int, newMasterCount int)
    IsCompleted(plan ReviewPlan) bool
    GetIntervalDays(round int) int
}
```

### 1.2 基础调度算法（EbbinghausStrategy）

**5轮间隔表：**

| 轮次 | 间隔天数 | 累计距录入天数 |
|------|---------|--------------|
| 1 | 1 | 1 |
| 2 | 2 | 3 |
| 3 | 4 | 7 |
| 4 | 7 | 14 |
| 5 | 16 | 30 |

```go
// review/scheduler/ebbinghaus.go
package scheduler

import "time"

var EbbinghausIntervals = [5]int{1, 2, 4, 7, 16}

type EbbinghausStrategy struct{}

func (s *EbbinghausStrategy) Name() string { return "ebbinghaus" }

func (s *EbbinghausStrategy) GetIntervalDays(round int) int {
    if round < 1 || round > 5 { return 0 }
    return EbbinghausIntervals[round-1]
}

// CalcNextReview 核心调度逻辑（PRD FR-400）
func (s *EbbinghausStrategy) CalcNextReview(
    plan ReviewPlan, rating SelfRating,
) (nextDate time.Time, newRound int, newMasterCount int) {
    now := time.Now()
    today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
    switch rating {
    case RatingMastered:
        newMasterCount = plan.MasterCount + 1
        newRound = plan.CurrentRound + 1
        if newRound > 5 { nextDate = time.Time{} } else {
            nextDate = today.AddDate(0, 0, s.GetIntervalDays(newRound))
        }
    case RatingPartial:
        newMasterCount = plan.MasterCount; newRound = plan.CurrentRound
        nextDate = today.AddDate(0, 0, s.GetIntervalDays(newRound))
    case RatingFailed:
        newMasterCount = 0; newRound = 1
        nextDate = today.AddDate(0, 0, s.GetIntervalDays(1))
    default:
        newMasterCount = plan.MasterCount; newRound = plan.CurrentRound
        nextDate = today.AddDate(0, 0, s.GetIntervalDays(newRound))
    }
    return
}

// IsCompleted 判断是否满足消灭条件（PRD FR-500-2）
func (s *EbbinghausStrategy) IsCompleted(plan ReviewPlan) bool {
    return plan.CurrentRound > 5 && plan.MasterCount >= 3
}
```

### 1.3 master_count 计算逻辑详解

| 自评结果 | master_count变化 | 说明 |
|---------|-----------------|------|
| MASTERED | +1 | >=3即触发消灭 |
| PARTIAL | 不变 | 中断连续计数但不归零 |
| FAILED | 归零 | 重置为0 |

> UI层不展示master_count具体数值（PRD FR-702-3），仅展示复习轮次进度条。

### 1.4 每日上限20道的顺延算法

**规则来源：** PRD FR-400-4

```go
// review/scheduler/daily_limit.go
package scheduler

import "sort"

const DefaultDailyLimit = 20

type ReviewCandidate struct {
    QuestionID     int64
    ReviewRound    int
    IntervalDays   int
    CreatedAt      int64
    NextReviewDate string
}

// ApplyDailyLimit 优先级：轮次高 > 间隔长 > 录入早
func ApplyDailyLimit(candidates []ReviewCandidate, limit int) (today, deferred []ReviewCandidate) {
    sort.Slice(candidates, func(i, j int) bool {
        a, b := candidates[i], candidates[j]
        if a.ReviewRound != b.ReviewRound { return a.ReviewRound > b.ReviewRound }
        if a.IntervalDays != b.IntervalDays { return a.IntervalDays > b.IntervalDays }
        return a.CreatedAt < b.CreatedAt
    })
    if len(candidates) <= limit { return candidates, nil }
    return candidates[:limit], candidates[limit:]
}
```

### 1.5 积压>50道的"大扫除"排序算法

**规则来源：** PRD FR-400-5

```go
// review/scheduler/backlog.go
package scheduler

import "sort"

const BacklogThreshold = 50

type BacklogCandidate struct {
    QuestionID   int64
    MasterCount  int    // 越高越优先（接近消灭的不放弃）
    IntervalDays int    // 越长越优先（逾期久更紧急）
    CreatedAt    int64  // 越早越优先
    ReviewRound  int
}

// SortBacklog 优先级：消灭计数高 > 间隔时间长 > 录入时间早
func SortBacklog(candidates []BacklogCandidate) []BacklogCandidate {
    sort.Slice(candidates, func(i, j int) bool {
        a, b := candidates[i], candidates[j]
        if a.MasterCount != b.MasterCount { return a.MasterCount > b.MasterCount }
        if a.IntervalDays != b.IntervalDays { return a.IntervalDays > b.IntervalDays }
        return a.CreatedAt < b.CreatedAt
    })
    return candidates
}
```

### 1.6 定时任务设计

**触发时间：** 每天凌晨 00:00
**幂等性保证：** Redis SETNX 防重入

```go
// review/cron/daily_scheduler.go
package cron

import ("context"; "fmt"; "log"; "time"; "errorhunter/review/scheduler")

// DailyScheduleJob Cron: 0 0 0 * * *
func DailyScheduleJob(ctx context.Context, svc *SchedulerService) error {
    today := time.Now().Format("2006-01-02")
    idempotentKey := fmt.Sprintf("daily_schedule:%s", today)

    acquired, err := svc.redis.SetNX(ctx, idempotentKey, 1, 25*time.Hour).Result()
    if err != nil { return fmt.Errorf("acquire lock: %w", err) }
    if !acquired { log.Printf("[DailySchedule] skip %s", today); return nil }

    batchSize := 100; lastUserID := int64(0)
    for {
        users, err := svc.userRepo.GetActiveUsersBatch(ctx, lastUserID, batchSize)
        if err != nil { return err }
        if len(users) == 0 { break }
        for _, user := range users {
            if err := svc.scheduleForUser(ctx, user.ID, today); err != nil {
                log.Printf("[DailySchedule] user %d failed: %v", user.ID, err)
            }
        }
        lastUserID = users[len(users)-1].ID
    }
    return nil
}

func (svc *SchedulerService) scheduleForUser(ctx context.Context, userID int64, today string) error {
    candidates, _ := svc.questionRepo.GetDueQuestions(ctx, userID, today)
    limit := svc.getUserDailyLimit(ctx, userID)
    todayList, deferred := scheduler.ApplyDailyLimit(candidates, limit)

    cacheKey := fmt.Sprintf("review_plan:%s:%d", today, userID)
    svc.redis.Set(ctx, cacheKey, todayList, 48*time.Hour)

    totalPending := len(candidates) + svc.getDeferredCount(ctx, userID)
    if totalPending > scheduler.BacklogThreshold {
        sorted := scheduler.SortBacklog(convertToBacklogCandidates(candidates))
        svc.redis.Set(ctx, cacheKey+":backlog", sorted, 48*time.Hour)
    }
    for _, d := range deferred { svc.questionRepo.DeferQuestion(ctx, d.QuestionID, today) }
    return nil
}
```

### 1.7 长期未登录召回

**规则来源：** PRD FR-400-6、FR-402-6、FR-402-7

```go
// review/recall/recall_service.go
package recall

import ("context"; "sort"; "time")

type RecallPackage struct {
    Questions   []RecallQuestion `json:"questions"`
    GeneratedAt time.Time        `json:"generated_at"`
}
type RecallQuestion struct {
    QuestionID  int64  `json:"question_id"`
    MasterCount int    `json:"master_count"`
    ReviewRound int    `json:"review_round"`
    ImageURL    string `json:"image_url"`
}

// GenerateRecallPackage 精选10道master_count最高的题
func GenerateRecallPackage(ctx context.Context, userID int64, repo QuestionRepository) (*RecallPackage, error) {
    questions, err := repo.GetReviewingQuestions(ctx, userID)
    if err != nil { return nil, err }
    sort.Slice(questions, func(i, j int) bool {
        if questions[i].MasterCount != questions[j].MasterCount {
            return questions[i].MasterCount > questions[j].MasterCount
        }
        return questions[i].CreatedAt.Before(questions[j].CreatedAt)
    })
    limit := 10
    if len(questions) < limit { limit = len(questions) }
    pkg := &RecallPackage{Questions: make([]RecallQuestion, limit), GeneratedAt: time.Now()}
    for i := 0; i < limit; i++ {
        pkg.Questions[i] = RecallQuestion{questions[i].ID, questions[i].MasterCount,
            questions[i].ReviewRound, questions[i].ImageURL}
    }
    return pkg, nil
}

// CheckRecallNeeded 3天普通召回，7天强召回+回归复习包
func CheckRecallNeeded(lastActiveAt time.Time) (bool, string) {
    days := int(time.Since(lastActiveAt).Hours() / 24)
    switch {
    case days >= 7: return true, "strong"
    case days >= 3: return true, "normal"
    default: return false, ""
    }
}
```

---

## 模块2：消灭引擎

> **对应PRD：** FR-500 消灭机制、FR-601 消灭动画
> **MVP范围：** 全部纳入MVP（含复活检测降频+永久消灭）

### 2.1 完整状态机设计

```
NOT_STARTED --[首次复习]--> REVIEWING --[master_count>=3]--> MASTERED
                                ^                               |
                                |                               |--[30天通过]--> MASTERED(下次60天)
                                |                               |--[60天通过]--> MASTERED(下次90天)
                                |                               |--[90天通过]--> PERMANENTLY_MASTERED
                                |                               |--[检测失败]--> REVIEWING(count归零)
                                +--[自评任意结果，循环复习]------+
```

### 2.2 状态转换条件表

| 当前状态 | 触发事件 | 目标状态 | 附加动作 | 来源 |
|---------|---------|---------|---------|------|
| NOT_STARTED | 首次复习 | REVIEWING | 记录review_record | FR-500-1 |
| REVIEWING | MASTERED且count<3 | REVIEWING | count+1, 算下次复习日 | FR-500-2a |
| REVIEWING | PARTIAL | REVIEWING | count不变, 重复当前轮次 | FR-500-2b |
| REVIEWING | FAILED | REVIEWING | count归零, 回退第1轮 | FR-500-2c |
| REVIEWING | count>=3 | MASTERED | 播放动画,移出列表,设mastered_at | FR-500-3 |
| MASTERED | 30天检测通过 | MASTERED | 间隔升至60天 | FR-500-4c |
| MASTERED | 60天检测通过 | MASTERED | 间隔升至90天 | FR-500-4d |
| MASTERED | 90天检测通过 | PERMANENTLY_MASTERED | 永久消灭 | FR-500-4e |
| MASTERED | 检测失败 | REVIEWING | count归零,鼓励文案 | FR-500-4f |

### 2.3 消灭触发事件链

```
自评MASTERED且master_count>=3
  -> 1. UPDATE status='MASTERED', mastered_at=NOW()
  -> 2. INSERT review_record
  -> 3. publish("question.mastered") -> 通知服务 -> 里程碑推送
  -> 4. 客户端: 播放消灭动画(FR-601) + 移出复习列表 + 更新Dashboard
  -> 5. DEL review_plan:{date}:{userID} -> 下次请求重新加载
```

### 2.4 复活检测队列管理

**规则来源：** PRD FR-500-4（含竞品分析讨论变更）

```go
// review/extinction/revive_checker.go
package extinction

import ("context"; "fmt"; "time")

var ReviveIntervals = []int{30, 60, 90}

type ReviveCheckStatus string
const (
    ReviveRemembered ReviveCheckStatus = "REMEMBERED"
    ReviveForgotten  ReviveCheckStatus = "FORGOTTEN"
)

type QuestionExtinctionService struct {
    questionRepo QuestionRepository
    redis        RedisClient
    eventBus     EventBus
}

// GetReviveQueue mastered_at最早的优先，每日最多3道
func (s *QuestionExtinctionService) GetReviveQueue(
    ctx context.Context, userID int64, today time.Time,
) ([]ReviveCandidate, error) {
    const dailyReviveLimit = 3
    candidates, err := s.questionRepo.GetReviveCandidates(ctx, userID, today, dailyReviveLimit)
    if err != nil { return nil, fmt.Errorf("get revive candidates: %w", err) }
    result := make([]ReviveCandidate, 0, len(candidates))
    for _, c := range candidates {
        result = append(result, ReviveCandidate{
            QuestionID: c.ID, MasteredAt: c.MasteredAt,
            CurrentInterval: c.ReviveInterval, ImageURL: c.ImageURL,
            OcrText: c.OcrText, IsReviveCheck: true,
        })
    }
    return result, nil
}

func (s *QuestionExtinctionService) ProcessReviveResult(
    ctx context.Context, questionID int64, userID int64, status ReviveCheckStatus,
) error {
    q, err := s.questionRepo.GetByID(ctx, questionID)
    if err != nil { return err }
    switch status {
    case ReviveRemembered:
        nextInterval := getNextReviveInterval(q.ReviveInterval)
        if nextInterval == 0 { return s.markPermanentlyMastered(ctx, q) }
        nextDate := time.Now().AddDate(0, 0, nextInterval)
        return s.questionRepo.UpdateReviveSchedule(ctx, questionID, nextInterval, nextDate)
    case ReviveForgotten:
        return s.reviveFailed(ctx, q)
    }
    return nil
}

// getNextReviveInterval 30->60->90->0(永久消灭)
func getNextReviveInterval(current int) int {
    for i, v := range ReviveIntervals {
        if current == v {
            if i+1 < len(ReviveIntervals) { return ReviveIntervals[i+1] }
            return 0
        }
    }
    return 0
}

func (s *QuestionExtinctionService) markPermanentlyMastered(ctx context.Context, q *Question) error {
    if err := s.questionRepo.UpdateStatus(ctx, q.ID, "PERMANENTLY_MASTERED"); err != nil { return err }
    s.eventBus.Publish(ctx, "question.permanently_mastered", map[string]interface{}{"question_id": q.ID, "user_id": q.UserID})
    return nil
}

func (s *QuestionExtinctionService) reviveFailed(ctx context.Context, q *Question) error {
    if err := s.questionRepo.ReactivateQuestion(ctx, q.ID); err != nil { return err }
    strategy := &scheduler.EbbinghausStrategy{}
    nextDate := time.Now().AddDate(0, 0, strategy.GetIntervalDays(1))
    if err := s.questionRepo.ResetReviewPlan(ctx, q.ID, nextDate); err != nil { return err }
    // 鼓励式文案，不使用"复活"字样（PRD FR-500-4f）
    s.eventBus.Publish(ctx, "question.revive_failed", map[string]interface{}{
        "question_id": q.ID, "user_id": q.UserID, "message": "这道题需要再巩固一下哦！",
    })
    return nil
}
```

### 2.5 Go代码示例：状态机实现

```go
// review/extinction/state_machine.go
package extinction

import "fmt"

type QuestionStatus string
const (
    StatusNotStarted          QuestionStatus = "NOT_STARTED"
    StatusReviewing           QuestionStatus = "REVIEWING"
    StatusMastered            QuestionStatus = "MASTERED"
    StatusPermanentlyMastered QuestionStatus = "PERMANENTLY_MASTERED"
)

type Transition struct {
    From   QuestionStatus
    Event  string
    To     QuestionStatus
    Guard  func(ctx *TransitionContext) bool
    Action func(ctx *TransitionContext) error
}

type TransitionContext struct {
    QuestionID   int64
    UserID       int64
    MasterCount  int
    SelfRating   string
    ReviveResult string
}

type StateMachine struct{ transitions []Transition }

func NewStateMachine() *StateMachine {
    sm := &StateMachine{}
    sm.transitions = []Transition{
        {From: StatusNotStarted, Event: "first_review", To: StatusReviewing,
         Guard: func(ctx *TransitionContext) bool { return true }},
        {From: StatusReviewing, Event: "review_continue", To: StatusReviewing,
         Guard: func(ctx *TransitionContext) bool { return ctx.MasterCount < 3 }},
        {From: StatusReviewing, Event: "master", To: StatusMastered,
         Guard: func(ctx *TransitionContext) bool { return ctx.MasterCount >= 3 }},
        {From: StatusMastered, Event: "permanent_master", To: StatusPermanentlyMastered,
         Guard: func(ctx *TransitionContext) bool { return ctx.ReviveResult == "passed_90d" }},
        {From: StatusMastered, Event: "revive_failed", To: StatusReviewing,
         Guard: func(ctx *TransitionContext) bool { return ctx.ReviveResult == "forgotten" }},
    }
    return sm
}

func (sm *StateMachine) CanTransition(from QuestionStatus, event string, ctx *TransitionContext) bool {
    for _, t := range sm.transitions {
        if t.From == from && t.Event == event && (t.Guard == nil || t.Guard(ctx)) { return true }
    }
    return false
}

func (sm *StateMachine) Transition(from QuestionStatus, event string, ctx *TransitionContext) (QuestionStatus, error) {
    for _, t := range sm.transitions {
        if t.From == from && t.Event == event {
            if t.Guard != nil && !t.Guard(ctx) {
                return from, fmt.Errorf("guard not met: %s->%s", from, event)
            }
            if t.Action != nil {
                if err := t.Action(ctx); err != nil { return from, fmt.Errorf("action failed: %w", err) }
            }
            return t.To, nil
        }
    }
    return from, fmt.Errorf("no transition: %s + %s", from, event)
}
```

---

## 模块3：OCR服务集成

> **对应PRD：** FR-200 拍照录入 -> OCR服务规格
> **MVP范围：** 单源OCR + 去手写评估 + 超时降级

### 3.1 调用流程图

```
用户拍照/选图
  -> 1.智能裁剪(客户端OpenCV/ML Kit) -> 2.图片预处理(服务端EXIF校正+压缩)
  -> 3.去手写处理(5s超时,失败降级保留原图+标注"含手写")
  -> 4.OCR识别(5s超时,失败提示手动输入)
  -> 5.后处理(公式标准化+置信度过滤)
  -> 返回 {image_url, ocr_text, confidence, has_handwriting}
```

### 3.2 去手写处理Pipeline

```go
// ocr/pipeline/handwriting_removal.go
package pipeline

import ("context"; "time")

type HandwritingRemovalResult struct {
    CleanedImageURL    string
    HasHandwriting     bool
    RemovalQuality     float64 // 0-1
    FallbackToOriginal bool
}

func RemoveHandwriting(ctx context.Context, imageURL string, provider OCRProvider) (*HandwritingRemovalResult, error) {
    timeoutCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    result, err := provider.RemoveHandwriting(timeoutCtx, imageURL)
    if err != nil {
        // 去手写失败 -> 降级使用原图
        return &HandwritingRemovalResult{CleanedImageURL: imageURL, HasHandwriting: true, FallbackToOriginal: true}, nil
    }
    if result.Quality < 0.7 {
        result.FallbackToOriginal = true
        result.CleanedImageURL = imageURL
    }
    return result, nil
}
```

### 3.3 超时5秒降级策略

```go
// ocr/service/ocr_service.go
package service

import ("context"; "fmt"; "log"; "time")

const OCRTimeout = 5 * time.Second

type OCRResult struct {
    Text           string  `json:"text"`
    Confidence     float64 `json:"confidence"`
    HasHandwriting bool    `json:"has_handwriting"`
    HasFormula     bool    `json:"has_formula"`
    Degraded       bool    `json:"degraded"`
    DegradeReason  string  `json:"degrade_reason"`
}

func (s *OCRService) Recognize(ctx context.Context, imageURL string) (*OCRResult, error) {
    timeoutCtx, cancel := context.WithTimeout(ctx, OCRTimeout)
    defer cancel()
    resultCh := make(chan *OCRResult, 1)
    errCh := make(chan error, 1)
    go func() {
        r, e := s.provider.Recognize(timeoutCtx, imageURL)
        if e != nil { errCh <- e; return }
        resultCh <- r
    }()
    select {
    case r := <-resultCh: return r, nil
    case e := <-errCh:
        log.Printf("[OCR] failed: %v", e)
        return &OCRResult{Degraded: true, DegradeReason: fmt.Sprintf("识别失败: %v", e)}, nil
    case <-timeoutCtx.Done():
        log.Printf("[OCR] timeout %v", OCRTimeout)
        return &OCRResult{Degraded: true, DegradeReason: "识别超时，请手动输入题目内容"}, nil
    }
}
```

### 3.4 数学公式识别特殊处理

```go
// ocr/formula/formula_detector.go
package formula

import ("regexp"; "strings")

var FormulaPatterns = []*regexp.Regexp{
    regexp.MustCompile(`[+\-*\/=<>]+\s*\d`),
    regexp.MustCompile(`\frac\{.*?\}\{.*?\}`),
    regexp.MustCompile(`[xyz]\s*[+\-*/^]\s*\d`),
}

func DetectFormula(text string) bool {
    for _, p := range FormulaPatterns { if p.MatchString(text) { return true } }
    return false
}

func NormalizeFormula(rawText string) string {
    repl := map[string]string{"÷":"\div","×":"\times","√":"\sqrt","π":"\pi","≤":"\leq","≥":"\geq","≠":"\neq","≈":"\approx"}
    r := rawText
    for o, n := range repl { r = strings.ReplaceAll(r, o, n) }
    return r
}
```

### 3.5 百度OCR vs 腾讯OCR选型对比表

| 评估维度 | 百度OCR（高精度版） | 腾讯OCR（通用印刷体） | 权重 | 备注 |
|---------|------------------|--------------------|------|------|
| 印刷体准确率 | >=99% | >=98.5% | 30% | 需实测教育场景 |
| 去手写能力 | 教育场景专项优化 | 有但案例少 | 25% | **关键指标** |
| 数学公式识别 | LaTeX输出 | LaTeX输出 | 15% | 均支持 |
| 单次价格 | 0.005元/次 | 0.004元/次 | 10% | 均有免费额度 |
| 免费额度 | 1000次/月 | 1000次/月 | 5% | MVP够用 |
| SLA | 99.95% | 99.95% | 5% | 持平 |
| P99延迟 | ~800ms | ~600ms | 5% | 腾讯略快 |
| 教育行业案例 | 作业帮/猿辅导等 | 较少公开案例 | 5% | 百度生态更强 |

**MVP建议：百度OCR**（去手写验证充分+教育案例丰富）。V1.1加腾讯备用源。

---

## 模块4：离线同步引擎

> **对应PRD：** GR-002 离线与同步规则（单向上传）
> **MVP范围：** 单向上传 + 指数退避重试
> **本模块主要在Flutter客户端实现，以下为服务端接口设计+客户端架构说明**

### 4.1 客户端SQLite表结构设计

```sql
-- 本地错题表
CREATE TABLE local_questions (
    local_id TEXT PRIMARY KEY, user_id INTEGER NOT NULL,
    image_local_path TEXT NOT NULL, ocr_text TEXT,
    my_answer TEXT, correct_answer TEXT, solution_steps TEXT,
    error_category TEXT NOT NULL, error_sub_category TEXT,
    custom_tags TEXT, knowledge_point_ids TEXT,
    created_at DATETIME NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING/UPLOADING/SYNCED/FAILED
    server_id INTEGER, retry_count INTEGER DEFAULT 0,
    last_error TEXT, updated_at DATETIME NOT NULL
);

-- 本地图片表
CREATE TABLE local_images (
    local_id TEXT PRIMARY KEY, local_path TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    upload_status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING/UPLOADING/UPLOADED/FAILED
    oss_url TEXT, retry_count INTEGER DEFAULT 0,
    created_at DATETIME NOT NULL
);

-- 同步队列表
CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    local_question_id TEXT NOT NULL,
    operation TEXT NOT NULL DEFAULT 'CREATE', -- CREATE/UPDATE/DELETE
    priority INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'PENDING', -- PENDING/PROCESSING/DONE/FAILED
    retry_count INTEGER DEFAULT 0,
    created_at DATETIME NOT NULL, processed_at DATETIME,
    FOREIGN KEY (local_question_id) REFERENCES local_questions(local_id)
);
CREATE INDEX idx_sync_queue_status ON sync_queue(status, priority DESC);
CREATE INDEX idx_local_questions_sync ON local_questions(sync_status);
```

### 4.2 两阶段提交流程

```
Phase 1: 上传图片 -> PENDING->UPLOADING->UPLOADED(获取OSS URL)
Phase 2: 提交数据 -> PENDING->UPLOADING->SYNCED(完成)
失败: retry<3 -> 指数退避(1s->2s->4s); retry>=3 -> FAILED(用户手动重试)
```

### 4.3 重试策略

```go
// sync/retry_policy.go
package sync

import ("math"; "time")

const (MaxRetryCount = 3; BaseDelay = 1 * time.Second)

// CalcRetryDelay 指数退避: 1s -> 2s -> 4s
func CalcRetryDelay(retryCount int) time.Duration {
    if retryCount >= MaxRetryCount { return 0 }
    return BaseDelay * time.Duration(math.Pow(2, float64(retryCount)))
}
func ShouldRetry(retryCount int) bool { return retryCount < MaxRetryCount }
```

### 4.4 服务端接收接口设计

```go
// api/handler/question_sync.go
package handler

import ("net/http"; "github.com/gin-gonic/gin")

type SyncQuestionRequest struct {
    LocalID           string   `json:"local_id" binding:"required"`
    ImageURL          string   `json:"image_url" binding:"required"`
    ErrorCategory     string   `json:"error_category" binding:"required"`
    KnowledgePointIDs []int    `json:"knowledge_point_ids" binding:"required,min=1,max=3"`
    CreatedAt         string   `json:"created_at" binding:"required"`
    OcrText           string   `json:"ocr_text"`
    MyAnswer          string   `json:"my_answer"`
    CorrectAnswer     string   `json:"correct_answer"`
    SolutionSteps     []string `json:"solution_steps"`
    ErrorSubCategory  string   `json:"error_sub_category"`
    CustomTags        []string `json:"custom_tags"`
}

type SyncQuestionResponse struct {
    ServerID int64  `json:"server_id"`
    LocalID  string `json:"local_id"`
}

// POST /api/v1/questions/sync
// 幂等性：相同local_id + user_id只创建一次
func (h *QuestionHandler) SyncQuestion(c *gin.Context) {
    userID := c.GetInt64("user_id")
    var req SyncQuestionRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()}); return
    }
    existing, _ := h.questionSvc.GetByLocalID(c.Request.Context(), userID, req.LocalID)
    if existing != nil {
        c.JSON(http.StatusOK, SyncQuestionResponse{ServerID: existing.ID, LocalID: req.LocalID}); return
    }
    question, err := h.questionSvc.CreateFromSync(c.Request.Context(), userID, req)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()}); return
    }
    c.JSON(http.StatusCreated, SyncQuestionResponse{ServerID: question.ID, LocalID: req.LocalID})
}

// POST /api/v1/images/upload (Phase 1)
func (h *ImageHandler) UploadImage(c *gin.Context) {
    userID := c.GetInt64("user_id")
    file, header, err := c.Request.FormFile("image")
    if err != nil { c.JSON(http.StatusBadRequest, gin.H{"error": "invalid image"}); return }
    defer file.Close()
    if header.Size > 20*1024*1024 {
        c.JSON(http.StatusBadRequest, gin.H{"error": "max 20MB"}); return
    }
    ossURL, err := h.imageSvc.UploadToOSS(c.Request.Context(), userID, file, header.Filename)
    if err != nil { c.JSON(http.StatusInternalServerError, gin.H{"error": "upload failed"}); return }
    c.JSON(http.StatusOK, gin.H{"image_url": ossURL})
}
```

---

## 模块5：知识点AI推荐引擎

> **对应PRD：** FR-301 知识点关联 -> AI推荐规则
> **MVP范围：** 关键词匹配算法（非大模型）

### 5.1 关键词匹配算法详细实现

```
INPUT: 题目文字text + 用户年级grade
OUTPUT: 推荐知识点列表（最多3个，score>0.3）

Step 1: 预处理 - 去数字标点, 全角转半角, trim
Step 2: 中文分词 - gojieba提取名词(n)/动词(v)/数词(m), 去停用词
Step 3: 知识点匹配 - Redis缓存知识点树(含keywords字段), 按学段(PRIMARY/JUNIOR)过滤
Step 4: 分数计算 - score = hit_keywords_count / total_keywords_count
Step 5: 排序取TOP3 - score > 0.3才推荐, 标记"AI推荐"
```

### 5.2 Go代码实现

```go
// knowledge/recommender/keyword_matcher.go
package recommender

import ("context"; "sort"; "strings"; "github.com/yanyiwu/gojieba")

type KnowledgePointWithKeywords struct {
    ID       int      `json:"id"`
    Name     string   `json:"name"`
    Stage    string   `json:"stage"`    // PRIMARY / JUNIOR
    Keywords []string `json:"keywords"`
}

type RecommendResult struct {
    KnowledgePointID int     `json:"knowledge_point_id"`
    Name             string  `json:"name"`
    Score            float64 `json:"score"`
    IsAIRecommended  bool    `json:"is_ai_recommended"`
}

type KeywordMatcher struct {
    jieba     *gojieba.Jieba
    cache     KnowledgeCache
    stopWords map[string]bool
}

func NewKeywordMatcher(cache KnowledgeCache) *KeywordMatcher {
    return &KeywordMatcher{jieba: gojieba.NewJieba(), cache: cache, stopWords: loadStopWords()}
}

func (m *KeywordMatcher) Recommend(ctx context.Context, text string, stage string, topN int) ([]RecommendResult, error) {
    words := m.extractKeywords(preprocess(text))
    kps, err := m.cache.GetKnowledgePoints(ctx, stage)
    if err != nil { return nil, err }
    var results []RecommendResult
    for _, kp := range kps {
        score := m.calcMatchScore(words, kp.Keywords)
        if score > 0.3 {
            results = append(results, RecommendResult{kp.ID, kp.Name, score, true})
        }
    }
    sort.Slice(results, func(i, j int) bool { return results[i].Score > results[j].Score })
    if len(results) > topN { results = results[:topN] }
    return results, nil
}

func (m *KeywordMatcher) extractKeywords(text string) []string {
    tags := m.jieba.Tag(text)
    var kw []string
    for _, tag := range tags {
        if isContentWord(tag.Pos) && !m.stopWords[tag.Word] && len(tag.Word) >= 2 {
            kw = append(kw, tag.Word)
        }
    }
    return kw
}

// calcMatchScore: score = 命中关键词数 / 知识点总关键词数
func (m *KeywordMatcher) calcMatchScore(textWords, kpKeywords []string) float64 {
    if len(kpKeywords) == 0 { return 0 }
    ws := make(map[string]bool, len(textWords))
    for _, w := range textWords { ws[w] = true }
    hits := 0
    for _, kw := range kpKeywords {
        if ws[kw] { hits++; continue }
        for tw := range ws {
            if strings.Contains(tw, kw) || strings.Contains(kw, tw) { hits++; break }
        }
    }
    return float64(hits) / float64(len(kpKeywords))
}

func isContentWord(pos string) bool {
    m := map[string]bool{"n":true,"nr":true,"ns":true,"nt":true,"v":true,"vn":true,"m":true,"nz":true}
    return m[pos]
}

func preprocess(text string) string {
    text = removeDigits(text)
    text = fullWidthToHalfWidth(text)
    return strings.TrimSpace(text)
}
```

### 5.3 知识点树查询优化

```go
// knowledge/cache/knowledge_cache.go
package cache

import ("context"; "encoding/json"; "fmt"; "time")

const KnowledgeTreeCacheKey = "knowledge_tree:%s" // %s = PRIMARY/JUNIOR
const KnowledgeTreeTTL = 24 * time.Hour

type KnowledgeCache interface {
    GetKnowledgePoints(ctx context.Context, stage string) ([]KnowledgePointWithKeywords, error)
    Invalidate(ctx context.Context, stage string) error
}

type RedisKnowledgeCache struct { redis RedisClient; db KnowledgePointRepository }

func (c *RedisKnowledgeCache) GetKnowledgePoints(ctx context.Context, stage string) ([]KnowledgePointWithKeywords, error) {
    key := fmt.Sprintf(KnowledgeTreeCacheKey, stage)
    if cached, err := c.redis.Get(ctx, key).Result(); err == nil && cached != "" {
        var pts []KnowledgePointWithKeywords
        if json.Unmarshal([]byte(cached), &pts) == nil { return pts, nil }
    }
    pts, err := c.db.GetByStage(ctx, stage)
    if err != nil { return nil, err }
    data, _ := json.Marshal(pts)
    c.redis.Set(ctx, key, string(data), KnowledgeTreeTTL)
    return pts, nil
}

func (c *RedisKnowledgeCache) Invalidate(ctx context.Context, stage string) error {
    return c.redis.Del(ctx, fmt.Sprintf(KnowledgeTreeCacheKey, stage)).Err()
}
```

### 5.4 推荐结果缓存策略

| 缓存项 | Key格式 | TTL | 失效条件 | 说明 |
|-------|---------|-----|---------|------|
| 知识点树 | `knowledge_tree:{stage}` | 24h | 数据更新时主动失效 | 整棵树~5KB |
| 推荐结果 | `kp_recommend:{md5(text)}:{stage}` | 1h | 自然过期 | 相同题目复用 |

---

## 模块6：学情统计引擎

> **对应PRD：** FR-600 首页Dashboard、FR-602 学情周报
> **MVP范围：** 全部纳入MVP

### 6.1 每日凌晨离线计算SQL（00:05执行，避开00:00复习调度）

```sql
INSERT INTO dashboard_daily_stats (
    user_id, stat_date, total_questions, mastered_questions,
    mastering_rate, streak_days, error_distribution
)
SELECT u.id, CURRENT_DATE,
    COUNT(CASE WHEN q.deleted_at IS NULL THEN 1 END),
    COUNT(CASE WHEN q.status IN ('MASTERED','PERMANENTLY_MASTERED') AND q.deleted_at IS NULL THEN 1 END),
    ROUND(
        COUNT(CASE WHEN q.status IN ('MASTERED','PERMANENTLY_MASTERED') AND q.deleted_at IS NULL THEN 1 END)::numeric
        / NULLIF(COUNT(CASE WHEN q.deleted_at IS NULL THEN 1 END), 0) * 100, 2),
    u.streak_days,
    json_build_object(
        'KNOWLEDGE', COUNT(CASE WHEN q.error_category='KNOWLEDGE' AND q.deleted_at IS NULL THEN 1 END),
        'SKILL',     COUNT(CASE WHEN q.error_category='SKILL' AND q.deleted_at IS NULL THEN 1 END),
        'PSYCHOLOGY',COUNT(CASE WHEN q.error_category='PSYCHOLOGY' AND q.deleted_at IS NULL THEN 1 END),
        'HABIT',     COUNT(CASE WHEN q.error_category='HABIT' AND q.deleted_at IS NULL THEN 1 END)
    )
FROM users u LEFT JOIN questions q ON q.user_id = u.id
WHERE u.deleted_at IS NULL
GROUP BY u.id, u.streak_days
ON CONFLICT (user_id, stat_date) DO UPDATE SET
    total_questions = EXCLUDED.total_questions,
    mastered_questions = EXCLUDED.mastered_questions,
    mastering_rate = EXCLUDED.mastering_rate,
    streak_days = EXCLUDED.streak_days,
    error_distribution = EXCLUDED.error_distribution;
```

### 6.2 实时查询实现（今日待复习数走Redis缓存）

```go
// stats/dashboard_service.go
package stats

import ("context"; "encoding/json"; "fmt"; "time")

type DashboardData struct {
    Nickname          string         `json:"nickname"`
    StreakDays        int            `json:"streak_days"`
    TodayPendingCount int            `json:"today_pending_count"` // 实时
    TotalQuestions    int            `json:"total_questions"`
    MasteredQuestions int            `json:"mastered_questions"`
    MasteringRate     float64        `json:"mastering_rate"`
    ErrorDistribution map[string]int `json:"error_distribution"`
    WeekTrend         []DailyTrend   `json:"week_trend"`
    WeakKnowledgeTop  []WeakKP       `json:"weak_knowledge_top"`
}

func (s *DashboardService) GetDashboard(ctx context.Context, userID int64) (*DashboardData, error) {
    today := time.Now().Format("2006-01-02")

    // 1. 今日待复习数 -> 实时Redis LLen
    pendingKey := fmt.Sprintf("review_plan:%s:%d", today, userID)
    pendingCount, _ := s.redis.LLen(ctx, pendingKey).Result()

    // 2. 其余统计数据 -> Redis缓存(TTL 6h)
    statsKey := fmt.Sprintf("dashboard_stats:%s:%d", today, userID)
    if cached, err := s.redis.Get(ctx, statsKey).Result(); err == nil {
        var data DashboardData
        if json.Unmarshal([]byte(cached), &data) == nil {
            data.TodayPendingCount = int(pendingCount)
            return &data, nil
        }
    }

    // 3. Redis miss -> DB预计算表（兜底查昨日）
    stats, err := s.statsRepo.GetDailyStats(ctx, userID, today)
    if err != nil {
        yesterday := time.Now().AddDate(0, 0, -1).Format("2006-01-02")
        stats, err = s.statsRepo.GetDailyStats(ctx, userID, yesterday)
        if err != nil { return nil, err }
    }

    data := convertToDashboardData(stats)
    data.TodayPendingCount = int(pendingCount)
    jsonData, _ := json.Marshal(data)
    s.redis.Set(ctx, statsKey, string(jsonData), 6*time.Hour)
    return &data, nil
}
```

### 6.3 周报生成算法（每周日20:00定时任务）

```go
// stats/weekly_report_generator.go
package stats

import ("context"; "time")

type WeeklyReportData struct {
    WeekNumber        int       `json:"week_number"` // 如202624
    WeekStart         time.Time `json:"week_start"`
    WeekEnd           time.Time `json:"week_end"`
    NewQuestions      int       `json:"new_questions"`
    MasteredQuestions int       `json:"mastered_questions"`
    ReviewCount       int       `json:"review_count"`
    ReviewAccuracy    float64   `json:"review_accuracy"`
    PrevWeekNew       int       `json:"prev_week_new"`
    PrevWeekMastered  int       `json:"prev_week_mastered"`
    TopErrorCategory  string    `json:"top_error_category"`
    WeakKnowledgeTop  []WeakKP  `json:"weak_knowledge_top"`
}

func (g *ReportGenerator) GenerateWeeklyReport(ctx context.Context, userID int64, weekStart time.Time) (*WeeklyReportData, error) {
    weekEnd := weekStart.AddDate(0, 0, 6)
    prevStart := weekStart.AddDate(0, 0, -7)
    prevEnd := weekStart.AddDate(0, 0, -1)

    newQ, _ := g.questionRepo.CountByDateRange(ctx, userID, weekStart, weekEnd)
    mastered, _ := g.questionRepo.CountMasteredByDateRange(ctx, userID, weekStart, weekEnd)
    reviewStats, _ := g.reviewRepo.GetStatsByDateRange(ctx, userID, weekStart, weekEnd)
    prevNew, _ := g.questionRepo.CountByDateRange(ctx, userID, prevStart, prevEnd)
    prevMastered, _ := g.questionRepo.CountMasteredByDateRange(ctx, userID, prevStart, prevEnd)
    topCat, _ := g.questionRepo.GetTopErrorCategory(ctx, userID, weekStart, weekEnd)
    weakKPs, _ := g.getWeakKnowledgeTop(ctx, userID, weekEnd)

    year, weekNum := weekStart.ISOWeek()
    report := &WeeklyReportData{
        WeekNumber: year*100+weekNum, WeekStart: weekStart, WeekEnd: weekEnd,
        NewQuestions: newQ, MasteredQuestions: mastered,
        ReviewCount: reviewStats.TotalReviews, ReviewAccuracy: reviewStats.Accuracy,
        PrevWeekNew: prevNew, PrevWeekMastered: prevMastered,
        TopErrorCategory: topCat, WeakKnowledgeTop: weakKPs,
    }
    g.reportRepo.Save(ctx, userID, report)
    return report, nil
}
```

### 6.4 错因分布统计（排除UNKNOWN枚举值）

```sql
-- PRD FR-300-9: "不确定"不纳入错因分布饼图
SELECT error_category, COUNT(*) as count,
    ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER() * 100, 1) as percentage
FROM questions
WHERE user_id = $1 AND deleted_at IS NULL AND error_category != 'UNKNOWN'
GROUP BY error_category ORDER BY count DESC;
```

### 6.5 薄弱知识点TOP排行SQL

```sql
-- PRD FR-600-11: 按知识点分组，未消灭错题数降序
SELECT kp.id, kp.name, COUNT(q.id) AS unmastered_count
FROM question_knowledge qk
JOIN knowledge_points kp ON kp.id = qk.knowledge_point_id
JOIN questions q ON q.id = qk.question_id
WHERE q.user_id = $1 AND q.deleted_at IS NULL
  AND q.status NOT IN ('MASTERED', 'PERMANENTLY_MASTERED')
GROUP BY kp.id, kp.name ORDER BY unmastered_count DESC LIMIT 3;
```

### 6.6 Dashboard数据缓存策略

| 数据项 | 缓存位置 | TTL | 更新时机 |
|-------|---------|-----|---------|
| 今日待复习数 | Redis List | 实时 | 每日00:00调度写入 |
| 累计统计/错因/薄弱KP | Redis String | 6h | 每日00:05预计算 |
| 本周趋势 | Redis String | 1h | 复习后增量更新 |
| 打卡天数 | Redis String | 1h | 复习完成后更新 |
| 周报 | Redis String | 7d | 每周日20:00生成 |

> **性能保障：** Dashboard API P99 < 500ms。最差情况1次DB预计算表查+1次Redis LLEN < 100ms。

---

## 模块7：通知服务

> **对应PRD：** FR-402 复习提醒推送
> **MVP范围：** 基础推送 + 免打扰 + 召回提醒

### 7.1 推送消息类型及模板

| 消息类型 | 触发条件 | 标题 | 内容模板 | 优先级 | MVP |
|---------|---------|------|---------|-------|-----|
| 每日复习提醒 | 每天定时+有待复习题 | 复习时间到！ | 你今天有{count}道错题等你复习哦！坚持就是胜利 | normal | Y |
| 召回(3天) | 3天未打开APP | 好久不见 | 你已经3天没来复习了，错题们在想你呢~ | normal | Y |
| 强召回(7天) | 7天未打开APP | 别放弃！ | 你已经一周没复习了，为你准备了回归复习包 | high | Y |
| 消灭里程碑 | 消灭达10/50/100 | 太厉害了！ | 恭喜消灭第{count}道错题！继续保持！ | normal | Y |
| 打卡里程碑 | 打卡达7/30/100天 | 打卡达人！ | 连续打卡{days}天了，自律的你最棒！ | normal | Y |
| 周报生成 | 每周日20:00 | 本周学情报告 | 你的本周学习报告已生成，快来看看吧！ | low | Y |
| 存储预警 | 存储>90% | 空间不足 | 存储空间已使用{percent}%，请及时清理 | high | Y |

### 7.2 定时推送调度

```go
// notification/scheduler/push_scheduler.go
package scheduler

import ("context"; "fmt"; "time")

type PushConfig struct {
    UserID          int64
    ReminderEnabled bool
    ReminderTime    string // "19:00"
    DeviceTokens    []DeviceToken
    LastActiveAt    time.Time
}

type DeviceToken struct {
    Token    string `json:"token"`
    Platform string `json:"platform"` // "ios"/"android"
}

func (s *PushScheduler) ScheduleDailyReminders(ctx context.Context) error {
    now := time.Now()
    currentTimeSlot := fmt.Sprintf("%02d:%02d", now.Hour(), (now.Minute()/30)*30)

    // 免打扰: 22:00-08:00不推送（PRD FR-402-9）
    if isQuietHours(now) { return nil }

    configs, err := s.configRepo.GetUsersByReminderTime(ctx, currentTimeSlot)
    if err != nil { return err }

    for _, config := range configs {
        if !config.ReminderEnabled { continue }
        pendingCount, _ := s.getTodayPendingCount(ctx, config.UserID)
        if pendingCount == 0 { continue } // PRD FR-402-5: 无待复习不推送

        msg := PushMessage{
            Type: PushTypeDailyReminder, Title: "复习时间到！",
            Body: fmt.Sprintf("你今天有%d道错题等你复习哦！坚持就是胜利", pendingCount),
            Priority: PriorityNormal,
            Extra: map[string]string{"action": "open_review"},
        }
        for _, device := range config.DeviceTokens {
            s.pushService.Send(ctx, device, msg)
        }
    }
    return nil
}

func isQuietHours(t time.Time) bool { h := t.Hour(); return h >= 22 || h < 8 }
```

### 7.3 iOS APNs vs Android推送差异处理

```go
// notification/push/platform_adapter.go
package push

type PlatformAdapter interface {
    Send(ctx context.Context, token string, msg PushMessage) error
    ValidateToken(token string) bool
}

// APNsAdapter iOS推送适配器
type APNsAdapter struct{ client *apns.Client }
func (a *APNsAdapter) Send(ctx context.Context, token string, msg PushMessage) error {
    payload := apns.NewPayload()
    payload.Alert.Title = msg.Title
    payload.Alert.Body = msg.Body
    payload.Sound = "default"
    payload.Custom = msg.Extra
    payload.Badge = getBadgeCount(msg.UserID)      // iOS角标
    payload.ContentAvailable = 1                    // 静默唤醒
    if msg.Priority == PriorityHigh {
        payload.Priority = apns.PriorityHigh        // 10
    } else {
        payload.Priority = apns.PriorityNormal      // 5
    }
    _, err := a.client.PushWithContext(ctx, &apns.Notification{
        DeviceToken: token, Topic: "com.errorhunter.app", Payload: payload,
    })
    return err
}

// FCMAdapter Android推送（通过极光/个推网关）
type FCMAdapter struct{ provider PushProvider }
func (f *FCMAdapter) Send(ctx context.Context, token string, msg PushMessage) error {
    return f.provider.SendNotification(ctx, ProviderNotification{
        Token: token, Title: msg.Title, Body: msg.Body,
        Extra: msg.Extra, Channel: "review_reminder", Priority: msg.Priority,
    })
}
```

### 7.4 推送服务商选型对比

| 评估维度 | 极光推送（JPush） | 个推（GeTui） | 权重 | 备注 |
|---------|-----------------|-------------|------|------|
| 到达率 | 95%+（Android） | 93%+（Android） | 30% | 极光厂商通道更全 |
| iOS推送 | APNs直连稳定 | APNs直连稳定 | 15% | 持平 |
| 免费额度 | 不限次数 | 不限次数 | 10% | MVP均够用 |
| 付费价格 | 200元/月起 | 150元/月起 | 10% | 个推略便宜 |
| SDK体积 | ~2MB | ~1.5MB | 5% | 个推更轻 |
| 国内厂商通道 | 华为/小米/OPPO/vivo/魅族 | 华为/小米/OPPO/vivo | 15% | 极光多魅族 |
| Flutter插件 | jpush_flutter官方维护 | getui_flutter官方维护 | 5% | 均有 |
| 文档社区 | 优秀 | 良好 | 5% | 极光中文文档更好 |
| 数据统计面板 | 完善 | 完善 | 5% | 持平 |

**MVP建议：极光推送**（到达率高+Flutter插件活跃+文档丰富）。V1.1评估双源热备。

---

## 附录A：MVP vs V1.1 功能矩阵

| 模块 | 功能点 | MVP | V1.1 | 备注 |
|------|-------|-----|------|------|
| 复习调度 | 艾宾浩斯5轮算法 | Y | - | - |
| 复习调度 | 自适应算法+A/B测试 | - | Y | 根据正确率动态调整 |
| 消灭引擎 | 4状态+复活降频 | Y | - | 竞品讨论确认 |
| OCR | 单源百度 | Y | - | - |
| OCR | 双源主备+手写体 | - | Y | 加腾讯备用 |
| 离线同步 | 单向上传 | Y | - | - |
| 离线同步 | 双向同步+冲突解决 | - | Y | 多设备支持 |
| 知识点推荐 | 关键词匹配 | Y | - | - |
| 知识点推荐 | 大模型语义理解 | - | Y | GPT/文心一言 |
| 学情统计 | 预计算+实时混合 | Y | - | - |
| 学情统计 | 多维度交叉分析 | - | Y | 按学科/题型/时段 |
| 通知 | 基础推送+召回 | Y | - | - |
| 通知 | 微信模板消息 | - | V2.0 | 小程序家长端配套 |

## 附录B：关键配置项

| 配置项 | 默认值 | 可调范围 | 配置位置 | 说明 |
|-------|-------|---------|---------|------|
| 每日复习上限 | 20 | 10-30 | 用户设置 | PRD FR-800-2 |
| 复习提醒时间 | 19:00 | 18:00-22:00 | 用户设置 | 半小时粒度 |
| OCR超时 | 5s | 固定 | 服务端 | PRD FR-200 |
| 复活检测每日上限 | 3 | 固定 | 服务端 | PRD FR-500-4a |
| 积压阈值 | 50 | 固定 | 服务端 | PRD FR-400-5 |
| 同步重试次数 | 3 | 固定 | 客户端 | PRD GR-002-5 |
| Dashboard缓存TTL | 6h | 固定 | 服务端 | 平衡实时性与性能 |
| 知识点树缓存TTL | 24h | 固定 | 服务端 | 数据变更频率低 |
| 推荐分数阈值 | 0.3 | 0.2-0.5 | 服务端 | 过低会推荐不准 |

---

**文档签署：**

| 角色 | 姓名 | 日期 | 状态 |
|------|------|------|------|
| 架构师 | 李工 | 2026-06-17 | 已编写 |
| 开发负责人 | 王码 | - | 待评审 |
| 测试负责人 | 赵测 | - | 待评审 |
| 运维负责人 | 陈运 | - | 待评审 |
| 产品负责人 | 张明 | - | 待评审 |
