package handler

import (
	"github.com/errorhunter/errorhunter-server/internal/pkg/errcode"
	"github.com/gin-gonic/gin"
)

// respondSuccess 成功响应
func respondSuccess(c *gin.Context, data interface{}) {
	c.JSON(200, gin.H{
		"code":    0,
		"message": "success",
		"data":    data,
	})
}

// respondCreated 创建成功响应
func respondCreated(c *gin.Context, data interface{}) {
	c.JSON(201, gin.H{
		"code":    0,
		"message": "created",
		"data":    data,
	})
}

// respondError 错误响应
func respondError(c *gin.Context, err *errcode.AppError) {
	c.JSON(err.HTTPStatus, gin.H{
		"code":    err.Code,
		"message": err.Message,
		"data":    err.Data,
	})
}

// respondNoContent 无内容响应
func respondNoContent(c *gin.Context) {
	c.Status(204)
}
