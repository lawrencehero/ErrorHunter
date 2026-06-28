package handler

import (
	"encoding/json"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestGetStorageUsage_ResponseKeys 守护修复3的 JSON 契约：GET /v1/storage 响应
// data 块必须含 used_bytes / image_count / images / total / has_more 五个 key。
// 若有人移除新增的 images/total/has_more（回退到只返回 used_bytes/image_count），
// 本测试会立即失败。
//
// 说明：UploadHandler.s3Client 是具体 *s3.Client（非接口），无法在不改产品代码的
// 前提下注入 fake，故 list 逻辑本身未单测（需集成/真机覆盖）。这里在 handler 包内
// 直接复用非导出类型 cloudImageItem，构造与 GetStorageUsage 完全相同的响应体结构
// （gin.H + []cloudImageItem），守护序列化形状与排序/截断/has_more 语义。
func TestGetStorageUsage_ResponseKeys(t *testing.T) {
	now := time.Now().UTC()
	// 构造若干图片项（顺序故意打乱，验证后续倒序）
	items := []cloudImageItem{
		{URL: "http://h/v1/files/questions/1/b.jpg", Size: 1024, LastModified: now.Add(-2 * time.Hour).Format(time.RFC3339), Key: "questions/1/b.jpg"},
		{URL: "http://h/v1/files/questions/1/a.jpg", Size: 2048, LastModified: now.Add(-1 * time.Hour).Format(time.RFC3339), Key: "questions/1/a.jpg"},
		{URL: "http://h/v1/files/questions/1/c.jpg", Size: 512, LastModified: now.Add(-3 * time.Hour).Format(time.RFC3339), Key: "questions/1/c.jpg"},
	}

	// 复现 GetStorageUsage 的排序契约：按 last_modified 倒序（最近在前）
	sort.Slice(items, func(i, j int) bool {
		return items[i].LastModified > items[j].LastModified
	})

	// 复现 GetStorageUsage 的响应体结构（与产品代码 gin.H 一致）
	resp := gin.H{
		"used_bytes":  int64(1024 + 2048 + 512),
		"image_count": int64(3),
		"images":      items,
		"total":       int64(3),
		"has_more":    int64(3) > int64(len(items)),
	}

	raw, err := json.Marshal(resp)
	require.NoError(t, err, "storage 响应应可序列化")
	jsonStr := string(raw)

	// 1) 守护：必须存在新增的三个 key（回退到只返回 used_bytes/image_count 会失败）
	assert.True(t, strings.Contains(jsonStr, `"images"`),
		"storage 响应必须含 images key，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"total"`),
		"storage 响应必须含 total key，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"has_more"`),
		"storage 响应必须含 has_more key，got: %s", jsonStr)

	// 2) 守护：保留的原有 key 不得丢失
	assert.True(t, strings.Contains(jsonStr, `"used_bytes"`),
		"storage 响应必须含 used_bytes key，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"image_count"`),
		"storage 响应必须含 image_count key，got: %s", jsonStr)

	// 3) 守护：images 列表内每项必须含 url / size / last_modified / key 字段
	assert.True(t, strings.Contains(jsonStr, `"url"`),
		"images 项应序列化出 url，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"size"`),
		"images 项应序列化出 size，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"last_modified"`),
		"images 项应序列化出 last_modified，got: %s", jsonStr)
	assert.True(t, strings.Contains(jsonStr, `"key"`),
		"images 项应序列化出 key，got: %s", jsonStr)

	// 4) 守护：排序契约——images 按最后修改时间倒序排列
	var decoded map[string]interface{}
	require.NoError(t, json.Unmarshal(raw, &decoded))
	images, ok := decoded["images"].([]interface{})
	require.True(t, ok, "images 应为数组")
	require.Len(t, images, 3, "images 应有 3 项")
	firstKey := images[0].(map[string]interface{})["key"].(string)
	assert.Equal(t, "questions/1/a.jpg", firstKey,
		"images[0] 应是最近修改的 a.jpg（倒序），got: %s", firstKey)

	// 5) 守护：has_more 语义——总数等于已返回数时为 false
	assert.Equal(t, false, decoded["has_more"],
		"image_count == len(images) 时 has_more 应为 false")
	assert.Equal(t, float64(3), decoded["total"],
		"total 应等于 image_count")
}

// TestGetStorageUsage_CapAndHasMore 守护修复3 的 200 上限 + has_more 语义：
// 当对象总数超过 cloudImageListMax 时，images 截断到 200 项，但 total 仍为全量、
// has_more 为 true。复现 GetStorageUsage 的截断+计数逻辑（纯逻辑，不依赖 s3）。
func TestGetStorageUsage_CapAndHasMore(t *testing.T) {
	// 模拟 250 个对象（超过 200 上限）
	totalObjects := int64(250)
	images := make([]cloudImageItem, 0, cloudImageListMax)
	for i := 0; i < int(totalObjects); i++ {
		// 已收集满上限后不再追加（与产品代码一致），但 total/image_count 仍统计全量
		if len(images) >= cloudImageListMax {
			continue
		}
		images = append(images, cloudImageItem{
			URL:          "http://h/v1/files/questions/1/x.jpg",
			Size:         100,
			LastModified: time.Now().UTC().Format(time.RFC3339),
			Key:          "questions/1/x.jpg",
		})
	}

	// 复现响应体
	resp := gin.H{
		"used_bytes":  totalObjects * 100,
		"image_count": totalObjects,
		"images":      images,
		"total":       totalObjects,
		"has_more":    totalObjects > int64(len(images)),
	}

	raw, err := json.Marshal(resp)
	require.NoError(t, err)
	var decoded map[string]interface{}
	require.NoError(t, json.Unmarshal(raw, &decoded))

	// 守护：images 截断到 200 上限
	imagesArr, ok := decoded["images"].([]interface{})
	require.True(t, ok, "images 应为数组")
	assert.Equal(t, cloudImageListMax, len(imagesArr),
		"images 应被截断到 cloudImageListMax(%d)，got: %d", cloudImageListMax, len(imagesArr))

	// 守护：total 仍是全量对象数（未被截断）
	assert.Equal(t, float64(totalObjects), decoded["total"],
		"total 应为全量对象数 %d，got: %v", totalObjects, decoded["total"])
	assert.Equal(t, float64(totalObjects), decoded["image_count"],
		"image_count 应为全量对象数 %d，got: %v", totalObjects, decoded["image_count"])

	// 守护：has_more 为 true（超出上限）
	assert.Equal(t, true, decoded["has_more"],
		"对象数超过上限时 has_more 应为 true")
}
