require 'ruby/openai'

module OpenAIModule
  MODEL_NAME = 'curie'
  DOC_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-doc-001"
  QUERY_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-query-001"

  COMPLETIONS_MODEL = "text-davinci-003"
  COMPLETIONS_API_PARAMS = {
      # We use temperature of 0.0 because it gives the most predictable, factual answer.
      "temperature": 0.0,
      "max_tokens": 150,
      "model": COMPLETIONS_MODEL,
  }

  def self.client
    @client ||= OpenAI::Client.new(access_token: ENV['OPENAI_ACCESS_TOKEN'])
  end

  def self.get_embedding(text, model)
    result = client.embeddings(
      parameters: {
        model: model,
        input: text
      }
    )

    return result.dig("data", 0, "embedding")
  end

  def self.get_doc_embedding(text)
    return get_embedding(text, DOC_EMBEDDINGS_MODEL)
  end

  def self.get_query_embedding(text)
    return get_embedding(text, QUERY_EMBEDDINGS_MODEL)
  end

  def self.get_completions_answer(prompt)
    result = client.completions(
      parameters: {
        prompt: prompt,
        **COMPLETIONS_API_PARAMS
      }
    )

    text_result = result['choices'][0]['text']
    substring_to_remove = "\nA: "
    cleaned_answer = text_result.gsub(/^#{Regexp.escape(substring_to_remove)}/, '')
    return cleaned_answer
  end
end
