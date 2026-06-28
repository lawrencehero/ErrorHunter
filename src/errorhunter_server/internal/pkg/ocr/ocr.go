package ocr

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"regexp"
	"sort"
	"strings"
	"time"

	openapi "github.com/alibabacloud-go/darabonba-openapi/v2/client"
	alicloudOcr "github.com/alibabacloud-go/ocr-api-20210707/v3/client"
	"github.com/alibabacloud-go/tea/tea"
	util "github.com/alibabacloud-go/tea-utils/v2/service"
)

// latexRe 匹配 LaTeX 命令（如 \frac \sqrt \cdot）
var latexRe = regexp.MustCompile(`\\[a-zA-Z]+`)

// Result OCR识别结果
type Result struct {
	Text           string          `json:"text"`
	Confidence     float64         `json:"confidence"`
	HasHandwriting bool            `json:"has_handwriting"`
	HasFormula     bool            `json:"has_formula"`
	Figures        []FigureRegion  `json:"figures"`
	Degraded       bool            `json:"degraded"`
	DegradeReason  string          `json:"degrade_reason,omitempty"`
}

// FigureRegion 识别到的图形区域（相对原图像素坐标）
type FigureRegion struct {
	Type string `json:"type"`
	X    int    `json:"x"`
	Y    int    `json:"y"`
	W    int    `json:"w"`
	H    int    `json:"h"`
}

// Provider OCR提供者接口
type Provider interface {
	Recognize(ctx context.Context, imageURL string, body io.Reader) (*Result, error)
}

// Service OCR服务
type Service struct {
	provider Provider
	timeout  time.Duration
}

// NewService 创建OCR服务
func NewService(provider Provider, timeout time.Duration) *Service {
	return &Service{
		provider: provider,
		timeout:  timeout,
	}
}

// ocrMaxAttempts OCR 识别最大尝试次数（应对阿里云 OCR 端点偶发网络抖动）
const ocrMaxAttempts = 3

// ocrRetryBackoff 每次重试前的退避时间
const ocrRetryBackoff = 300 * time.Millisecond

// Recognize 识别图片文字（带超时降级 + 失败重试）
// body 为图片二进制数据流（优先使用），imageURL 为备选 URL。
// body 若为 io.Seeker（如 bytes.Reader），重试时会重置到起始位置。
func (s *Service) Recognize(ctx context.Context, imageURL string, body io.Reader) (*Result, error) {
	var lastReason string

	for attempt := 1; attempt <= ocrMaxAttempts; attempt++ {
		// 重试时重置 body 到起始位置
		if seeker, ok := body.(io.Seeker); ok {
			_, _ = seeker.Seek(0, io.SeekStart)
		}

		attemptCtx, cancel := context.WithTimeout(ctx, s.timeout)
		resultCh := make(chan *Result, 1)
		errCh := make(chan error, 1)

		go func() {
			r, e := s.provider.Recognize(attemptCtx, imageURL, body)
			if e != nil {
				errCh <- e
				return
			}
			resultCh <- r
		}()

		select {
		case r := <-resultCh:
			cancel()
			return r, nil
		case e := <-errCh:
			cancel()
			lastReason = "识别失败: " + e.Error()
		case <-attemptCtx.Done():
			cancel()
			lastReason = "识别超时，请手动输入题目内容"
		}

		// 还有重试机会则短暂退避后继续
		if attempt < ocrMaxAttempts {
			select {
			case <-time.After(ocrRetryBackoff):
			case <-ctx.Done():
				return &Result{Degraded: true, DegradeReason: lastReason}, nil
			}
		}
		if ctx.Err() != nil {
			break
		}
	}

	return &Result{Degraded: true, DegradeReason: lastReason}, nil
}

// MockProvider 模拟OCR提供者（开发测试用）
type MockProvider struct{}

func (p *MockProvider) Recognize(ctx context.Context, imageURL string, body io.Reader) (*Result, error) {
	time.Sleep(100 * time.Millisecond)
	return &Result{
		Text:       "这是一道示例数学题：\n计算 3/4 + 2/3 = ?",
		Confidence: 0.95,
		HasFormula: true,
	}, nil
}

// AliyunProvider 阿里云读光OCR提供者
type AliyunProvider struct {
	AccessKey string
	SecretKey string
	Endpoint  string
	client    *alicloudOcr.Client
}

func (p *AliyunProvider) initClient() error {
	if p.client != nil {
		return nil
	}
	endpoint := p.Endpoint
	if endpoint == "" {
		endpoint = "ocr-api.cn-hangzhou.aliyuncs.com"
	}
	config := &openapi.Config{
		AccessKeyId:     tea.String(p.AccessKey),
		AccessKeySecret: tea.String(p.SecretKey),
		Endpoint:        tea.String(endpoint),
	}
	client, err := alicloudOcr.NewClient(config)
	if err != nil {
		return fmt.Errorf("创建阿里云OCR客户端失败: %w", err)
	}
	p.client = client
	return nil
}

func (p *AliyunProvider) Recognize(ctx context.Context, imageURL string, body io.Reader) (*Result, error) {
	if err := p.initClient(); err != nil {
		return nil, err
	}

	request := &alicloudOcr.RecognizeEduQuestionOcrRequest{}

	// 优先使用 Body（直接传图片数据），否则用 URL
	if body != nil {
		request.Body = body
		log.Printf("[OCR] 使用图片 Body 直接识别")
	} else {
		request.Url = tea.String(imageURL)
		log.Printf("[OCR] 使用图片 URL 识别: %s", imageURL)
	}

	runtime := &util.RuntimeOptions{}

	resp, err := p.client.RecognizeEduQuestionOcrWithOptions(request, runtime)
	if err != nil {
		return nil, fmt.Errorf("阿里云OCR请求失败: %w", err)
	}

	if resp.Body == nil || resp.Body.Data == nil {
		return nil, fmt.Errorf("阿里云OCR返回空结果")
	}

	// 解析返回的 JSON 数据
	rawData := tea.StringValue(resp.Body.Data)
	var ocrData eduQuestionResult
	if err := json.Unmarshal([]byte(rawData), &ocrData); err != nil {
		return nil, fmt.Errorf("解析OCR结果失败: %w", err)
	}

	// 组装识别文本：按 y 坐标分组成行，避免逐词换行
	hasHandwriting := false
	hasFormula := false

	for _, prism := range ocrData.PrismWordsInfo {
		if strings.Contains(strings.ToLower(prism.WordType), "handwriting") {
			hasHandwriting = true
		}
		if latexRe.MatchString(prism.Word) {
			hasFormula = true
		}
	}

	text := reconstructOcrLines(ocrData.PrismWordsInfo, ocrData.PrismFormulaInfo, ocrData.Content)
	if text == "" {
		text = "[未识别到文字内容]"
	}

	// 提取图形区域（排除 subject_pattern 题目区域，只要有效尺寸的图形）
	var figures []FigureRegion
	for _, f := range ocrData.Figure {
		if f.Type == "subject_pattern" || f.W == 0 || f.H == 0 {
			continue
		}
		figures = append(figures, FigureRegion{
			Type: f.Type, X: f.X, Y: f.Y, W: f.W, H: f.H,
		})
	}

	log.Printf("[OCR] 识别完成: %d 文字块, %d 公式, %d 图形, 手写=%v",
		len(ocrData.PrismWordsInfo), len(ocrData.PrismFormulaInfo), len(figures), hasHandwriting)

	return &Result{
		Text:           text,
		Confidence:     0.90,
		HasHandwriting: hasHandwriting,
		HasFormula:     hasFormula,
		Figures:        figures,
	}, nil
}

// eduQuestionResult 阿里云 RecognizeEduQuestionOcr 返回数据结构
type eduQuestionResult struct {
	Content          string             `json:"content"`
	Figure           []figureInfo       `json:"figure"`
	PrismWordsInfo   []prismWordInfo   `json:"prism_wordsInfo"`
	PrismFormulaInfo []prismFormulaInfo `json:"prism_formulaInfo"`
}

type figureInfo struct {
	Type string `json:"type"`
	X    int    `json:"x"`
	Y    int    `json:"y"`
	W    int    `json:"w"`
	H    int    `json:"h"`
}

type prismWordInfo struct {
	Word     string `json:"word"`
	WordType string `json:"wordType"`
	X        int    `json:"x"`
	Y        int    `json:"y"`
	Height   int    `json:"height"`
}

type prismFormulaInfo struct {
	Text string `json:"text"`
}

// heightOf 取词块高度，h==0 时兜底为 32（阿里云 OCR 偶发返回 0）。
func heightOf(w prismWordInfo) int {
	if w.Height == 0 {
		return 32
	}
	return w.Height
}

// reconstructOcrLines 按 y 坐标把词块聚类成行，行内按 x 排序、空格连接，行间换行。
// 公式通常已内联在 word 中；仅当词块中无 LaTeX 且存在独立公式块时才追加公式。
//
// 同行判定采用「先按 y 断行再聚行」：按 y 排序后顺序遍历，用「相邻词 y 差」判定
// （而非「与行首 y 差」），避免行 y/height 合并后不更新导致的连锁漂移。
// 阈值收紧为 < minH/2（严格小于），避免 2×2 选项布局（行间距 0.5-0.6h）误并入。
func reconstructOcrLines(words []prismWordInfo, formulas []prismFormulaInfo, content string) string {
	if len(words) == 0 {
		return strings.TrimSpace(content)
	}

	// 先按 y 排序，再顺序聚类成行（用相邻词 y 差判定，避免连锁漂移）
	sorted := make([]prismWordInfo, len(words))
	copy(sorted, words)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].Y < sorted[j].Y })

	type line struct {
		y      int
		height int
		words  []prismWordInfo
	}
	var lines []line
	cur := line{y: sorted[0].Y, height: heightOf(sorted[0]), words: []prismWordInfo{sorted[0]}}
	for _, w := range sorted[1:] {
		h := heightOf(w)
		minH := cur.height
		if h < minH {
			minH = h
		}
		diff := w.Y - cur.y
		if diff < 0 {
			diff = -diff
		}
		// 同行判定：相邻词 y 差 < 较小高度的 1/2（严格小于）
		if diff < minH/2 {
			cur.words = append(cur.words, w)
		} else {
			lines = append(lines, cur)
			cur = line{y: w.Y, height: h, words: []prismWordInfo{w}}
		}
	}
	lines = append(lines, cur)

	var parts []string
	for i := range lines {
		ws := lines[i].words
		sort.SliceStable(ws, func(a, b int) bool { return ws[a].X < ws[b].X })
		var b strings.Builder
		for j, w := range ws {
			if j > 0 {
				b.WriteString(" ")
			}
			b.WriteString(w.Word)
		}
		parts = append(parts, b.String())
	}

	// 词块无 LaTeX 但有独立公式块时追加（罕见）
	hasLatex := false
	for _, w := range words {
		if latexRe.MatchString(w.Word) {
			hasLatex = true
			break
		}
	}
	if !hasLatex {
		for _, f := range formulas {
			parts = append(parts, f.Text)
		}
	}

	return strings.Join(parts, "\n")
}
