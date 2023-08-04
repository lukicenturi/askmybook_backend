require 'csv'
require 'matrix'
require 'numo/narray'
require 'langchainrb'
require Rails.root.join('lib', 'openai_module')

class MainController < ApplicationController
  def vector_similarity(x, y)
    x_array = Numo::DFloat.cast(x)
    y_array = Numo::DFloat.cast(y)
    x_array.dot(y_array)
  end

  def load_embeddings(file_name)
    embeddings = {}

    CSV.foreach(file_name, headers: true) do |row|
      title = row['title']
      vector = []

      row.each_with_index do |(key, value), index|
        next if key == 'title'
        vector.push(value.to_f)
      end

      embeddings[title] = vector
    end

    embeddings
  end

  def get_most_relevant_document_sections(embeddings, question, texts)
    question_embedding = OpenAIModule.get_query_embedding(question)

    document_similarities = []

    embeddings.each_with_index do |(_, doc_embedding), index|
      similarity = vector_similarity(question_embedding, doc_embedding)
      document_similarities << [similarity, index]
    end

    num_top_documents = 5
    top_document_similarities = document_similarities.take(num_top_documents)

    selected_sections = []
    top_document_similarities.each do |top_document|
      index = top_document[0]
      selected_sections.push(texts[index]['content'])
    end

    joined_relevant_sections = selected_sections.join('\n\n')

    return Langchain::Chunker::RecursiveText.new(joined_relevant_sections, chunk_size: 1000).chunks[0][:text]
  end

  def get_relevant_context(question)
    csv_text_path = 'book.pdf.pages.csv'
    csv_embedding_path = 'book.pdf.embeddings.csv'
    texts = CSV.read(csv_text_path, headers: true).map(&:to_h)
    embeddings = load_embeddings(csv_embedding_path)
    relevant_sections = get_most_relevant_document_sections(embeddings, question, texts)
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
