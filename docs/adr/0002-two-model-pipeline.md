# Recipe import uses two AI models: DeepSeek for generation, Jev for decisions

The recipe-import pipeline splits AI work across two vendors: DeepSeek (`deepseek-flash`) generates structured recipe content and reads images via vision, while Jev — TypeSafe's System One model, called through TypeSafe's official API (`api.typesafe.ai`) — makes only type-safe decisions (per-field presence, quality gates, and future categorization/routing). Jev cannot generate text, so every text-producing step belongs to DeepSeek.

**Considered options**: a single LLM for both extraction and decisions was rejected because an LLM can invent values where the source has none (violating req #4's "leave blank rather than invent") and is slower and costlier for pure decisions. Jev's calibrated confidence yields the review screen's per-field status and the no-invention guarantee with no output-token cost.
