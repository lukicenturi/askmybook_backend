## Backend part of https://askmybook.lukicenturi.vercel.app/
## Frontend Repository: https://github.com/lukicenturi/askmybook_frontend

---

# Setup

1. Create and fill in .env using .env.example as an example.

2. Install dependencies
```
bundle install
```

3. Turn your PDF into embeddings for GPT-3:
```
# Open rails console
rails console

# Call the service to turn the PDF into embeddings
EmbeddingService.generate("files/book/book.pdf")
```

4. Setup database tables
```
rails db:migrate
```

5. Run the server locally
```
rails s
```

6. Ask a question
```
https://localhost:3000/ask?question=When+was+the+book+published
```
