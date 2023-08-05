require 'pdf-reader'
require 'csv'
require 'langchainrb'
require Rails.root.join('lib', 'openai_module')

class EmbeddingService
  def self.clean_text(text)
    text.gsub(/\s+/, ' ').strip
  end

  def self.extract_pages(file_path)
    pages_data = []

    # Get all texts from the PDF
    texts = ''
    PDF::Reader.open(file_path) do |reader|
      reader.pages.each do |page|
        texts += page.text
      end
    end

    # Use RecursiveText from Langchain to chunk the texts into semantically related pieces of text
    # https://python.langchain.com/docs/modules/data_connection/document_transformers/text_splitters/recursive_text_splitter
    chunked_texts = Langchain::Chunker::RecursiveText.new(texts, chunk_size: 1000, chunk_overlap: 200).chunks

    chunked_texts.each_with_index do |chunk, index|
      text = chunk[:text]

      page_data = {
        title: "Section #{index + 1}",
        content: clean_text(text),
      }

      pages_data << page_data
    end
    return pages_data
  end

  def self.generate(file_path)
    pages_data = extract_pages(file_path)
    embedding_output = 'files/output/output.pdf.embeddings.csv'

    CSV.open(embedding_output, 'w') do |csv|
      # Column headers (title, content, followed by numbers indicating the index of the embedding vector)
      csv << ["title"] + ["content"] + (0..4095).to_a.map(&:to_s)

      pages_data.each_with_index do |page_data, idx|
        content = [page_data[:content]]

        # Get the embedding of each section's content
        embedding = OpenAIModule.get_doc_embedding(content)
        csv << [page_data[:title]] + [page_data[:content]] + embedding
      end
    end
  end
end
