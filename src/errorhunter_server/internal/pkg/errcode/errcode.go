package errcode

import "net/http"

// AppError 统一错误结构
type AppError struct {
	Code       int         `json:"code"`
	Message    string      `json:"message"`
	Data       interface{} `json:"data,omitempty"`
	HTTPStatus int         `json:"-"`
}

func (e *AppError) Error() string {
	return e.Message
}

// New 创建新错误
func New(code int, message string, httpStatus int) *AppError {
	return &AppError{
		Code:       code,
		Message:    message,
		HTTPStatus: httpStatus,
	}
}

// WithData 附加数据
func (e *AppError) WithData(data interface{}) *AppError {
	copyErr := *e
	copyErr.Data = data
	return &copyErr
}

// ===== 10000-19999 用户模块 =====
const (
	ErrPhoneAlreadyRegistered = 10001
	ErrVerifyCodeInvalid      = 10002
	ErrParentConsentRequired  = 10003
	ErrVerifyCodeLocked       = 10004
	ErrUserNotFound           = 10005
	ErrSendCodeTooFrequent    = 10006
	ErrSendCodeDailyLimit     = 10007
	ErrRefreshTokenExpired    = 10008
	ErrStorageWarning         = 10009
	ErrNicknameInvalid        = 10010
	ErrGradeInvalid           = 10011
	ErrReminderTimeInvalid    = 10012
	ErrDailyLimitInvalid      = 10013
	ErrAccountDeleted         = 10014
	ErrDeviceLimitExceeded    = 10015
	ErrPushTokenInvalid       = 10016
)

// ===== 20000-29999 错题模块 =====
const (
	ErrStorageFull               = 20001
	ErrKnowledgePointMaxExceeded = 20002
	ErrKnowledgeStageMismatch    = 20003
	ErrQuestionNotFound          = 20004
	ErrRecycleBinConfirmRequired = 20005
	ErrCustomTagsMaxExceeded     = 20006
	ErrErrorCategoryRequired     = 20007
	ErrErrorCategoryInvalid      = 20008
	ErrImageUrlRequired          = 20009
	ErrQuestionBelongsToOther    = 20010
	ErrExportLimitExceeded       = 20011
	ErrSolutionStepInvalid       = 20012
	ErrOcrTextTooLong            = 20013
	ErrKnowledgePointNotFound    = 20014
)

// ===== 30000-39999 复习模块 =====
const (
	ErrReviewQuestionNotDue    = 30001
	ErrReviewSelfRatingInvalid = 30002
	ErrReviveResultRequired    = 30003
	ErrReviveResultInvalid     = 30004
	ErrReviewAlreadyCompleted  = 30005
	ErrReviewRecordConflict    = 30006
	ErrReviveCheckNotAllowed   = 30007
	ErrReviewDurationNegative  = 30008
)

// ===== 40000-49999 报告模块 =====
const (
	ErrReportNotFound       = 40001
	ErrReportWeekInvalid    = 40002
	ErrReportGenerateFailed = 40003
	ErrDashboardCacheError  = 40004
)

// ===== 50000-59999 同步模块 =====
const (
	ErrSyncPayloadInvalid       = 50001
	ErrSyncEntityTypeInvalid    = 50002
	ErrSyncOperationInvalid     = 50003
	ErrSyncBatchSizeExceeded    = 50004
	ErrSyncRelatedEntityMissing = 50005
	ErrSyncRetryIdNotFound      = 50006
	ErrSyncRetryNotFailed       = 50007
	ErrSyncLocalIdDuplicate     = 50008
)

// ===== 60000-69999 图片模块 =====
const (
	ErrImageTooLarge            = 60001
	ErrImageStorageInsufficient = 60002
	ErrImageFormatUnsupported   = 60003
	ErrImageUploadUrlExpired    = 60004
	ErrImageSignedUrlInvalid    = 60005
	ErrImageFileNameInvalid     = 60006
	ErrImageCategoryInvalid     = 60007
	ErrOssServiceUnavailable    = 60008
)

// ===== 90000-99999 系统级 =====
const (
	ErrRateLimited        = 90001
	ErrServiceUnavailable = 90002
	ErrInternalServer     = 90003
	ErrInvalidRequest     = 90004
	ErrUnauthorized       = 90005
	ErrForbidden          = 90006
	ErrResourceNotFound   = 90007
	ErrMethodNotAllowed   = 90008
	ErrParamValidation    = 90009
)

// ===== 预定义错误变量 =====
var (
	// 用户模块
	EPhoneAlreadyRegistered = New(ErrPhoneAlreadyRegistered, "该手机号已注册，是否直接登录？", http.StatusConflict)
	EVerifyCodeInvalid      = New(ErrVerifyCodeInvalid, "验证码错误或已过期", http.StatusBadRequest)
	EParentConsentRequired  = New(ErrParentConsentRequired, "请勾选家长知情同意", http.StatusBadRequest)
	EVerifyCodeLocked       = New(ErrVerifyCodeLocked, "验证码输错次数过多，请30分钟后再试", http.StatusTooManyRequests)
	EUserNotFound           = New(ErrUserNotFound, "该手机号未注册", http.StatusNotFound)
	ESendCodeTooFrequent    = New(ErrSendCodeTooFrequent, "发送过于频繁，请60秒后再试", http.StatusTooManyRequests)
	ESendCodeDailyLimit     = New(ErrSendCodeDailyLimit, "今日验证码发送次数已达上限", http.StatusTooManyRequests)
	ERefreshTokenExpired    = New(ErrRefreshTokenExpired, "登录已过期，请重新登录", http.StatusUnauthorized)
	EStorageWarning         = New(ErrStorageWarning, "存储空间即将不足", http.StatusOK)
	ENicknameInvalid        = New(ErrNicknameInvalid, "昵称长度应为2-12个字符", http.StatusBadRequest)
	EGradeInvalid           = New(ErrGradeInvalid, "无效的年级值", http.StatusBadRequest)
	EReminderTimeInvalid    = New(ErrReminderTimeInvalid, "提醒时间不在有效范围", http.StatusBadRequest)
	EDailyLimitInvalid      = New(ErrDailyLimitInvalid, "每日复习上限应在10-30之间", http.StatusBadRequest)
	EAccountDeleted         = New(ErrAccountDeleted, "该账号已注销", http.StatusForbidden)
	EDeviceLimitExceeded    = New(ErrDeviceLimitExceeded, "设备数已达上限", http.StatusBadRequest)

	// 错题模块
	EStorageFull            = New(ErrStorageFull, "存储空间已满，请清理空间或升级", http.StatusForbidden)
	EKnowledgePointMax      = New(ErrKnowledgePointMaxExceeded, "每道错题最多关联10个知识点", http.StatusBadRequest)
	EKnowledgeStageMismatch = New(ErrKnowledgeStageMismatch, "所选知识点与当前年级不匹配", http.StatusBadRequest)
	EQuestionNotFound       = New(ErrQuestionNotFound, "错题不存在或已被删除", http.StatusNotFound)
	ERecycleBinConfirm      = New(ErrRecycleBinConfirmRequired, "请确认清空操作，此操作不可恢复", http.StatusBadRequest)
	ECustomTagsMax          = New(ErrCustomTagsMaxExceeded, "自定义标签最多5个", http.StatusBadRequest)
	EErrorCategoryRequired  = New(ErrErrorCategoryRequired, "请选择错因粗分类", http.StatusBadRequest)
	EErrorCategoryInvalid   = New(ErrErrorCategoryInvalid, "无效错因分类", http.StatusBadRequest)
	EImageUrlRequired       = New(ErrImageUrlRequired, "题目图片URL必填", http.StatusBadRequest)
	EQuestionBelongsToOther      = New(ErrQuestionBelongsToOther, "无权操作该错题", http.StatusForbidden)
	EKnowledgePointNotFound      = New(ErrKnowledgePointNotFound, "部分知识点不存在", http.StatusBadRequest)

	// 复习模块
	EReviewNotDue         = New(ErrReviewQuestionNotDue, "该错题今日不在复习计划中", http.StatusBadRequest)
	ESelfRatingInvalid    = New(ErrReviewSelfRatingInvalid, "无效的自评结果", http.StatusBadRequest)
	EReviveResultRequired = New(ErrReviveResultRequired, "复活检测需提供检测结果", http.StatusBadRequest)
	EReviveResultInvalid  = New(ErrReviveResultInvalid, "无效复活检测结果", http.StatusBadRequest)
	EReviewAlreadyDone    = New(ErrReviewAlreadyCompleted, "今日已完成该题的复习", http.StatusConflict)
	EReviewDurationNeg    = New(ErrReviewDurationNegative, "复习用时不能为负", http.StatusBadRequest)

	// 报告模块
	EReportNotFound = New(ErrReportNotFound, "周报不存在", http.StatusNotFound)

	// 同步模块
	ESyncPayloadInvalid = New(ErrSyncPayloadInvalid, "同步数据格式无效", http.StatusBadRequest)
	ESyncBatchExceeded  = New(ErrSyncBatchSizeExceeded, "批量同步不能超过50条", http.StatusBadRequest)
	ESyncRelatedMissing = New(ErrSyncRelatedEntityMissing, "关联的实体不存在", http.StatusBadRequest)

	// 图片模块
	EImageTooLarge          = New(ErrImageTooLarge, "文件大小超过20MB限制", http.StatusBadRequest)
	EImageStorageInsuff     = New(ErrImageStorageInsufficient, "存储空间不足，请清理后重试", http.StatusForbidden)
	EImageFormatUnsupported = New(ErrImageFormatUnsupported, "不支持的图片格式，仅支持JPG/PNG/HEIC", http.StatusBadRequest)
	EOssUnavailable         = New(ErrOssServiceUnavailable, "图片服务暂时不可用，请稍后重试", http.StatusServiceUnavailable)

	// 系统级
	ERateLimited        = New(ErrRateLimited, "请求过于频繁，请稍后再试", http.StatusTooManyRequests)
	EServiceUnavailable = New(ErrServiceUnavailable, "服务暂时不可用，请稍后重试", http.StatusServiceUnavailable)
	EInternalServer     = New(ErrInternalServer, "服务器内部错误", http.StatusInternalServerError)
	EInvalidRequest     = New(ErrInvalidRequest, "请求格式错误", http.StatusBadRequest)
	EUnauthorized       = New(ErrUnauthorized, "请先登录", http.StatusUnauthorized)
	EForbidden          = New(ErrForbidden, "无权访问", http.StatusForbidden)
	EParamValidation    = New(ErrParamValidation, "参数校验失败", http.StatusBadRequest)
)
