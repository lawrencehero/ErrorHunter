module github.com/errorhunter/errorhunter-server

go 1.22

require (
	github.com/aws/aws-sdk-go-v2 v1.30.0
	github.com/aws/aws-sdk-go-v2/config v1.27.24
	github.com/aws/aws-sdk-go-v2/credentials v1.17.24
	github.com/aws/aws-sdk-go-v2/service/s3 v1.58.0
	github.com/gin-contrib/cors v1.7.1
	github.com/gin-gonic/gin v1.10.0
	github.com/golang-jwt/jwt/v5 v5.2.1
	github.com/google/uuid v1.6.0
	github.com/lib/pq v1.10.9
	github.com/redis/go-redis/v9 v9.5.3
	github.com/spf13/viper v1.19.0
	go.uber.org/zap v1.27.0
	golang.org/x/crypto v0.24.0
	gorm.io/driver/postgres v1.5.9
	gorm.io/gorm v1.25.10
)
