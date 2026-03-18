package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

const (
	// Specify the API endpoint
	apiURL = "https://api.openai.com/v1/chat/completions"
	// Use the latest GPT-4o model for better quality
	defaultModel = "gpt-4o"
	// Maximum retries for API calls
	maxRetries = 3
	// Delay between retries
	retryDelay = 2 * time.Second
)

var (
	apiKey = ""
)

type Language struct {
	Name string
	Code string
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatGptReq struct {
	Model          string          `json:"model"`
	Messages       []Message       `json:"messages"`
	Temperature    float64         `json:"temperature"`
	MaxTokens      int             `json:"max_tokens,omitempty"`
	ResponseFormat *ResponseFormat `json:"response_format,omitempty"`
}

type ResponseFormat struct {
	Type string `json:"type"`
}

type ChatGptResp struct {
	ID      string    `json:"id"`
	Model   string    `json:"model"`
	Choices []Choice  `json:"choices"`
	Error   *APIError `json:"error,omitempty"`
}

type APIError struct {
	Message string `json:"message"`
	Type    string `json:"type"`
	Code    string `json:"code,omitempty"`
}

type Choice struct {
	Index        int     `json:"index"`
	Message      Message `json:"message"`
	FinishReason string  `json:"finish_reason"`
}

func translate(lang Language, referenceLang Language, referenceJson string) error {
	// Enhanced prompt for better translation quality
	systemPrompt := fmt.Sprintf(`You are an expert native %s translator specializing in gaming and mobile applications. Your task is to translate JSON files from English to %s with the following requirements:
	
1. **Target Audience**: Kids and teenagers (12-16 years old) using a gaming mobile app similar to Roblox
2. **Style**: App User Interface (menus, buttons, etc.)
3. **Length**: Keep translations concise - never more than 10% longer than the English version
4. **Accuracy**: Maintain the exact meaning while adapting to natural %s expressions
5. **Consistency**: Use consistent terminology throughout the translation
6. **Cultural Adaptation**: Adapt references to be culturally appropriate for %s-speaking regions
7. **Shortcuts**: In some cases, it's ok to use shortcuts when the translation is too long, like "✏️ Edit links": "✏️ Liens" in french as "✏️ Modifier les liens" would be too long.
8. **Formatting placeholders**: Ensure that all formatting placeholders (e.g., %s, %d, %f) are preserved exactly as they appear in the source string, including their position and format, without modification or removal. For example, %d should remain %d in the translated string, even if directly followed by non-space characters.

The JSON structure may contain:
- Simple key-value pairs: "key": "value"
- Nested objects with context: "key": {"context1": "value1", "context2": "value2"}

Context keys (like "button", "title") should NOT be translated - only the values should be translated.

Here's the reference English to %s translation for context:

%s

Now translate this entire JSON structure to %s, maintaining the exact same format and structure. Only output the JSON file, no other text or explanations.`, lang.Name, lang.Name, lang.Name, lang.Name, referenceLang.Name, referenceJson, lang.Name)

	req := ChatGptReq{
		Model:       defaultModel,
		Temperature: 0.1,  // Slightly higher for more natural translations
		MaxTokens:   4000, // Ensure we have enough tokens for the full response
		ResponseFormat: &ResponseFormat{
			Type: "json_object", // Ensure JSON output format
		},
		Messages: []Message{
			{
				Role:    "system",
				Content: systemPrompt,
			},
		},
	}

	var lastErr error
	for attempt := 1; attempt <= maxRetries; attempt++ {
		if attempt > 1 {
			fmt.Printf("Retry attempt %d/%d for %s...\n", attempt, maxRetries, lang.Name)
			time.Sleep(retryDelay)
		}

		err := makeAPICall(req, lang)
		if err == nil {
			return nil // Success
		}
		lastErr = err
		fmt.Printf("Attempt %d failed for %s: %v\n", attempt, lang.Name, err)
	}

	return fmt.Errorf("failed to translate %s after %d attempts: %v", lang.Name, maxRetries, lastErr)
}

func makeAPICall(req ChatGptReq, lang Language) error {
	// Convert the request to JSON
	reqBodyBytes, err := json.Marshal(req)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %v", err)
	}

	bodyReader := bytes.NewReader(reqBodyBytes)

	// Prepare the request
	httpReq, err := http.NewRequest("POST", apiURL, bodyReader)
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	// Set headers
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	httpReq.Header.Set("Content-Type", "application/json")

	// Send the request with timeout
	client := &http.Client{
		Timeout: 60 * time.Second, // 60 second timeout
	}
	resp, err := client.Do(httpReq)
	if err != nil {
		return fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response body: %v", err)
	}

	// Check HTTP status code
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var respData ChatGptResp
	err = json.Unmarshal(body, &respData)
	if err != nil {
		return fmt.Errorf("failed to unmarshal response: %v", err)
	}

	// Check for API errors
	if respData.Error != nil {
		return fmt.Errorf("API error: %s (type: %s)", respData.Error.Message, respData.Error.Type)
	}

	if len(respData.Choices) == 0 {
		return errors.New("no choices in response")
	}

	if len(respData.Choices) != 1 {
		return fmt.Errorf("expected 1 choice, got %d", len(respData.Choices))
	}

	respStr := respData.Choices[0].Message.Content
	respBytes := []byte(respStr)

	// Validate that the response is valid JSON
	var jsonTest map[string]interface{}
	if err := json.Unmarshal(respBytes, &jsonTest); err != nil {
		return fmt.Errorf("response is not valid JSON: %v", err)
	}

	fmt.Printf("Successfully translated to %s\n", lang.Name)

	// Write to file
	outputPath := "../" + lang.Code + ".json"
	err = os.WriteFile(outputPath, respBytes, 0644)
	if err != nil {
		return fmt.Errorf("failed to write file %s: %v", outputPath, err)
	}

	return nil
}

func main() {
	apiKey = os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		fmt.Println("❌ Error: OPENAI_API_KEY environment variable is not set")
		return
	}

	referenceLang := Language{
		Name: "French",
		Code: "fr",
	}

	languages := []Language{
		{
			Name: "Japanese",
			Code: "ja",
		},
		{
			Name: "Spanish",
			Code: "es",
		},
		{
			Name: "Italian",
			Code: "it",
		},
		{
			Name: "Portuguese",
			Code: "pt",
		},
		{
			Name: "Ukrainian",
			Code: "ua",
		},
		{
			Name: "Polish",
			Code: "pl",
		},
		{
			Name: "Russian",
			Code: "ru",
		},
	}

	fmt.Printf("Starting translation with %s model...\n", defaultModel)

	referenceJson, err := os.ReadFile("../" + referenceLang.Code + ".json")
	if err != nil {
		fmt.Printf("❌ Error reading reference JSON file: %v\n", err)
		return
	}

	fmt.Printf("REFERENCE JSON:\n\n%s\n\n", string(referenceJson))

	for i, lang := range languages {
		fmt.Printf("\n[%d/%d] Translating to %s (%s)...\n", i+1, len(languages), lang.Name, lang.Code)
		err := translate(lang, referenceLang, string(referenceJson))
		if err != nil {
			fmt.Printf("❌ Error translating %s: %v\n", lang.Name, err)
		} else {
			fmt.Printf("✅ Successfully translated %s\n", lang.Name)
		}
	}

	fmt.Println("\nTranslation process completed!")
}
