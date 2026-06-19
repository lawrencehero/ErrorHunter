package model

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
)

// JSONB 自定义类型用于 PostgreSQL JSONB
type JSONB json.RawMessage

// Value 实现 driver.Valuer 接口
func (j JSONB) Value() (driver.Value, error) {
	if len(j) == 0 {
		return nil, nil
	}
	return string(j), nil
}

// Scan 实现 sql.Scanner 接口
func (j *JSONB) Scan(value interface{}) error {
	if value == nil {
		*j = JSONB("null")
		return nil
	}
	switch v := value.(type) {
	case []byte:
		*j = append((*j)[0:0], v...)
	case string:
		*j = append((*j)[0:0], v...)
	default:
		return errors.New("unsupported type for JSONB")
	}
	return nil
}

// MarshalJSON 实现 json.Marshaler 接口
func (j JSONB) MarshalJSON() ([]byte, error) {
	if len(j) == 0 {
		return []byte("null"), nil
	}
	return []byte(j), nil
}

// UnmarshalJSON 实现 json.Unmarshaler 接口
func (j *JSONB) UnmarshalJSON(data []byte) error {
	if j == nil {
		return errors.New("JSONB: UnmarshalJSON on nil pointer")
	}
	*j = append((*j)[0:0], data...)
	return nil
}

// String 返回字符串表示
func (j JSONB) String() string {
	return string(j)
}

// IsNull 检查是否为 null
func (j JSONB) IsNull() bool {
	return len(j) == 0 || string(j) == "null"
}

// ToSlice 转换为字符串切片
func (j JSONB) ToStringSlice() ([]string, error) {
	if j.IsNull() {
		return nil, nil
	}
	var result []string
	err := json.Unmarshal(j, &result)
	return result, err
}

// FromSlice 从字符串切片创建
func JSONBFromSlice(s []string) JSONB {
	data, _ := json.Marshal(s)
	return JSONB(data)
}

// FromMap 从 map 创建
func JSONBFromMap(m map[string]interface{}) JSONB {
	data, _ := json.Marshal(m)
	return JSONB(data)
}
