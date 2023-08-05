class CreateQuestions < ActiveRecord::Migration[7.0]
  def change
    create_table :questions do |t|
      t.text :question, limit: 1000
      t.text :answer, limit: 1000
      t.timestamps
    end
  end
end
