package repository

import (
	"context"
	"time"

	"github.com/errorhunter/errorhunter-server/internal/model"
	"gorm.io/gorm"
)

// UserRepository 用户数据访问
type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}

// Create 创建用户
func (r *UserRepository) Create(ctx context.Context, user *model.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

// FindByID 根据ID查找
func (r *UserRepository) FindByID(ctx context.Context, id int64) (*model.User, error) {
	var user model.User
	err := r.db.WithContext(ctx).Where("id = ? AND deleted_at IS NULL", id).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByPhone 根据手机号查找
func (r *UserRepository) FindByPhone(ctx context.Context, phone string) (*model.User, error) {
	var user model.User
	err := r.db.WithContext(ctx).Where("phone = ? AND deleted_at IS NULL", phone).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// Update 更新用户
func (r *UserRepository) Update(ctx context.Context, user *model.User) error {
	return r.db.WithContext(ctx).Save(user).Error
}

// UpdateLastActive 更新最后活跃时间
func (r *UserRepository) UpdateLastActive(ctx context.Context, userID int64) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&model.User{}).
		Where("id = ?", userID).
		Update("last_active_at", now).Error
}

// SoftDelete 软删除（注销账号）
func (r *UserRepository) SoftDelete(ctx context.Context, userID int64) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&model.User{}).
		Where("id = ?", userID).
		Update("deleted_at", now).Error
}

// UpdateStreakDays 更新连续打卡天数
func (r *UserRepository) UpdateStreakDays(ctx context.Context, userID int64, days int) error {
	return r.db.WithContext(ctx).Model(&model.User{}).
		Where("id = ?", userID).
		Update("streak_days", days).Error
}

// ListActiveUserIDs 列出所有未软删用户的 ID（周报定时任务用）。
// 仅取 id 列，避免把全表用户对象载入内存。
func (r *UserRepository) ListActiveUserIDs(ctx context.Context) ([]int64, error) {
	ids := make([]int64, 0)
	err := r.db.WithContext(ctx).
		Model(&model.User{}).
		Where("deleted_at IS NULL").
		Pluck("id", &ids).Error
	return ids, err
}

// UpdateStreakOnActivity 复习时原子更新连续打卡天数，返回更新后的 streak_days。
//
// 单条 SQL 原子更新，避免一次复习会话内多题并发提交导致 streak 叠加成 +N：
//   - last_review_date = 今天：streak 不变（当天已计打卡）
//   - last_review_date = 昨天：streak + 1（连续打卡延续）
//   - 其它（NULL / 首次复习 / 断卡）：streak = 1
//
// 字段选择：用 last_review_date（DATE）而非 last_active_at 判断"是否已打卡"。
//   last_active_at 同时被登录（auth_service.go UpdateLastActive）和复习更新，
//   用它判断会导致"登录后首次复习"被误判为"今天已打卡"→ streak 恒 0。
//   last_review_date 只由本方法（复习路径）更新，登录不动它，从而隔离两种语义。
//   仍保留 last_active_at = NOW() 维持"最近活跃"语义不变。
//
// 时区说明：last_review_date 为 DATE 列，DB 会话时区 TZ=Asia/Shanghai，
// current_date 即上海日期；DATE 列存的就是日期值，无需 AT TIME ZONE 转换。
// current_date - 1（postgres DATE 减整数）= 昨天 DATE。
// WHERE deleted_at IS NULL 与 FindByID 语义一致，避免软删用户被更新。
func (r *UserRepository) UpdateStreakOnActivity(ctx context.Context, userID int64) (int, error) {
	const sql = `
UPDATE users SET
  streak_days = CASE
    WHEN last_review_date = current_date THEN streak_days
    WHEN last_review_date = current_date - 1 THEN streak_days + 1
    ELSE 1
  END,
  last_review_date = current_date,
  last_active_at = NOW(),
  updated_at = NOW()
WHERE id = ? AND deleted_at IS NULL
RETURNING streak_days`

	var newStreak int
	if err := r.db.WithContext(ctx).Raw(sql, userID).Scan(&newStreak).Error; err != nil {
		return 0, err
	}
	return newStreak, nil
}
