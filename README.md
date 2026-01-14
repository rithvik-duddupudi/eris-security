# Eris LLM Security Scanner
🛡️ Automated LLM Red Team security testing for GitHub Actions.
## Usage
```yaml
- uses: rithvik-duddupudi/eris-security@v1
  with:
    eris_api_url: https://chaosml-api.onrender.com
    eris_api_key: ${{ secrets.ERIS_API_KEY }}
    llm_provider: openai
    llm_api_key: ${{ secrets.OPENAI_API_KEY }}
```
