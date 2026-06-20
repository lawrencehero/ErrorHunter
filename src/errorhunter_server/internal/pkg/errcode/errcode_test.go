package errcode

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestAppError_Error 验证 Error() 返回 message
func TestAppError_Error(t *testing.T) {
	err := New(10001, "测试错误", http.StatusBadRequest)
	assert.Equal(t, "测试错误", err.Error())
}

// TestAppError_WithData 验证 WithData 附加数据
func TestAppError_WithData(t *testing.T) {
	err := New(10001, "测试错误", http.StatusBadRequest)
	errWithData := err.WithData(map[string]string{"key": "value"})

	assert.NotNil(t, errWithData.Data)
	assert.Nil(t, err.Data) // 原错误不受影响
	assert.NotSame(t, err, errWithData)
}

// TestPredefinedErrors_UserModule 用户模块预定义错误
func TestPredefinedErrors_UserModule(t *testing.T) {
	tests := []struct {
		name       string
		err        *AppError
		code       int
		httpStatus int
	}{
		{"手机号已注册", EPhoneAlreadyRegistered, ErrPhoneAlreadyRegistered, http.StatusConflict},
		{"验证码无效", EVerifyCodeInvalid, ErrVerifyCodeInvalid, http.StatusBadRequest},
		{"验证码锁定", EVerifyCodeLocked, ErrVerifyCodeLocked, http.StatusTooManyRequests},
		{"用户不存在", EUserNotFound, ErrUserNotFound, http.StatusNotFound},
		{"发送频繁", ESendCodeTooFrequent, ErrSendCodeTooFrequent, http.StatusTooManyRequests},
		{"每日限制", ESendCodeDailyLimit, ErrSendCodeDailyLimit, http.StatusTooManyRequests},
		{"Refresh过期", ERefreshTokenExpired, ErrRefreshTokenExpired, http.StatusUnauthorized},
		{"账号已注销", EAccountDeleted, ErrAccountDeleted, http.StatusForbidden},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.code, tt.err.Code)
			assert.Equal(t, tt.httpStatus, tt.err.HTTPStatus)
			assert.NotEmpty(t, tt.err.Message)
		})
	}
}

// TestPredefinedErrors_QuestionModule 错题模块预定义错误
func TestPredefinedErrors_QuestionModule(t *testing.T) {
	tests := []struct {
		name       string
		err        *AppError
		code       int
		httpStatus int
	}{
		{"存储已满", EStorageFull, ErrStorageFull, http.StatusForbidden},
		{"错题不存在", EQuestionNotFound, ErrQuestionNotFound, http.StatusNotFound},
		{"标签超限", ECustomTagsMax, ErrCustomTagsMaxExceeded, http.StatusBadRequest},
		{"错因无效", EErrorCategoryInvalid, ErrErrorCategoryInvalid, http.StatusBadRequest},
		{"无权操作", EQuestionBelongsToOther, ErrQuestionBelongsToOther, http.StatusForbidden},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.code, tt.err.Code)
			assert.Equal(t, tt.httpStatus, tt.err.HTTPStatus)
		})
	}
}

// TestPredefinedErrors_ReviewModule 复习模块预定义错误
func TestPredefinedErrors_ReviewModule(t *testing.T) {
	tests := []struct {
		name string
		err  *AppError
		code int
	}{
		{"自评无效", ESelfRatingInvalid, ErrReviewSelfRatingInvalid},
		{"复活结果必填", EReviveResultRequired, ErrReviveResultRequired},
		{"复活结果无效", EReviveResultInvalid, ErrReviveResultInvalid},
		{"今日已复习", EReviewAlreadyDone, ErrReviewAlreadyCompleted},
		{"用时为负", EReviewDurationNeg, ErrReviewDurationNegative},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.code, tt.err.Code)
		})
	}
}

// TestPredefinedErrors_SystemModule 系统级预定义错误
func TestPredefinedErrors_SystemModule(t *testing.T) {
	assert.Equal(t, ErrInternalServer, EInternalServer.Code)
	assert.Equal(t, http.StatusInternalServerError, EInternalServer.HTTPStatus)

	assert.Equal(t, ErrUnauthorized, EUnauthorized.Code)
	assert.Equal(t, http.StatusUnauthorized, EUnauthorized.HTTPStatus)

	assert.Equal(t, ErrParamValidation, EParamValidation.Code)
	assert.Equal(t, http.StatusBadRequest, EParamValidation.HTTPStatus)
}

// TestNew_CreatesCorrectError 验证 New 构造函数
func TestNew_CreatesCorrectError(t *testing.T) {
	err := New(99999, "自定义错误", http.StatusTeapot)
	assert.Equal(t, 99999, err.Code)
	assert.Equal(t, "自定义错误", err.Message)
	assert.Equal(t, http.StatusTeapot, err.HTTPStatus)
	assert.Nil(t, err.Data)
}
