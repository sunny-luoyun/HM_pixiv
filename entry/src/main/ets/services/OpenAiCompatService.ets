import { BaseLlmService, LlmConfig } from './LlmProvider';

export class OpenAiCompatService extends BaseLlmService {
  constructor(baseUrl: string = '', apiKey: string = '', model: string = '') {
    const config: LlmConfig = {
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      supportsThinking: false,
      maxTokensTitle: 100,
      maxTokensFull: 8192,
      supportsCostEstimate: false
    };
    super(config);
  }

  updateConfig(baseUrl: string, apiKey: string, model: string): void {
    this.baseUrl = baseUrl;
    this.model = model;
    this.updateApiKey(apiKey);
  }
}
