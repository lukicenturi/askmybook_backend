require 'pdf-reader'
require 'tokenizers'
require 'csv'
require 'langchainrb'
require Rails.root.join('lib', 'openai_module')

class EmbeddingService
  def self.count_tokens(text)
    tokenizer = Tokenizers::from_pretrained("gpt2")
    length = tokenizer.encode(text).ids.length
    return length
  end

  def self.clean_text(text)
    text.gsub(/\s+/, ' ').strip
  end

  def self.extract_pages(file_path)
    texts = ''
    pages_data = []

    PDF::Reader.open(file_path) do |reader|
      reader.pages.each do |page|
        texts += page.text
      end
    end

    chunked_texts = Langchain::Chunker::RecursiveText.new(texts, chunk_size: 1000, chunk_overlap: 100).chunks

    chunked_texts.each_with_index do |chunk, index|
      text = chunk[:text]
      tokens = count_tokens(text)

      page_data = {
        title: "Section #{index + 1}",
        content: clean_text(text),
        tokens: tokens
      }

      pages_data << page_data
    end
    return pages_data
  end

  def self.write_to_csv(file_path, pages_data)
    CSV.open(file_path, 'w') do |csv|
      csv << ['title', 'content', 'tokens']

      pages_data.each do |page_data|
        csv << [page_data[:title], page_data[:content], page_data[:tokens]]
      end
    end
  end

  def self.compute_doc_embeddings(pages_data)
    embeddings = {}

    pages_data.each_with_index do |obj, idx|
      content = obj[:content]

      embeddings[idx] = OpenAIModule.get_doc_embedding(content)
    end

    embeddings
  end

  def self.generate_embedding(file_path)
    output = 'book.pdf.pages.csv'
    pages_data = extract_pages(file_path)
    write_to_csv(output, pages_data)

    embedding_output = 'book.pdf.embeddings.csv'
    doc_embeddings = compute_doc_embeddings(pages_data)

    CSV.open(embedding_output, 'w') do |csv|
      csv << ["title"] + (0..4095).to_a.map(&:to_s) # Column headers

      doc_embeddings.each do |i, embedding|
        csv << ["Page #{i + 1}"] + embedding
      end
    end
  end

  def self.generate
    pdf_path = 'book2.pdf'
    generate_embedding(pdf_path)
  end
end
