package model

import (
	"encoding/json"
	"time"

	"gorm.io/gorm"
)

// Grade 年级枚举
type Grade string

const (
	Grade31 Grade = "31" // 小学三年级
	Grade32 Grade = "32" // 小学四年级
	Grade33 Grade = "33" // 小学五年级
	Grade34 Grade = "34" // 小学六年级
	Grade71 Grade = "71" // 初中一年级
	Grade72 Grade = "72" // 初中二年级
	Grade73 Grade = "73" // 初中三年级
)

func (g Grade) Stage() Stage {
	switch g {
	case Grade31, Grade32, Grade33, Grade34:
		return StagePrimary
	case Grade71, Grade72, Grade73:
		return StageJunior
	default:
		return StagePrimary
	}
}

// QuestionStatus 错题状态枚举
type QuestionStatus string

const (
	StatusNotStarted          QuestionStatus = "NOT_STARTED"
	StatusReviewing           QuestionStatus = "REVIEWING"
	StatusMastered            QuestionStatus = "MASTERED"
	StatusPermanentlyMastered QuestionStatus = "PERMANENTLY_MASTERED"
)

// ErrorCategory 错因粗分类枚举
type ErrorCategory string

const (
	ErrorKnowledge  ErrorCategory = "KNOWLEDGE"
	ErrorSkill      ErrorCategory = "SKILL"
	ErrorPsychology ErrorCategory = "PSYCHOLOGY"
	ErrorHabit      ErrorCategory = "HABIT"
	ErrorUnknown    ErrorCategory = "UNKNOWN"
)

// SelfRating 自评结果枚举
type SelfRating string

const (
	RatingMastered SelfRating = "MASTERED"
	RatingPartial  SelfRating = "PARTIAL"
	RatingFailed   SelfRating = "FAILED"
)

// Stage 学段枚举
type Stage string

const (
	StagePrimary Stage = "PRIMARY"
	StageJunior  Stage = "JUNIOR"
)

// SyncOperation 同步操作类型
type SyncOperation string

const (
	SyncCreate SyncOperation = "CREATE"
	SyncUpdate SyncOperation = "UPDATE"
	SyncDelete SyncOperation = "DELETE"
)

// SyncStatus 同步状态
type SyncStatus string

const (
	SyncPending   SyncStatus = "PENDING"
	SyncUploading SyncStatus = "UPLOADING"
	SyncSuccess   SyncStatus = "SUCCESS"
	SyncFailed    SyncStatus = "FAILED"
)

// DeviceType 设备类型
type DeviceType string

const (
	DeviceIOS     DeviceType = "IOS"
	DeviceAndroid DeviceType = "ANDROID"
)

// User 用户表
type User struct {
	ID                 int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	Phone              string     `gorm:"type:varchar(11);uniqueIndex;not null" json:"-"`
	Nickname           *string    `gorm:"type:varchar(24)" json:"nickname"`
	AvatarURL          *string    `gorm:"type:varchar(512)" json:"avatar_url"`
	Grade              Grade      `gorm:"type:grade_enum;not null" json:"grade"`
	StorageUsed        int64      `gorm:"not null;default:0" json:"storage_used"`
	StorageLimit       int64      `gorm:"not null;default:5368709120" json:"storage_limit"`
	StreakDays         int        `gorm:"not null;default:0" json:"streak_days"`
	ReviewReminderTime string     `gorm:"type:time;not null;default:'19:00:00'" json:"review_reminder_time"`
	ReminderEnabled    bool       `gorm:"not null;default:true" json:"reminder_enabled"`
	MasteredAnimation  bool       `gorm:"not null;default:true" json:"mastered_animation"`
	DailyReviewLimit   int        `gorm:"not null;default:20" json:"daily_review_limit"`
	LastActiveAt       *time.Time `json:"last_active_at,omitempty"`
	LastReviewDate     *time.Time `gorm:"type:date" json:"last_review_date,omitempty"`
	CreatedAt          time.Time  `gorm:"not null;default:now()" json:"created_at"`
	UpdatedAt          time.Time  `gorm:"not null;default:now()" json:"updated_at"`
	DeletedAt          *time.Time `gorm:"index" json:"deleted_at,omitempty"`
}

func (User) TableName() string { return "users" }

// MaskPhone 返回脱敏手机号
func (u *User) MaskPhone() string {
	if len(u.Phone) != 11 {
		return u.Phone
	}
	return u.Phone[:3] + "****" + u.Phone[7:]
}

// Question 错题表
type Question struct {
	ID                    int64           `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID                int64           `gorm:"not null;index" json:"user_id"`
	Status                QuestionStatus  `gorm:"type:question_status_enum;not null;default:'NOT_STARTED'" json:"status"`
	ImageURL              string          `gorm:"type:varchar(512);not null" json:"image_url"`
	OcrText               *string         `gorm:"type:text" json:"ocr_text,omitempty"`
	OcrConfirmed          bool            `gorm:"not null;default:false" json:"ocr_confirmed"`
	MyAnswer              *string         `gorm:"type:text" json:"my_answer,omitempty"`
	CorrectAnswer         *string         `gorm:"type:text" json:"correct_answer,omitempty"`
	SolutionSteps         JSONB           `gorm:"type:jsonb" json:"solution_steps,omitempty"`
	ErrorStepIndex        *int            `json:"error_step_index,omitempty"`
	ErrorCategory         ErrorCategory   `gorm:"type:error_category_enum;not null" json:"error_category"`
	SubCategories         JSONB           `gorm:"type:jsonb" json:"sub_categories,omitempty"`
	CustomTags            JSONB           `gorm:"type:jsonb" json:"custom_tags,omitempty"`
	MasterCount           int             `gorm:"not null;default:0" json:"master_count"`
	ReviewRound           int             `gorm:"not null;default:1" json:"review_round"`
	NextReviewDate        time.Time       `gorm:"type:date;not null" json:"next_review_date"`
	MasteredAt            *time.Time      `json:"mastered_at,omitempty"`
	ReviveCheckDate       *time.Time      `gorm:"type:date" json:"revive_check_date,omitempty"`
	ReviveCheckInterval   *int            `gorm:"default:30" json:"revive_check_interval,omitempty"`
	AiErrorAnalysis       *string         `gorm:"type:text" json:"ai_error_analysis,omitempty"`
	AiKnowledgeGaps       JSONB           `gorm:"type:jsonb" json:"ai_knowledge_gaps,omitempty"`
	AiSuggestedExercises  JSONB           `gorm:"type:jsonb" json:"ai_suggested_exercises,omitempty"`
	AiAnalyzedAt          *time.Time      `json:"ai_analyzed_at,omitempty"`
	CreatedAt             time.Time       `gorm:"not null;default:now()" json:"created_at"`
	UpdatedAt             time.Time       `gorm:"not null;default:now()" json:"updated_at"`
	DeletedAt             *time.Time      `gorm:"index" json:"deleted_at,omitempty"`

	// TotalReviewRounds 艾宾浩斯复习总轮次（= len(scheduler.EbbinghausIntervals)）。
	// 非持久化：gorm:"-" 不影响 DB 读写；service 返回题目前显式赋值。
	// omitempty 保证未赋值(0)时不输出，前端仍可回退默认 5。
	TotalReviewRounds     int             `gorm:"-" json:"total_review_rounds,omitempty"`

	// ReviewRecords 关联的最近复习记录（仅 GetByID 详情接口填充，倒序限 N 条）。
	// 非持久化：gorm:"-" 不影响 DB 读写；列表/复习队列不填充以避免 N+1。
	// omitempty 保证未填充(nil)时不输出，前端回退空复习历史。
	ReviewRecords []ReviewRecord `gorm:"-" json:"review_records,omitempty"`

	// Associations
	KnowledgePoints []KnowledgePoint `gorm:"many2many:question_knowledge;" json:"knowledge_points,omitempty"`
}

func (Question) TableName() string { return "questions" }

// ReviewRecord 复习记录表
type ReviewRecord struct {
	ID                  int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	QuestionID          int64      `gorm:"not null;index" json:"question_id"`
	UserID              int64      `gorm:"not null;index" json:"user_id"`
	ReviewRound         int        `gorm:"not null" json:"review_round"`
	SelfRating          SelfRating `gorm:"type:self_rating_enum;not null" json:"self_rating"`
	MasterCountAfter    int        `gorm:"not null" json:"master_count_after"`
	ReviewDurationSec   *int       `json:"review_duration_sec,omitempty"`
	ReviewedAt          time.Time  `gorm:"not null;default:now()" json:"reviewed_at"`
}

func (ReviewRecord) TableName() string { return "review_records" }

// KnowledgePoint 知识点表
type KnowledgePoint struct {
	ID         int     `gorm:"primaryKey;autoIncrement" json:"id"`
	ParentID   *int    `gorm:"index" json:"parent_id,omitempty"`
	Name       string  `gorm:"type:varchar(64);not null" json:"name"`
	Level      int16   `gorm:"not null" json:"level"`
	Stage      Stage   `gorm:"type:stage_enum;not null" json:"stage"`
	Keywords   JSONB   `gorm:"type:jsonb" json:"keywords,omitempty"`
	SortOrder  int     `gorm:"not null;default:0" json:"sort_order"`
	Version    string  `gorm:"type:varchar(16);not null;default:'2026A'" json:"version"`
}

func (KnowledgePoint) TableName() string { return "knowledge_points" }

// knowledgePointJSON 是 KnowledgePoint 序列化到 JSON 响应时使用的 DTO，
// 与 /v1/knowledge-points 列表接口（knowledgePointResponse）保持一致：
// 从 keywords JSONB 解析出 subject / parent_id(领域字符串) / is_recommended，
// 保证错题详情/列表/复习队列里关联的知识点与知识点列表接口返回结构一致。
//
// 前端 KnowledgePoint.fromJson 读取 id/name/subject/parent_id/is_recommended，
// 历史上详情接口直接序列化 model 导致这几个字段缺失（回退默认值），
// 推荐标记与学段丢失。此 MarshalJSON 统一两处输出结构。
type knowledgePointJSON struct {
	ID            int    `json:"id"`
	Name          string `json:"name"`
	Subject       string `json:"subject"`
	ParentID      string `json:"parent_id,omitempty"` // 领域：num/geo/stat/custom
	IsRecommended bool   `json:"is_recommended"`
}

// MarshalJSON 把 KnowledgePoint 序列化为与知识点列表接口一致的 DTO 形状。
// keywords 为空或解析失败时回退：subject="数学"、is_recommended=false、parent_id 省略。
func (kp KnowledgePoint) MarshalJSON() ([]byte, error) {
	dto := knowledgePointJSON{
		ID:   kp.ID,
		Name: kp.Name,
		// 默认学段数学；keywords 里有则覆盖
		Subject: "数学",
	}
	if !kp.Keywords.IsNull() {
		var kw map[string]interface{}
		if err := json.Unmarshal(kp.Keywords, &kw); err == nil {
			if v, ok := kw["subject"].(string); ok && v != "" {
				dto.Subject = v
			}
			if v, ok := kw["domain"].(string); ok && v != "" {
				dto.ParentID = v
			}
			if v, ok := kw["is_recommended"].(bool); ok {
				dto.IsRecommended = v
			}
		}
	}
	return json.Marshal(dto)
}

// WeeklyReport 周报表
type WeeklyReport struct {
	ID                          int64          `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID                      int64          `gorm:"not null;index" json:"user_id"`
	WeekNumber                  int            `gorm:"not null" json:"week_number"`
	WeekStart                   time.Time      `gorm:"type:date;not null" json:"week_start"`
	WeekEnd                     time.Time      `gorm:"type:date;not null" json:"week_end"`
	NewQuestions                int            `gorm:"not null;default:0" json:"new_questions"`
	MasteredQuestions           int            `gorm:"not null;default:0" json:"mastered_questions"`
	ReviewCount                 int            `gorm:"not null;default:0" json:"review_count"`
	ReviewAccuracy              float64        `gorm:"type:decimal(5,2);not null;default:0.00" json:"review_accuracy"`
	PrevWeekNew                 *int           `json:"prev_week_new,omitempty"`
	PrevWeekMastered            *int           `json:"prev_week_mastered,omitempty"`
	PrevWeekReviewCount         *int           `json:"prev_week_review_count,omitempty"`
	PrevWeekAccuracy            *float64       `json:"prev_week_accuracy,omitempty"`
	Achievements                JSONB          `gorm:"type:jsonb;default:'[]'" json:"achievements"`
	TopErrorCategory            *ErrorCategory `gorm:"type:error_category_enum" json:"top_error_category,omitempty"`
	TopErrorCategoryPercentage  float64        `gorm:"type:decimal(5,2);not null;default:0.00" json:"top_error_category_percentage,omitempty"`
	WeakKnowledgeTop            JSONB          `gorm:"type:jsonb" json:"weak_knowledge_top,omitempty"`
	CreatedAt                   time.Time      `gorm:"not null;default:now()" json:"created_at"`
}

func (WeeklyReport) TableName() string { return "weekly_reports" }

// SyncQueue 同步队列表
type SyncQueue struct {
	ID           int64         `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID       int64         `gorm:"not null;index" json:"user_id"`
	EntityType   string        `gorm:"type:varchar(16);not null" json:"entity_type"`
	EntityID     *string       `gorm:"type:varchar(64)" json:"entity_id,omitempty"`
	Operation    SyncOperation `gorm:"type:sync_operation_enum;not null" json:"operation"`
	Payload      JSONB         `gorm:"type:jsonb;not null" json:"payload"`
	Status       SyncStatus    `gorm:"type:sync_status_enum;not null;default:'PENDING'" json:"status"`
	RetryCount   int           `gorm:"not null;default:0" json:"retry_count"`
	NextRetryAt  *time.Time    `json:"next_retry_at,omitempty"`
	ErrorMessage *string       `gorm:"type:text" json:"error_message,omitempty"`
	CreatedAt    time.Time     `gorm:"not null;default:now()" json:"created_at"`
	UpdatedAt    time.Time     `gorm:"not null;default:now()" json:"updated_at"`
}

func (SyncQueue) TableName() string { return "sync_queue" }

// UserDevice 设备表
type UserDevice struct {
	ID          int64      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID      int64      `gorm:"not null;index" json:"user_id"`
	DeviceName  string     `gorm:"type:varchar(64);not null" json:"device_name"`
	DeviceType  DeviceType `gorm:"type:device_type_enum;not null" json:"device_type"`
	PushToken   *string    `gorm:"type:varchar(256)" json:"push_token,omitempty"`
	LastLoginAt time.Time  `gorm:"not null;default:now()" json:"last_login_at"`
	CreatedAt   time.Time  `gorm:"not null;default:now()" json:"created_at"`
}

func (UserDevice) TableName() string { return "user_devices" }

// BaseModel 基础模型（用于 GORM 回调）
type BaseModel struct {
	CreatedAt time.Time
	UpdatedAt time.Time
}

// BeforeCreate GORM hook
func (base *BaseModel) BeforeCreate(tx *gorm.DB) error {
	now := time.Now()
	base.CreatedAt = now
	base.UpdatedAt = now
	return nil
}

// BeforeUpdate GORM hook
func (base *BaseModel) BeforeUpdate(tx *gorm.DB) error {
	base.UpdatedAt = time.Now()
	return nil
}
