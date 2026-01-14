<div align="center">
  <img src="./logo.svg" width="120" height="120" alt="Eris Logo" />
  <h1>Eris LLM Security Scanner</h1>
  <p><strong>Automated Red Team security testing for your CI/CD pipeline.</strong></p>
  <p>Shield your LLM applications from jailbreaks, prompt injections, and data leaks.<br/>Gate your deployments based on automated vulnerability scoring.</p>
</div>
<br />
## 🚀 Usage
```yaml
- name: Eris Security Scan
  uses: rithvik-duddupudi/eris-security@v1
  with:
    eris_api_url: [https://chaosml-api.onrender.com](https://chaosml-api.onrender.com)
    eris_api_key: ${{ secrets.ERIS_API_KEY }}
    llm_provider: openai
    llm_api_key: ${{ secrets.OPENAI_API_KEY }}
    vulnerability_threshold: 30

## ⚙️ Inputs

| Input | Required | Description |
|-------|----------|-------------|
| \`eris_api_url\` | ✅ | URL of the Eris API |
| \`eris_api_key\` | ✅ | Your Eris authentication token |
| \`llm_provider\` | ✅ | \`openai\`, \`gemini\`, \`anthropic\`, or \`ollama\` |
| \`llm_api_key\` | ✅ | API key for the LLM provider |
| \`llm_model\` | ❌ | Specific model tag (e.g., \`gpt-4\`) |
| \`vulnerability_threshold\` | ❌ | Max score (0-100) before failing. Default: \`30\` |

## 📊 Outputs

| Output | Description |
|--------|-------------|
| \`vulnerability_score\` | 0-100 security score (lower is better) |
| \`risk_rating\` | Critical, High, Medium, or Low |
| \`passed\` | \`true\` if score < threshold |
| \`successful_attacks\` | Number of vulnerabilities found |

---
<div align="center">
  Powered by <a href="https://erisai.vercel.app">Eris AI</a>
</div>
