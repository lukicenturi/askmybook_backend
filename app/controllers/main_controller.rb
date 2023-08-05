require 'csv'
require 'matrix'
require 'numo/narray'
require 'langchainrb'
require 'tokenizers'
require Rails.root.join('lib', 'openai_module')

class MainController < ApplicationController
  # Calculate dot product of given two vector
  def calc_similarity(x, y)
    x_array = Numo::DFloat.cast(x)
    y_array = Numo::DFloat.cast(y)
    x_array.dot(y_array)
  end

  # Get the data of each sections (content and embedding vector)
  def load_sections_data(file_name)
    data = {}

    CSV.foreach(file_name, headers: true) do |row|
      title = row['title']
      content = row['content']

      # Unify the vector value that was spread in the numeric fields of the csv
      embedding = []
      row.each_with_index do |(key, value), index|
        next if key == 'title' || key == 'content'
        embedding.push(value.to_f)
      end

      data[title] = {
        content: content,
        embedding: embedding
      }
    end

    data
  end

  def get_most_relevant_sections(sections_data, question)
    question_embedding = OpenAIModule.get_query_embedding(question)

    # Get the relevancy of each section by comparing the embedding similarity with the question
    section_contents_with_relevancy = []
    sections_data.each_with_index do |(_, section), index|
      relevancy = calc_similarity(question_embedding, section[:embedding])
      section_contents_with_relevancy << {
        relevancy: relevancy,
        content: section[:content]
      }
    end

    # Sort all section by the relevancy with the question, higher first
    sorted_section_by_relevancy = section_contents_with_relevancy.sort_by { |entry| -entry[:relevancy] }

    # Take 5 most relevant sections, and unify the content
    num_top_sections = 5
    top_similar_sections = sorted_section_by_relevancy.take(num_top_sections)
    top_section_texts = top_similar_sections.map do |section|
      section[:content]
    end
    relevant_section_text = top_section_texts.join('\n\n')

    # Only get first 500 tokens from the unified content
    max_tokens = 500
    tokenizer = Tokenizers::from_pretrained("gpt2")
    top_tokens = tokenizer.encode(relevant_section_text).ids.take(max_tokens)
    decoded_tokens = tokenizer.decode(top_tokens)
    return decoded_tokens
  end

  def get_relevant_context(question)
    data_path = 'files/output/output.pdf.embeddings.csv'
    sections_data = load_sections_data(data_path)
    relevant_sections = get_most_relevant_sections(sections_data, question)
  end

  def construct_prompt(question)
    context = get_relevant_context(question)

    prompt = <<~STRING
      #{context}

      Q: #{question}
    STRING
  end

  def ask
    question = params[:question]
    modified_question = question.end_with?('?') ? question : question + '?'
    prompt = construct_prompt(modified_question)
    result = OpenAIModule.get_completions_answer(prompt)
    render json: { response: result }
  end
end
